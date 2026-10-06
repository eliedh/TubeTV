//
//  Configuration.swift
//  TubeTV
//
//  Created by Copilot on 22.10.25.
//

import Foundation

struct AppConfigurationSnapshot {
    let baseURL: String
    let apiToken: String

    var isComplete: Bool {
        !baseURL.isEmpty && !apiToken.isEmpty
    }

    var authorizationValue: String {
        "Token \(apiToken)"
    }
}

enum Configuration {
    // MARK: - Shared Storage

    /// App Group shared with the Top Shelf extension so it can reach the server too
    static let appGroupID = "group.edh.TubeArchivistTV"

    /// Settings storage shared between the app and its extensions
    static let sharedDefaults: UserDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

    /// Copies settings saved by earlier versions (in standard defaults) into the shared App Group
    static func migrateSettingsToSharedDefaultsIfNeeded() {
        let standard = UserDefaults.standard
        guard sharedDefaults !== standard,
              sharedDefaults.string(forKey: "serverURL") == nil,
              let serverURL = standard.string(forKey: "serverURL") else { return }
        sharedDefaults.set(serverURL, forKey: "serverURL")
        sharedDefaults.set(standard.string(forKey: "apiToken"), forKey: "apiToken")
        sharedDefaults.set(standard.bool(forKey: "isConfigured"), forKey: "isConfigured")
    }

    // MARK: - Server Configuration

    static var current: AppConfigurationSnapshot {
        AppConfigurationSnapshot(baseURL: baseURL, apiToken: apiToken)
    }
    
    /// Server base URL from UserDefaults, normalized (scheme added, trailing slashes removed)
    static var baseURL: String {
        normalizeServerURL(sharedDefaults.string(forKey: "serverURL") ?? "")
    }

    /// Trims whitespace, strips trailing slashes and defaults to http:// when no scheme was entered
    static func normalizeServerURL(_ rawValue: String) -> String {
        var url = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return "" }
        if !url.lowercased().hasPrefix("http://") && !url.lowercased().hasPrefix("https://") {
            url = "http://" + url
        }
        while url.hasSuffix("/") {
            url.removeLast()
        }
        return url
    }

    /// True when the URL points at the configured TubeArchivist server (so it may receive the API token)
    static func isServerURL(_ url: URL) -> Bool {
        guard let server = URL(string: baseURL), let serverHost = server.host else { return false }
        return url.host == serverHost && url.port == server.port && url.scheme == server.scheme
    }
    
    /// API token from UserDefaults
    static var apiToken: String {
        sharedDefaults.string(forKey: "apiToken") ?? ""
    }
    
    // MARK: - API Endpoints
    static var apiBaseURL: String {
        "\(baseURL)/api"
    }
    
    static var watchedEndpoint: String {
        "\(apiBaseURL)/watched/"
    }

    static var watchedURL: URL? {
        URL(string: watchedEndpoint)
    }

    static func videoDetailURL(videoID: String) -> URL? {
        URL(string: "\(apiBaseURL)/video/\(videoID)/")
    }

    static func videoProgressURL(videoID: String) -> URL? {
        URL(string: "\(apiBaseURL)/video/\(videoID)/progress/")
    }
    
    static func videoEndpoint(page: Int, unwatchedOnly: Bool, sortByDownloaded: Bool = true) -> String {
        let sortValue = sortByDownloaded ? "downloaded" : "published"
        var urlString = "\(apiBaseURL)/video/?order=desc&sort=\(sortValue)&type=videos&page=\(page)"
        if unwatchedOnly {
            urlString += "&watch=unwatched"
        }
        return urlString
    }

    static func videoURL(page: Int, unwatchedOnly: Bool, sortByDownloaded: Bool = true) -> URL? {
        URL(string: videoEndpoint(page: page, unwatchedOnly: unwatchedOnly, sortByDownloaded: sortByDownloaded))
    }

    static func makeAuthorizedRequest(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        contentType: String? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        let configuration = current
        if !configuration.apiToken.isEmpty {
            request.setValue(configuration.authorizationValue, forHTTPHeaderField: "Authorization")
        }

        return request
    }
}
