//
//  TubeTVApp.swift
//  TubeTV
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Called when iOS relaunches the app to deliver finished background downloads. Creating the
    /// DownloadManager reconnects its background URLSession; the handler must be called once
    /// all events are delivered (see DownloadManager.urlSessionDidFinishEvents).
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        guard identifier == DownloadManager.sessionIdentifier else {
            completionHandler()
            return
        }
        DownloadManager.shared.backgroundCompletionHandler = completionHandler
    }
}
#endif

@main
struct TubeTVApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
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
