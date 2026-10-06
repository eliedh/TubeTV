import Foundation
import Combine

enum APIServiceError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case emptyResponse
    case decodingFailed
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Configure your TubeArchivist server URL and API token in Settings before loading videos."
        case .invalidURL:
            return "The app generated an invalid TubeArchivist URL."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .httpStatus(let statusCode):
            return "The server returned HTTP \(statusCode)."
        case .emptyResponse:
            return "The server returned no data."
        case .decodingFailed:
            return "The app could not decode the server response."
        case .requestFailed(let message):
            return message
        }
    }
}

@MainActor
class APIService: ObservableObject {
    @Published var videos: [Video] = []
    @Published var hasMorePages: Bool = true
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    private(set) var currentPage: Int = 1
    private(set) var lastUnwatchedOnly: Bool = false
    private(set) var lastSortByDownloaded: Bool = true
    private(set) var lastContinueWatching: Bool = false
    /// Bumped on every reload so results from superseded requests are discarded
    private var loadGeneration = 0

    // MARK: - Public Methods

    func fetchVideos(unwatchedOnly: Bool = false, sortByDownloaded: Bool = true, continueWatching: Bool = false) {
        Task {
            await reloadVideos(unwatchedOnly: unwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: continueWatching)
        }
    }

    func reloadVideos(unwatchedOnly: Bool = false, sortByDownloaded: Bool = true, continueWatching: Bool = false) async {
        // A newer request (e.g. toggling another filter mid-load) supersedes the in-flight one
        loadGeneration += 1
        let generation = loadGeneration

        // Reset for new fetch
        currentPage = 1
        lastUnwatchedOnly = unwatchedOnly
        lastSortByDownloaded = sortByDownloaded
        lastContinueWatching = continueWatching
        hasMorePages = true
        errorMessage = nil
        isLoading = true

        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        do {
            try validateConfiguration()
            await VideoProgressSync.shared.flushPending()
            await WatchedStateSync.shared.flushPending()

            let page = try await fetchFilteredPage(startingAt: 1)
            guard generation == loadGeneration else { return }
            var filteredVideos = page.videos

            if continueWatching {
                // Sort by progress (highest first)
                filteredVideos.sort { ($0.progress ?? 0) > ($1.progress ?? 0) }
            }

            PlaybackStateStore.shared.reset()
            DownloadManager.shared.backfillMetadata(from: filteredVideos)
            videos = filteredVideos
            currentPage = page.lastFetchedPage
            hasMorePages = page.hasMorePages
        } catch {
            guard generation == loadGeneration else { return }
            videos = []
            hasMorePages = false
            errorMessage = describe(error)
        }
    }

    func loadMoreVideos() {
        Task {
            await loadMoreVideosIfNeeded()
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    private func loadMoreVideosIfNeeded() async {
        guard hasMorePages, !isLoading, !isLoadingMore else { return }
        let nextPage = currentPage + 1
        let generation = loadGeneration
        errorMessage = nil
        isLoadingMore = true

        defer {
            isLoadingMore = false
        }

        do {
            try validateConfiguration()
            await VideoProgressSync.shared.flushPending()
            await WatchedStateSync.shared.flushPending()

            let page = try await fetchFilteredPage(startingAt: nextPage)
            guard generation == loadGeneration else { return }
            DownloadManager.shared.backfillMetadata(from: page.videos)
            videos.append(contentsOf: page.videos)
            currentPage = page.lastFetchedPage
            hasMorePages = page.hasMorePages
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = describe(error)
        }
    }

    /// Fetches a page and applies the client-side "continue watching" filter. When the filter
    /// leaves a page empty, keeps going (up to a limit) so the list doesn't look empty just
    /// because the first page had no in-progress videos.
    private func fetchFilteredPage(startingAt startPage: Int) async throws -> (videos: [Video], lastFetchedPage: Int, hasMorePages: Bool) {
        let maxPagesPerFetch = lastContinueWatching ? 10 : 1
        var page = startPage
        var collected: [Video] = []

        while true {
            guard let url = Configuration.videoURL(page: page, unwatchedOnly: lastUnwatchedOnly, sortByDownloaded: lastSortByDownloaded) else {
                throw APIServiceError.invalidURL
            }

            let response = try await performRequest(url: url)
            let pageVideos = lastContinueWatching ? response.data.filter { $0.isPartiallyWatched } : response.data
            collected.append(contentsOf: pageVideos)

            let morePages = response.hasMorePages && !response.data.isEmpty
            if !collected.isEmpty || !morePages || page - startPage + 1 >= maxPagesPerFetch {
                return (collected, page, morePages)
            }
            page += 1
        }
    }

    private func performRequest(url: URL) async throws -> VideoResponse {
        let request = Configuration.makeAuthorizedRequest(url: url)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIServiceError.httpStatus(httpResponse.statusCode)
            }

            guard !data.isEmpty else {
                throw APIServiceError.emptyResponse
            }

            do {
                return try JSONDecoder().decode(VideoResponse.self, from: data)
            } catch {
                print("Failed to decode video response: \(error)")
                throw APIServiceError.decodingFailed
            }
        } catch let error as APIServiceError {
            throw error
        } catch {
            throw APIServiceError.requestFailed(error.localizedDescription)
        }
    }

    private func validateConfiguration() throws {
        guard Configuration.current.isComplete else {
            throw APIServiceError.missingConfiguration
        }
    }

    private func describe(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return error.localizedDescription
    }
}
