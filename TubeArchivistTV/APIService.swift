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

    // MARK: - Public Methods

    func fetchVideos(unwatchedOnly: Bool = false, sortByDownloaded: Bool = true, continueWatching: Bool = false) {
        Task {
            await reloadVideos(unwatchedOnly: unwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: continueWatching)
        }
    }

    func reloadVideos(unwatchedOnly: Bool = false, sortByDownloaded: Bool = true, continueWatching: Bool = false) async {
        guard !isLoading else { return }

        // Reset for new fetch
        currentPage = 1
        lastUnwatchedOnly = unwatchedOnly
        lastSortByDownloaded = sortByDownloaded
        lastContinueWatching = continueWatching
        hasMorePages = true
        errorMessage = nil
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            try validateConfiguration()
            await VideoProgressSync.shared.flushPending()
            await WatchedStateSync.shared.flushPending()

            guard let url = Configuration.videoURL(page: 1, unwatchedOnly: unwatchedOnly, sortByDownloaded: sortByDownloaded) else {
                throw APIServiceError.invalidURL
            }

            let response = try await performRequest(url: url)
            var filteredVideos = response.data
            
            // Apply client-side filter for continue watching
            if continueWatching {
                filteredVideos = filteredVideos.filter { $0.isPartiallyWatched }
                // Sort by progress (highest first)
                filteredVideos.sort { ($0.progress ?? 0) > ($1.progress ?? 0) }
            }
            
            videos = filteredVideos
            hasMorePages = !filteredVideos.isEmpty
        } catch {
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
        errorMessage = nil
        isLoadingMore = true

        defer {
            isLoadingMore = false
        }

        do {
            try validateConfiguration()
            await VideoProgressSync.shared.flushPending()
            await WatchedStateSync.shared.flushPending()

            guard let url = Configuration.videoURL(page: nextPage, unwatchedOnly: lastUnwatchedOnly, sortByDownloaded: lastSortByDownloaded) else {
                throw APIServiceError.invalidURL
            }

            let response = try await performRequest(url: url)
            if !response.data.isEmpty {
                var newVideos = response.data
                
                // Apply client-side filter for continue watching
                if lastContinueWatching {
                    newVideos = newVideos.filter { $0.isPartiallyWatched }
                }
                
                videos.append(contentsOf: newVideos)
                currentPage = nextPage
                hasMorePages = !newVideos.isEmpty
            } else {
                hasMorePages = false
            }
        } catch {
            errorMessage = describe(error)
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
