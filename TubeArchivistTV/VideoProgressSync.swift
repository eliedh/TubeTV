import Foundation

struct VideoProgressPayload: Codable {
    let position: Double
}

struct VideoProgressResponse: Decodable {
    let watched: Bool
    let duration: Double
    let durationText: String?
    let position: Double?
    let youtubeID: String?

    enum CodingKeys: String, CodingKey {
        case watched
        case duration
        case durationText = "duration_str"
        case position
        case youtubeID = "youtube_id"
    }
}

actor VideoProgressSync {
    static let shared = VideoProgressSync()

    private let defaultsKey = "pendingVideoProgress"
    private var isFlushing = false

    func enqueue(videoID: String, position: Double) async -> VideoProgressResponse? {
        guard position.isFinite, position > 5 else { return nil }

        var pendingProgress = loadPendingProgress()
        pendingProgress[videoID] = position
        savePendingProgress(pendingProgress)

        return await flushPending(forcedVideoID: videoID)
    }

    func flushPending() async {
        _ = await flushPending(forcedVideoID: nil)
    }

    private func flushPending(forcedVideoID: String?) async -> VideoProgressResponse? {
        guard !isFlushing else { return nil }

        let configuration = Configuration.current
        guard configuration.isComplete else { return nil }

        let pendingProgress = loadPendingProgress()
        guard !pendingProgress.isEmpty else { return nil }

        isFlushing = true
        defer { isFlushing = false }

        var remainingProgress = pendingProgress
        var latestForcedResponse: VideoProgressResponse?

        for (videoID, position) in pendingProgress.sorted(by: { $0.key < $1.key }) {
            do {
                let response = try await postProgress(videoID: videoID, position: position)
                remainingProgress.removeValue(forKey: videoID)
                if forcedVideoID == videoID {
                    latestForcedResponse = response
                }
            } catch {
                remainingProgress[videoID] = position
            }
        }

        savePendingProgress(remainingProgress)
        return latestForcedResponse
    }

    private func postProgress(videoID: String, position: Double) async throws -> VideoProgressResponse {
        guard let endpoint = Configuration.videoProgressURL(videoID: videoID) else {
            throw VideoProgressSyncError.invalidURL
        }

        let body = try JSONEncoder().encode(VideoProgressPayload(position: position))
        let request = Configuration.makeAuthorizedRequest(
            url: endpoint,
            method: "POST",
            body: body,
            contentType: "application/json"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VideoProgressSyncError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw VideoProgressSyncError.httpStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(VideoProgressResponse.self, from: data)
    }

    private func loadPendingProgress() -> [String: Double] {
        (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Double]) ?? [:]
    }

    private func savePendingProgress(_ progress: [String: Double]) {
        UserDefaults.standard.set(progress, forKey: defaultsKey)
    }
}

enum VideoProgressSyncError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The app generated an invalid video-progress URL."
        case .invalidResponse:
            return "The video-progress request returned an invalid response."
        case .httpStatus(let statusCode):
            return "The video-progress request failed with HTTP \(statusCode)."
        }
    }
}