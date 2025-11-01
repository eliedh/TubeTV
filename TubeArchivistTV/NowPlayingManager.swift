//
//  NowPlayingManager.swift
//  TubeTV
//

import Foundation
import AVFoundation
import MediaPlayer
import UIKit

final class NowPlayingManager {
    private weak var player: AVPlayer?
    private var commandCenter = MPRemoteCommandCenter.shared()
    private var nowPlayingInfo: [String: Any] = [:]
    private var artworkTask: URLSessionDataTask?
    
    private let onPlay: () -> Void
    private let onPause: () -> Void
    private let onToggle: () -> Void
    private let onSkipForward: () -> Void
    private let onSkipBackward: () -> Void
    
    init(player: AVPlayer,
         onPlay: @escaping () -> Void,
         onPause: @escaping () -> Void,
         onToggle: @escaping () -> Void,
         onSkipForward: @escaping () -> Void,
         onSkipBackward: @escaping () -> Void) {
        self.player = player
        self.onPlay = onPlay
        self.onPause = onPause
        self.onToggle = onToggle
        self.onSkipForward = onSkipForward
        self.onSkipBackward = onSkipBackward
    }
    
    func start(title: String, artworkURL: URL?, duration: TimeInterval?) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title
        ]
        if let duration, duration.isFinite {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1
        self.nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        // Fetch artwork asynchronously
        if let artworkURL {
            artworkTask?.cancel()
            artworkTask = URLSession.shared.dataTask(with: artworkURL) { [weak self] data, _, _ in
                guard let self, let data, let image = UIImage(data: data) else { return }
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                DispatchQueue.main.async {
                    self.nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
                }
            }
            artworkTask?.resume()
        }
        
        // Command center
        setupRemoteCommands()
    }
    
    func stop() {
        artworkTask?.cancel()
        teardownRemoteCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func updateElapsedTime(currentTime: TimeInterval, duration: TimeInterval?, rate: Float) {
        if let duration, duration.isFinite {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Remote Commands
    
    private func setupRemoteCommands() {
        // Clear existing targets to avoid duplicates
        teardownRemoteCommands()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onPlay(); return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPause(); return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onToggle(); return .success
        }
        
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [10]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.onSkipForward(); return .success
        }
        
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.onSkipBackward(); return .success
        }
    }
    
    private func teardownRemoteCommands() {
        // Remove all handlers by reassigning an empty block, then disabling
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
    }
}
