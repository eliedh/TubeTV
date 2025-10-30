//
//  PlayerPresenter.swift
//  TubeTV
//
//  Created by Copilot on 20.10.25.
//

import Foundation
import AVKit
import UIKit
import AVFoundation

enum PlayerPresenter {
    /// Presents a full-screen video player for the given video
    static func present(video: Video, token: String) {
        guard let url = URL(string: video.derivedURLString) else {
            print("Invalid video URL: \(video.derivedURLString)")
            return
        }
        
        guard let topVC = topViewController() else {
            print("Unable to find top view controller")
            return
        }

        // Configure audio session to play sound even when device is on silent
        #if os(iOS)
        configureAudioSession()
        #endif

        let options = [
            "AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Token \(token)"]
        ]
        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)

        let controller = SkippingPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.modalPresentationStyle = .fullScreen

        player.play()

        topVC.present(controller, animated: true)
    }
    
    /// Presents a full-screen video player for a locally stored video
    static func presentLocal(url: URL) {
        guard let topVC = topViewController() else {
            print("Unable to find top view controller")
            return
        }

        // Configure audio session to play sound even when device is on silent
        #if os(iOS)
        configureAudioSession()
        #endif

        let player = AVPlayer(url: url)

        let controller = SkippingPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.modalPresentationStyle = .fullScreen

        player.play()

        topVC.present(controller, animated: true)
    }

    /// Finds the topmost view controller in the hierarchy
    private static func topViewController(base: UIViewController? = {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let keyWindow = scenes.first?.windows.first { $0.isKeyWindow } ?? scenes.first?.windows.first
        return keyWindow?.rootViewController
    }()) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
    
    #if os(iOS)
    /// Configures the audio session to allow playback even when device is on silent
    private static func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    #endif
}
