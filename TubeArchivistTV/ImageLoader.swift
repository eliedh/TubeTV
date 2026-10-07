//
//  ImageLoader.swift
//  TubeTV
//

import SwiftUI
import UIKit

/// Loads images with the TubeArchivist API token attached (AsyncImage can't send headers),
/// backed by an in-memory cache plus an on-disk URLCache.
final class ImageLoader {
    static let shared = ImageLoader()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "ThumbnailCache"
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
        memoryCache.countLimit = 300
    }

    func cachedImage(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url as NSURL)
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = cachedImage(for: url) {
            return cached
        }
        let data = try await data(for: url)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        memoryCache.setObject(image, forKey: url as NSURL)
        return image
    }

    /// Raw image bytes; the API token is only sent to the configured TubeArchivist server
    func data(for url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }

        let request = Configuration.isServerURL(url)
            ? Configuration.makeAuthorizedRequest(url: url)
            : URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw APIServiceError.httpStatus(httpResponse.statusCode)
        }
        return data
    }
}

/// Drop-in replacement for AsyncImage that goes through `ImageLoader`
struct AuthorizedImage<Content: View, Placeholder: View, Failure: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let failure: () -> Failure

    @State private var image: UIImage?
    @State private var didFail = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self.failure = failure
    }

    var body: some View {
        Group {
            if let image = image ?? url.flatMap({ ImageLoader.shared.cachedImage(for: $0) }) {
                content(Image(uiImage: image))
            } else if didFail {
                failure()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        image = nil
        didFail = false
        guard let url else {
            didFail = true
            return
        }
        do {
            image = try await ImageLoader.shared.image(for: url)
        } catch is CancellationError {
            // View went off-screen; it will reload when it reappears
        } catch let error as URLError where error.code == .cancelled {
            // Same as above
        } catch {
            didFail = true
        }
    }
}
