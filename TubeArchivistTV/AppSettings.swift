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
    
    init() {
        // Load from UserDefaults
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        self.apiToken = UserDefaults.standard.string(forKey: "apiToken") ?? ""
        self.isConfigured = UserDefaults.standard.bool(forKey: "isConfigured")
        
        // Observe changes and save to UserDefaults
        $serverURL
            .dropFirst() // Skip initial value
            .sink { newValue in
                UserDefaults.standard.set(newValue, forKey: "serverURL")
            }
            .store(in: &cancellables)
        
        $apiToken
            .dropFirst()
            .sink { newValue in
                UserDefaults.standard.set(newValue, forKey: "apiToken")
            }
            .store(in: &cancellables)
        
        $isConfigured
            .dropFirst()
            .sink { newValue in
                UserDefaults.standard.set(newValue, forKey: "isConfigured")
            }
            .store(in: &cancellables)
    }
    
    func saveSettings(serverURL: String, apiToken: String) {
        self.serverURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isConfigured = true
    }
    
    func clearSettings() {
        self.serverURL = ""
        self.apiToken = ""
        self.isConfigured = false
    }
}
