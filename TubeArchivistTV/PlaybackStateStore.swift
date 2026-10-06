//
//  PlaybackStateStore.swift
//  TubeTV
//

import Foundation

/// Remembers resume positions from this session's playback, so re-opening a video resumes
/// where you left off even though the already-loaded video list still holds the old position.
/// Cleared whenever fresh data is loaded from the server.
final class PlaybackStateStore {
    static let shared = PlaybackStateStore()

    private var positions: [String: Double] = [:]
    private var watchedIDs: Set<String> = []

    private init() {}

    func record(videoID: String, position: Double) {
        positions[videoID] = position
        DownloadManager.shared.updatePlaybackState(videoID: videoID, position: position, watched: watchedIDs.contains(videoID))
    }

    func markWatched(videoID: String) {
        watchedIDs.insert(videoID)
        positions[videoID] = 0
        DownloadManager.shared.updatePlaybackState(videoID: videoID, position: 0, watched: true)
    }

    /// Resume position to use for a video, preferring what was played locally this session
    func resumePosition(for video: Video) -> Double? {
        guard let videoID = video.canonicalVideoID, let position = positions[videoID] else {
            return video.position
        }
        return position
    }

    /// Overlays this session's playback state (if any) onto server data
    func applyLocalState(to video: Video) -> Video {
        guard let videoID = video.canonicalVideoID else { return video }
        let isWatched = watchedIDs.contains(videoID)
        guard let position = positions[videoID] else {
            return isWatched ? video.withPlayback(position: video.position, watched: true) : video
        }
        return video.withPlayback(position: position, watched: isWatched || video.watched)
    }

    func reset() {
        positions.removeAll()
        watchedIDs.removeAll()
    }
}
