//
//  PlayerPresenter.swift
//  TubeTV
//
//  Created by Copilot on 20.10.25.
//

import Foundation
import AVKit
import UIKit

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
}
