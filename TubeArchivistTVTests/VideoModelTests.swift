//
//  VideoModelTests.swift
//  TubeArchivistTVTests
//

import Foundation
import Testing
@testable import TubeArchivistTV

/// JSON shaped like TubeArchivist's /api/video/ responses
private func videoJSON(
    id: String = "abc123",
    watched: Bool = false,
    position: Double? = nil,
    progress: Double? = nil,
    thumb: String? = "/cache/videos/a/abc123.jpg"
) -> String {
    var player = #""watched": \#(watched), "duration": 600, "duration_str": "10m""#
    if let position { player += #", "position": \#(position)"# }
    if let progress { player += #", "progress": \#(progress)"# }
    let thumbField = thumb.map { #""vid_thumb_url": "\#($0)","# } ?? ""
    return """
    {
        "youtube_id": "\(id)",
        "title": "Test Video",
        "published": "2025-01-02",
        "media_url": "/media/UC123/\(id).mp4",
        \(thumbField)
        "player": { \(player) }
    }
    """
}

private func decodeVideo(_ json: String) throws -> Video {
    try JSONDecoder().decode(Video.self, from: Data(json.utf8))
}

private func decodePage(_ json: String) throws -> VideoResponse {
    try JSONDecoder().decode(VideoResponse.self, from: Data(json.utf8))
}

@MainActor
struct VideoDecodingTests {
    @Test func decodesServerFields() throws {
        let video = try decodeVideo(videoJSON(position: 120, progress: 20))
        #expect(video.youtubeID == "abc123")
        #expect(video.title == "Test Video")
        #expect(video.url == "/media/UC123/abc123.mp4")
        #expect(video.thumbnailPath == "/cache/videos/a/abc123.jpg")
        #expect(video.watched == false)
        #expect(video.duration == 600)
        #expect(video.durationText == "10m")
        #expect(video.position == 120)
        #expect(video.progress == 20)
    }

    @Test func missingThumbnailFallsBackToYouTube() throws {
        let video = try decodeVideo(videoJSON(thumb: nil))
        #expect(video.thumbnailPath == nil)
        #expect(video.thumbnailURL?.absoluteString == "https://i.ytimg.com/vi/abc123/hqdefault.jpg")
    }

    @Test func encodingRoundTripsThroughServerShape() throws {
        let original = try decodeVideo(videoJSON(watched: true, position: 42, progress: 7))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Video.self, from: data)
        #expect(decoded.youtubeID == original.youtubeID)
        #expect(decoded.title == original.title)
        #expect(decoded.url == original.url)
        #expect(decoded.thumbnailPath == original.thumbnailPath)
        #expect(decoded.watched == original.watched)
        #expect(decoded.position == original.position)
        #expect(decoded.progress == original.progress)
        #expect(decoded.duration == original.duration)
    }
}

@MainActor
struct PlaybackStateTests {
    @Test func partiallyWatchedRequiresProgressAndNotWatched() throws {
        #expect(try decodeVideo(videoJSON(position: 120)).isPartiallyWatched)
        #expect(try decodeVideo(videoJSON(progress: 50)).isPartiallyWatched)
        #expect(try !decodeVideo(videoJSON(watched: true, position: 120)).isPartiallyWatched)
        #expect(try !decodeVideo(videoJSON(position: 3)).isPartiallyWatched)
        #expect(try !decodeVideo(videoJSON(progress: 97)).isPartiallyWatched)
    }

    @Test func withPlaybackRecomputesProgress() throws {
        let video = try decodeVideo(videoJSON())
        let updated = video.withPlayback(position: 300, watched: false)
        #expect(updated.position == 300)
        #expect(updated.progress == 50)
        #expect(updated.watched == false)
        #expect(updated.title == video.title)

        let finished = video.withPlayback(position: 0, watched: true)
        #expect(finished.watched)
        #expect(!finished.isPartiallyWatched)
    }

    @Test func resumeTimeFormatting() throws {
        let video = try decodeVideo(videoJSON(position: 330))
        #expect(video.resumeTimeString == "5:30 / 10:00")
    }
}

@MainActor
struct PaginationTests {
    private let item = videoJSON()

    @Test func moreWhenLastPageIsANumber() throws {
        let page = try decodePage(#"{"data": [\#(item)], "paginate": {"current_page": 1, "last_page": 4}}"#)
        #expect(page.hasMorePages)
    }

    @Test func noMoreWhenLastPageIsFalse() throws {
        let page = try decodePage(#"{"data": [\#(item)], "paginate": {"current_page": 4, "last_page": false}}"#)
        #expect(!page.hasMorePages)
    }

    @Test func withoutPaginationFallsBackToNonEmptyData() throws {
        #expect(try decodePage(#"{"data": [\#(item)]}"#).hasMorePages)
        #expect(try !decodePage(#"{"data": []}"#).hasMorePages)
    }
}

@MainActor
struct ConfigurationTests {
    @Test(arguments: [
        ("192.168.1.10:8000", "http://192.168.1.10:8000"),
        ("  http://nas.local:8000/  ", "http://nas.local:8000"),
        ("https://ta.example.com//", "https://ta.example.com"),
        ("HTTPS://ta.example.com", "HTTPS://ta.example.com"),
        ("", ""),
    ])
    func normalizesServerURL(input: String, expected: String) {
        #expect(Configuration.normalizeServerURL(input) == expected)
    }
}
