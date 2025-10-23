import Foundation

struct Video: Identifiable, Decodable, Sendable {
    var id: String { youtubeID ?? "unknown" }
    
    let youtubeID: String?
    let title: String
    let published: String
    let url: String
    let watched: Bool
    
    // MARK: - Derived Properties
    
    /// Returns the thumbnail URL from YouTube's CDN
    var derivedThumbnailURLString: String? {
        guard let youtubeID, !youtubeID.isEmpty else {
            return nil
        }
        return "https://i.ytimg.com/vi/\(youtubeID)/hqdefault.jpg"
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
    }
}

// MARK: - API Response

struct VideoResponse: Decodable, Sendable {
    let data: [Video]
}
