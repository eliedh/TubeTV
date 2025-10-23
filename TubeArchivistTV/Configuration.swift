//
//  Configuration.swift
//  TubeTV
//
//  Created by Copilot on 22.10.25.
//

import Foundation

enum Configuration {
    // MARK: - Server Configuration
    
    /// Server base URL from UserDefaults, with trailing slash removed
    static var baseURL: String {
        let url = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        return url.hasSuffix("/") ? String(url.dropLast()) : url
    }
    
    /// API token from UserDefaults
    static var apiToken: String {
        UserDefaults.standard.string(forKey: "apiToken") ?? ""
    }
    
    // MARK: - API Endpoints
    static var apiBaseURL: String {
        "\(baseURL)/api"
    }
    
    static var watchedEndpoint: String {
        "\(apiBaseURL)/watched/"
    }
    
    static func videoEndpoint(page: Int, unwatchedOnly: Bool, sortByDownloaded: Bool = true) -> String {
        let sortValue = sortByDownloaded ? "downloaded" : "published"
        var urlString = "\(apiBaseURL)/video/?order=desc&sort=\(sortValue)&type=videos&page=\(page)"
        if unwatchedOnly {
            urlString += "&watch=unwatched"
        }
        return urlString
    }
    
    // MARK: - Thumbnail Configuration
    static var thumbnailBaseURL: String {
        baseURL
    }
}
