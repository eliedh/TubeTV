//
//  ContentProvider.swift
//  TubeTVTopShelf
//
//  Shows "Continue Watching" and "Recently Added" rows on the Apple TV Top Shelf.
//  Shares Video.swift and Configuration.swift with the app; server settings come
//  from the App Group defaults the app writes.
//

import Foundation
import TVServices

final class ContentProvider: TVTopShelfContentProvider {
    private let maxItemsPerSection = 10

    override func loadTopShelfContent(completionHandler: @escaping ((any TVTopShelfContent)?) -> Void) {
        Task {
            completionHandler(await makeContent())
        }
    }

    private func makeContent() async -> (any TVTopShelfContent)? {
        guard Configuration.current.isComplete,
              let url = Configuration.videoURL(page: 1, unwatchedOnly: false, sortByDownloaded: true) else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: Configuration.makeAuthorizedRequest(url: url))
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return nil }
            let videos = try JSONDecoder().decode(VideoResponse.self, from: data).data

            let continueWatching = Array(videos.filter { $0.isPartiallyWatched }.prefix(maxItemsPerSection))
            let recentlyAdded = Array(videos.prefix(maxItemsPerSection))
            let imageURLs = await cacheThumbnails(for: continueWatching + recentlyAdded)

            var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []
            if !continueWatching.isEmpty {
                sections.append(makeSection(title: "Continue Watching", videos: continueWatching, imageURLs: imageURLs, showProgress: true))
            }
            if !recentlyAdded.isEmpty {
                sections.append(makeSection(title: "Recently Added", videos: recentlyAdded, imageURLs: imageURLs, showProgress: false))
            }
            return sections.isEmpty ? nil : TVTopShelfSectionedContent(sections: sections)
        } catch {
            return nil
        }
    }

    private func makeSection(
        title: String,
        videos: [Video],
        imageURLs: [String: URL],
        showProgress: Bool
    ) -> TVTopShelfItemCollection<TVTopShelfSectionedItem> {
        let items = videos.compactMap { video -> TVTopShelfSectionedItem? in
            guard let videoID = video.canonicalVideoID,
                  let playURL = URL(string: "tubetv://play/\(videoID)") else { return nil }

            // Identifiers must be unique across sections
            let item = TVTopShelfSectionedItem(identifier: "\(title)-\(videoID)")
            item.title = video.title
            item.imageShape = .hdtv
            if let imageURL = imageURLs[videoID] {
                item.setImageURL(imageURL, for: .screenScale1x)
                item.setImageURL(imageURL, for: .screenScale2x)
            }
            if showProgress, let progress = video.progress {
                item.playbackProgress = min(max(progress / 100, 0), 1)
            }
            item.displayAction = TVTopShelfAction(url: playURL)
            item.playAction = TVTopShelfAction(url: playURL)
            return item
        }

        let section = TVTopShelfItemCollection(items: items)
        section.title = title
        return section
    }

    /// The system fetches Top Shelf images itself and can't send the API token, so download
    /// thumbnails (with the token) into the shared container and hand out file URLs.
    private func cacheThumbnails(for videos: [Video]) async -> [String: URL] {
        guard let directory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Configuration.appGroupID)?
            .appendingPathComponent("Library/Caches/TopShelf", isDirectory: true) else {
            return [:]
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var unique: [String: URL] = [:]
        for video in videos {
            if let videoID = video.canonicalVideoID, let thumbnailURL = video.thumbnailURL {
                unique[videoID] = thumbnailURL
            }
        }

        let results = await withTaskGroup(of: (String, URL?).self) { group in
            for (videoID, remoteURL) in unique {
                group.addTask {
                    let fileURL = directory.appendingPathComponent("\(videoID).jpg")
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        return (videoID, fileURL)
                    }
                    var request = URLRequest(url: remoteURL)
                    if remoteURL.host == URL(string: Configuration.baseURL)?.host {
                        request = Configuration.makeAuthorizedRequest(url: remoteURL)
                    }
                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard let httpResponse = response as? HTTPURLResponse,
                              (200...299).contains(httpResponse.statusCode) else {
                            return (videoID, nil)
                        }
                        try data.write(to: fileURL, options: .atomic)
                        return (videoID, fileURL)
                    } catch {
                        return (videoID, nil)
                    }
                }
            }
            var urls: [String: URL] = [:]
            for await (videoID, fileURL) in group {
                urls[videoID] = fileURL
            }
            return urls
        }

        // Drop thumbnails for videos no longer shown
        let keep = Set(results.values.map(\.lastPathComponent))
        let existing = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in existing where !keep.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
        return results
    }
}
