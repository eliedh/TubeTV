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
                // The link arrives while the app is still launching / coming to the foreground;
                // wait (up to ~5s) until a player can actually be presented
                var attempts = 0
                while !PlayerPresenter.canPresentNow && attempts < 50 {
                    try await Task.sleep(nanoseconds: 100_000_000)
                    attempts += 1
                }
                PlayerPresenter.present(video: video)
            } catch {
                print("Couldn't open video \(videoID): \(error.localizedDescription)")
            }
        }
    }
}
