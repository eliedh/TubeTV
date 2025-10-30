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
                #if os(tvOS)
                ContentView()
                    .environmentObject(settings)
                #else
                // iOS: Use TabView for iPad and iPhone
                TabView {
                    ContentView()
                        .environmentObject(settings)
                        .tabItem {
                            Label("Videos", systemImage: "play.rectangle.fill")
                        }
                    
                    DownloadsView()
                        .environmentObject(settings)
                        .tabItem {
                            Label("Downloads", systemImage: "arrow.down.circle.fill")
                        }
                }
                #endif
            } else {
                SettingsView(settings: settings)
            }
        }
    }
}
