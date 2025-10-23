import Foundation
import Combine

@MainActor
class APIService: ObservableObject {
    @Published var videos: [Video] = []
    @Published var hasMorePages: Bool = true
    private(set) var currentPage: Int = 1
    private(set) var lastUnwatchedOnly: Bool = false
    private(set) var lastSortByDownloaded: Bool = true

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Authorization": "Token \(Configuration.apiToken)"]
        return URLSession(configuration: config)
    }()

    // MARK: - Public Methods

    func fetchVideos(unwatchedOnly: Bool = false, sortByDownloaded: Bool = true) {
        // Reset for new fetch
        currentPage = 1
        lastUnwatchedOnly = unwatchedOnly
        lastSortByDownloaded = sortByDownloaded
        hasMorePages = true

        guard let url = URL(string: Configuration.videoEndpoint(page: 1, unwatchedOnly: unwatchedOnly, sortByDownloaded: sortByDownloaded)) else {
            print("Invalid URL")
            return
        }

        performRequest(url: url) { [weak self] response in
            guard let self else { return }
            self.videos = response.data
            self.hasMorePages = !response.data.isEmpty
        }
    }

    func loadMoreVideos() {
        guard hasMorePages else { return }
        let nextPage = currentPage + 1

        guard let url = URL(string: Configuration.videoEndpoint(page: nextPage, unwatchedOnly: lastUnwatchedOnly, sortByDownloaded: lastSortByDownloaded)) else {
            print("Invalid URL")
            return
        }

        performRequest(url: url) { [weak self] response in
            guard let self else { return }
            if !response.data.isEmpty {
                self.videos.append(contentsOf: response.data)
                self.currentPage = nextPage
                self.hasMorePages = true
            } else {
                self.hasMorePages = false
            }
        }
    }

    // MARK: - Private Methods

    private func performRequest(url: URL, completion: @escaping (VideoResponse) -> Void) {
        session.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            
            // Handle network or data errors
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                self.updateHasMorePages(false)
                return
            }

            guard let data = data else {
                print("No data received")
                self.updateHasMorePages(false)
                return
            }

            // Decode on main actor
            Task { @MainActor [weak self] in
                do {
                    let videoResponse = try JSONDecoder().decode(VideoResponse.self, from: data)
                    completion(videoResponse)
                } catch {
                    print("Decoding error: \(error)")
                    if let raw = String(data: data, encoding: .utf8) {
                        print("Raw JSON (first 500 chars): \(raw.prefix(500))")
                    }
                    self?.hasMorePages = false
                }
            }
        }.resume()
    }
    
    private nonisolated func updateHasMorePages(_ value: Bool) {
        Task { @MainActor [weak self] in
            self?.hasMorePages = value
        }
    }
}
