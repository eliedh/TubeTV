import Foundation

struct Video: Identifiable, Decodable, Sendable {
    var id: String { youtubeID ?? "unknown" }
    
    let youtubeID: String?
    let title: String
    let published: String
    let url: String
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
    
    /// Returns the thumbnail URL from YouTube's CDN
    var derivedThumbnailURLString: String? {
        guard let canonicalVideoID else {
            return nil
        }
        return "https://i.ytimg.com/vi/\(canonicalVideoID)/hqdefault.jpg"
    }
    
    /// Returns the full video URL by combining base URL with the relative path
    var derivedURLString: String {
        Configuration.thumbnailBaseURL + url
    }
    
    // MARK: - Decodable
    
    enum CodingKeys: String, CodingKey {
        case youtubeID = "youtube_id"
        case title
        case published
        case url = "media_url"
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
        
        // Decode watched status from nested player object
        let playerContainer = try container.nestedContainer(keyedBy: PlayerKeys.self, forKey: .player)
        watched = try playerContainer.decode(Bool.self, forKey: .watched)
        duration = try playerContainer.decodeIfPresent(Double.self, forKey: .duration)
        durationText = try playerContainer.decodeIfPresent(String.self, forKey: .durationText)
        progress = try playerContainer.decodeIfPresent(Double.self, forKey: .progress)
        position = try playerContainer.decodeIfPresent(Double.self, forKey: .position)
    }
}

// MARK: - API Response

struct VideoResponse: Decodable, Sendable {
    let data: [Video]
}
