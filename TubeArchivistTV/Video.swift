import Foundation

struct Video: Identifiable, Codable, Sendable {
    var id: String { youtubeID ?? "unknown" }
    
    let youtubeID: String?
    let title: String
    let published: String
    let url: String
    /// Server-relative thumbnail path from TubeArchivist (e.g. "/cache/videos/a/abc123.jpg")
    let thumbnailPath: String?
    let watched: Bool
    let duration: Double?
    let durationText: String?
    let progress: Double?
    let position: Double?

    var canonicalVideoID: String? {
        guard let youtubeID else { return nil }
        let trimmedID = youtubeID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedID.isEmpty ? nil : trimmedID
    }
    
    /// Returns true if video has measurable playback progress (resumed position or progress percentage)
    var hasProgress: Bool {
        // Check if position is meaningful (more than 5 seconds)
        if let position, position > 5 {
            return true
        }
        // Check if progress percentage is meaningful (between 5% and 95%)
        if let progress, progress > 5, progress < 95 {
            return true
        }
        return false
    }
    
    /// Returns true if video is partially watched (not fully completed)
    var isPartiallyWatched: Bool {
        hasProgress && !watched
    }
    
    /// Returns the progress percentage as a user-friendly string (e.g., "45%")
    var progressPercentageString: String {
        guard let progress else { return "0%" }
        return "\(Int(progress))%"
    }
    
    /// Returns the resume time in a user-friendly format (e.g., "5:30 / 10:45")
    var resumeTimeString: String {
        guard let position, let duration else { return "" }
        let posMinutes = Int(position) / 60
        let posSecs = Int(position) % 60
        let durMinutes = Int(duration) / 60
        let durSecs = Int(duration) % 60
        return String(format: "%d:%02d / %d:%02d", posMinutes, posSecs, durMinutes, durSecs)
    }
    
    // MARK: - Derived Properties
    
    /// Thumbnail URL served by TubeArchivist (requires the API token), falling back to
    /// YouTube's CDN only when the server didn't provide a thumbnail path.
    var thumbnailURL: URL? {
        if let thumbnailPath, !thumbnailPath.isEmpty {
            return URL(string: Configuration.baseURL + thumbnailPath)
        }
        guard let canonicalVideoID else { return nil }
        return URL(string: "https://i.ytimg.com/vi/\(canonicalVideoID)/hqdefault.jpg")
    }
    
    /// Returns the full video URL by combining base URL with the relative path
    var derivedURLString: String {
        Configuration.baseURL + url
    }

    /// Returns a copy with locally-known playback state (used to keep offline metadata fresh)
    func withPlayback(position: Double?, watched: Bool) -> Video {
        var progress = self.progress
        if let position, let duration, duration > 0 {
            progress = 100 * position / duration
        }
        return Video(
            youtubeID: youtubeID,
            title: title,
            published: published,
            url: url,
            thumbnailPath: thumbnailPath,
            watched: watched,
            duration: duration,
            durationText: durationText,
            progress: progress,
            position: position
        )
    }

    private init(
        youtubeID: String?,
        title: String,
        published: String,
        url: String,
        thumbnailPath: String?,
        watched: Bool,
        duration: Double?,
        durationText: String?,
        progress: Double?,
        position: Double?
    ) {
        self.youtubeID = youtubeID
        self.title = title
        self.published = published
        self.url = url
        self.thumbnailPath = thumbnailPath
        self.watched = watched
        self.duration = duration
        self.durationText = durationText
        self.progress = progress
        self.position = position
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case youtubeID = "youtube_id"
        case title
        case published
        case url = "media_url"
        case thumbnailPath = "vid_thumb_url"
        case player
    }
    
    enum PlayerKeys: String, CodingKey {
        case watched
        case duration
        case durationText = "duration_str"
        case progress
        case position
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        youtubeID = try container.decodeIfPresent(String.self, forKey: .youtubeID)
        title = try container.decode(String.self, forKey: .title)
        published = try container.decode(String.self, forKey: .published)
        url = try container.decode(String.self, forKey: .url)
        thumbnailPath = try? container.decodeIfPresent(String.self, forKey: .thumbnailPath)
        
        // Decode watched status from nested player object
        let playerContainer = try container.nestedContainer(keyedBy: PlayerKeys.self, forKey: .player)
        watched = try playerContainer.decode(Bool.self, forKey: .watched)
        duration = try playerContainer.decodeIfPresent(Double.self, forKey: .duration)
        durationText = try playerContainer.decodeIfPresent(String.self, forKey: .durationText)
        progress = try playerContainer.decodeIfPresent(Double.self, forKey: .progress)
        position = try playerContainer.decodeIfPresent(Double.self, forKey: .position)
    }

    /// Mirrors the server's JSON shape so stored metadata round-trips through `init(from:)`
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(youtubeID, forKey: .youtubeID)
        try container.encode(title, forKey: .title)
        try container.encode(published, forKey: .published)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(thumbnailPath, forKey: .thumbnailPath)

        var playerContainer = container.nestedContainer(keyedBy: PlayerKeys.self, forKey: .player)
        try playerContainer.encode(watched, forKey: .watched)
        try playerContainer.encodeIfPresent(duration, forKey: .duration)
        try playerContainer.encodeIfPresent(durationText, forKey: .durationText)
        try playerContainer.encodeIfPresent(progress, forKey: .progress)
        try playerContainer.encodeIfPresent(position, forKey: .position)
    }
}

// MARK: - API Response

struct VideoResponse: Decodable, Sendable {
    let data: [Video]
    let paginate: Pagination?

    struct Pagination: Decodable, Sendable {
        /// TubeArchivist sends the last page number, or `false` when the current page is the last one
        let lastPage: Int?

        enum CodingKeys: String, CodingKey {
            case lastPage = "last_page"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            lastPage = try? container.decodeIfPresent(Int.self, forKey: .lastPage)
        }
    }

    /// Whether another page exists after this one
    var hasMorePages: Bool {
        guard let paginate else { return !data.isEmpty }
        return paginate.lastPage != nil
    }
}
