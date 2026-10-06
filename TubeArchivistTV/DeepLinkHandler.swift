//
//  DeepLinkHandler.swift
//  TubeTV
//

import Foundation

/// Handles `tubetv://play/<youtube_id>` links (used by the Top Shelf extension)
enum DeepLinkHandler {
    static let scheme = "tubetv"

    static func handle(_ url: URL) {
        guard url.scheme == scheme, url.host == "play" || url.host == "video" else { return }
        let videoID = url.lastPathComponent
        guard !videoID.isEmpty, videoID != "/" else { return }

        Task {
            do {
                let video = try await APIService.fetchVideo(videoID: videoID)
                PlayerPresenter.present(video: video)
            } catch {
                print("Couldn't open video \(videoID): \(error.localizedDescription)")
            }
        }
    }
}
