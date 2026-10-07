//
//  AppSettings.swift
//  TubeTV
//
//  Created by Copilot on 22.10.25.
//

import Foundation
import Combine

class AppSettings: ObservableObject {
    @Published var serverURL: String = ""
    @Published var apiToken: String = ""
    @Published var isConfigured: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private let defaults = Configuration.sharedDefaults
    
    init() {
        Configuration.migrateSettingsToSharedDefaultsIfNeeded()
        
        // Load from the shared (App Group) defaults
        self.serverURL = defaults.string(forKey: "serverURL") ?? ""
        self.apiToken = defaults.string(forKey: "apiToken") ?? ""
        self.isConfigured = defaults.bool(forKey: "isConfigured")
        
        // Observe changes and save to UserDefaults
        $serverURL
            .dropFirst() // Skip initial value
            .sink { [defaults] newValue in
                defaults.set(newValue, forKey: "serverURL")
            }
            .store(in: &cancellables)
        
        $apiToken
            .dropFirst()
            .sink { [defaults] newValue in
                defaults.set(newValue, forKey: "apiToken")
            }
            .store(in: &cancellables)
        
        $isConfigured
            .dropFirst()
            .sink { [defaults] newValue in
                defaults.set(newValue, forKey: "isConfigured")
            }
            .store(in: &cancellables)
    }
    
    func saveSettings(serverURL: String, apiToken: String) {
        self.serverURL = Configuration.normalizeServerURL(serverURL)
        self.apiToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isConfigured = true
    }
    
    func clearSettings() {
        self.serverURL = ""
        self.apiToken = ""
        self.isConfigured = false
    }
}
