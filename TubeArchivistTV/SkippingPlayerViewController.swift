//
//  SkippingPlayerViewController.swift
//  TubeTV
//

import AVKit
import UIKit
import MediaPlayer

final class SkippingPlayerViewController: AVPlayerViewController {
    private var timeControlStatusObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeObserverToken: Any?
    private var didTriggerWatched: Bool = false
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var lastSyncedProgressPosition: Double = 0
    private var hasAppliedInitialPosition = false
    
    // Now Playing
    private var nowPlayingManager: NowPlayingManager?
    var nowPlayingTitle: String?
    var nowPlayingArtworkURL: URL?
    var watchedVideoID: String?
    var initialPlaybackPosition: Double?
    
    // Playback speed settings, shown in the system player's own speed menu
    private let playbackSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    override func viewDidLoad() {
        super.viewDidLoad()
        speeds = playbackSpeeds.map { rate in
            AVPlaybackSpeed(rate: rate, localizedName: rate == 1 ? "Normal" : "\(rate)×")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // viewDidAppear can fire again (e.g. after a modal over the player); don't double-register
        guard timeObserverToken == nil else { return }
        applyInitialPlaybackPositionIfNeeded()
        observePlaybackForIdleTimer()
        observeFivePercentRemaining()
        setupNowPlaying()
        observeAudioSessionNotifications()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Lets the video list refresh this video's watched state / progress
        if isBeingDismissed, let watchedVideoID {
            NotificationCenter.default.post(name: .playerDidClose, object: watchedVideoID)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        syncProgress(force: true)
        timeControlStatusObservation?.invalidate()
        timeControlStatusObservation = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        if let token = timeObserverToken, let player = player {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        nowPlayingManager?.stop()
        nowPlayingManager = nil
        removeAudioSessionNotifications()
    }
    
    /// Resumes playback at the speed picked in the speed menu. Plain play() would reset to 1.0×
    /// when resuming from Lock Screen controls or after an interruption.
    private func resumePlayback() {
        guard let player else { return }
        player.playImmediately(atRate: selectedSpeed?.rate ?? 1)
    }

    // MARK: - Watch Progress Tracking
    
    private func observeFivePercentRemaining() {
        guard let player = player, let item = player.currentItem else { return }
        // Poll every half second
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] currentTime in
            guard let self = self else { return }
            let duration = item.duration.seconds
            let current = currentTime.seconds
            guard duration.isFinite, duration > 0 else { return }
            if !self.didTriggerWatched {
                self.syncProgressIfNeeded(current: current, duration: duration)
                let remaining = duration - current
                let tenPercent = duration * 0.10
                let threshold = max(tenPercent, 30.0)
                if remaining <= threshold {
                    self.didTriggerWatched = true
                    self.markWatched()
                }
            }
            // Update Now Playing elapsed time (also after the video counts as watched)
            self.nowPlayingManager?.updateElapsedTime(currentTime: current,
                                                      duration: duration,
                                                      rate: self.player?.rate ?? 0)
        }
    }

    private func markWatched() {
        guard let watchedVideoID else { return }
        PlaybackStateStore.shared.markWatched(videoID: watchedVideoID)

        Task {
            await WatchedStateSync.shared.enqueue(videoID: watchedVideoID)
        }
    }

    private func applyInitialPlaybackPositionIfNeeded() {
        guard !hasAppliedInitialPosition,
              let player,
              let item = player.currentItem else { return }

        itemStatusObservation?.invalidate()
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self, item.status == .readyToPlay else { return }
            self.seekToInitialPlaybackPosition()
        }
    }

    private func seekToInitialPlaybackPosition() {
        guard !hasAppliedInitialPosition,
              let player,
              let initialPlaybackPosition,
              initialPlaybackPosition > 5,
              initialPlaybackPosition.isFinite else {
            hasAppliedInitialPosition = true
            return
        }

        hasAppliedInitialPosition = true
        lastSyncedProgressPosition = initialPlaybackPosition
        let targetTime = CMTime(seconds: initialPlaybackPosition, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func syncProgressIfNeeded(current: Double, duration: Double) {
        guard current.isFinite, duration.isFinite, current > 5 else { return }
        guard current - lastSyncedProgressPosition >= 15 else { return }
        syncProgress(force: false, current: current)
    }

    private func syncProgress(force: Bool, current: Double? = nil) {
        guard let watchedVideoID, !didTriggerWatched else { return }
        guard let player else { return }

        let currentPosition = current ?? player.currentTime().seconds
        guard currentPosition.isFinite, currentPosition > 5 else { return }
        guard force || currentPosition - lastSyncedProgressPosition >= 5 else { return }

        lastSyncedProgressPosition = currentPosition
        PlaybackStateStore.shared.record(videoID: watchedVideoID, position: currentPosition)

        Task {
            let response = await VideoProgressSync.shared.enqueue(videoID: watchedVideoID, position: currentPosition)
            if response?.watched == true {
                didTriggerWatched = true
            }
        }
    }
    
    // MARK: - Idle Timer & Playback Observation

    private func observePlaybackForIdleTimer() {
        guard let player = player else { return }
        timeControlStatusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = (player.timeControlStatus == .playing)
                if player.timeControlStatus != .playing {
                    self?.syncProgress(force: true)
                }
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }

    @objc private func didFinishPlaying() {
        UIApplication.shared.isIdleTimerDisabled = false
        syncProgress(force: true)
        // Dismiss the player and return to ContentView
        if let presentingVC = self.presentingViewController {
            presentingVC.dismiss(animated: true)
        } else {
            self.dismiss(animated: true)
        }
    }
    
    // MARK: - Skip Forward/Backward
    // On tvOS, clicking left/right to skip 10s is built into AVPlayerViewController (and the
    // arrows scrub while paused), so there's no custom press handling. skip(by:) is used for
    // the Lock Screen / Control Center commands.

    private func skip(by seconds: Double) {
        guard let player = player, player.currentItem != nil else { return }
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = max(0, currentTime + seconds)
        
        let time = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Now Playing & Remote Commands
    private func setupNowPlaying() {
        guard let player = player else { return }
        // item.duration doesn't block (asset.duration synchronously loads over the network on the
        // main thread); it may still be indefinite here, updateElapsedTime fills it in later
        let duration = player.currentItem?.duration.seconds
        nowPlayingManager = NowPlayingManager(
            player: player,
            onPlay: { [weak self] in self?.resumePlayback() },
            onPause: { [weak self] in self?.player?.pause() },
            onToggle: { [weak self] in
                guard let self = self else { return }
                if self.player?.rate == 0 { self.resumePlayback() } else { self.player?.pause() }
            },
            onSkipForward: { [weak self] in self?.skip(by: 10) },
            onSkipBackward: { [weak self] in self?.skip(by: -10) }
        )
        nowPlayingManager?.start(title: nowPlayingTitle ?? "",
                                 artworkURL: nowPlayingArtworkURL,
                                 duration: duration)
    }

    private func observeAudioSessionNotifications() {
        let center = NotificationCenter.default
        interruptionObserver = center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleAudioInterruption(note: note)
        }
        routeChangeObserver = center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleRouteChange(note: note)
        }
    }
    
    private func removeAudioSessionNotifications() {
        let center = NotificationCenter.default
        if let obs = interruptionObserver { center.removeObserver(obs) }
        if let obs = routeChangeObserver { center.removeObserver(obs) }
        interruptionObserver = nil
        routeChangeObserver = nil
    }
    
    private func handleAudioInterruption(note: Notification) {
        guard let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            syncProgress(force: true)
            player?.pause()
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if options.contains(.shouldResume) {
                resumePlayback()
            }
        @unknown default:
            break
        }
    }
    
    private func handleRouteChange(note: Notification) {
        guard let info = note.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        if reason == .oldDeviceUnavailable {
            // e.g., headphones unplugged
            syncProgress(force: true)
            player?.pause()
        }
    }
}
