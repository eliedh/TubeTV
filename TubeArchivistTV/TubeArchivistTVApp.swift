//
//  TubeTVApp.swift
//  TubeTV
//

import SwiftUI

@main
struct TubeTVApp: App {
    @StateObject private var settings = AppSettings()
    
    var body: some Scene {
        WindowGroup {
            if settings.isConfigured {
                ContentView()
                    .environmentObject(settings)
            } else {
                SettingsView(settings: settings)
            }
        }
    }
}
