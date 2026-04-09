import Foundation

actor WatchedStateSync {
    static let shared = WatchedStateSync()

    private let defaultsKey = "pendingWatchedVideoIDs"
    private var isFlushing = false

    func enqueue(videoID: String) async {
        var pendingIDs = loadPendingIDs()
        if !pendingIDs.contains(videoID) {
            pendingIDs.append(videoID)
            savePendingIDs(pendingIDs)
        }

        await flushPending()
    }

    func flushPending() async {
        guard !isFlushing else { return }

        let configuration = Configuration.current
        guard configuration.isComplete, let endpoint = Configuration.watchedURL else { return }

        let pendingIDs = loadPendingIDs()
        guard !pendingIDs.isEmpty else { return }

        isFlushing = true
        defer { isFlushing = false }

        var remainingIDs: [String] = []

        for videoID in pendingIDs {
            do {
                try await postWatched(videoID: videoID, endpoint: endpoint)
            } catch {
                remainingIDs.append(videoID)
            }
        }

        savePendingIDs(remainingIDs)
    }

    private func postWatched(videoID: String, endpoint: URL) async throws {
        let payload = ["id": videoID, "is_watched": true] as [String: Any]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = Configuration.makeAuthorizedRequest(
            url: endpoint,
            method: "POST",
            body: body,
            contentType: "application/json"
        )

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchedSyncError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw WatchedSyncError.httpStatus(httpResponse.statusCode)
        }
    }

    private func loadPendingIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
    }

    private func savePendingIDs(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: defaultsKey)
    }
}

enum WatchedSyncError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The watched-status request returned an invalid response."
        case .httpStatus(let statusCode):
            return "The watched-status request failed with HTTP \(statusCode)."
        }
    }
}