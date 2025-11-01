//
//  SkippingPlayerViewController.swift
//  TubeTV
//

import AVKit
import UIKit
import MediaPlayer

final class SkippingPlayerViewController: AVPlayerViewController {
    private var timeControlStatusObservation: NSKeyValueObservation?
    private var timeObserverToken: Any?
    private var didTriggerWatched: Bool = false
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    
    // Now Playing
    private var nowPlayingManager: NowPlayingManager?
    var nowPlayingTitle: String?
    var nowPlayingArtworkURL: URL?
    
    // Playback speed settings
    private var currentSpeedIndex: Int = 2 // Default to 1.0x
    private let playbackSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCustomTransportBarItems()
        setupiOSControls()
    }
    
    private func setupiOSControls() {
        #if os(iOS)
        // On iOS, we can add a double-tap gesture to cycle through speeds
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(doubleTapGesture)
        #endif
    }
    
    #if os(iOS)
    @objc private func handleDoubleTap() {
        // Cycle to next speed
        currentSpeedIndex = (currentSpeedIndex + 1) % playbackSpeeds.count
        let newSpeed = playbackSpeeds[currentSpeedIndex]
        player?.rate = newSpeed
        
        // Show a brief notification of the new speed
        showSpeedNotification(speed: newSpeed)
    }
    
    private func showSpeedNotification(speed: Float) {
        let alertController = UIAlertController(title: "Playback Speed", message: "\(speed)×", preferredStyle: .alert)
        present(alertController, animated: true)
        
        // Dismiss after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            alertController.dismiss(animated: true)
        }
    }
    #endif

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observePlaybackForIdleTimer()
        observeFivePercentRemaining()
        setupNowPlaying()
        observeAudioSessionNotifications()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        timeControlStatusObservation?.invalidate()
        timeControlStatusObservation = nil
        if let token = timeObserverToken, let player = player {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        nowPlayingManager?.stop()
        nowPlayingManager = nil
        removeAudioSessionNotifications()
    }
    
    // MARK: - Custom Transport Bar Items
    
    private func setupCustomTransportBarItems() {
        #if os(tvOS)
        if #available(tvOS 14.0, *) {
            // Create speed control menu
            let speedMenu = createSpeedMenu()
            
            // Assign custom transport bar items
            self.transportBarCustomMenuItems = [speedMenu]
        }
        #endif
    }
    
    private func createSpeedMenu() -> UIMenu {
        let speedActions = playbackSpeeds.enumerated().map { index, speed -> UIAction in
            let isCurrentSpeed = index == currentSpeedIndex
            let action = UIAction(
                title: "\(speed)×",
                image: isCurrentSpeed ? UIImage(systemName: "checkmark") : nil,
                state: isCurrentSpeed ? .on : .off
            ) { [weak self] _ in
                self?.setPlaybackSpeed(speed, at: index)
            }
            return action
        }
        
        return UIMenu(
            title: "Speed",
            image: UIImage(systemName: "speedometer"),
            children: speedActions
        )
    }
    
    private func setPlaybackSpeed(_ speed: Float, at index: Int) {
        guard let player = player else { return }
        
        // Update current speed index
        currentSpeedIndex = index
        
        // Apply new speed
        player.rate = speed
        
        // Recreate the menu to update checkmarks
        #if os(tvOS)
        if #available(tvOS 14.0, *) {
            let updatedMenu = createSpeedMenu()
            self.transportBarCustomMenuItems = [updatedMenu]
        }
        #endif
        
        print("Playback speed changed to \(speed)×")
    }
    
    // MARK: - Watch Progress Tracking
    
    private func observeFivePercentRemaining() {
        guard let player = player, let item = player.currentItem else { return }
        // Poll every half second
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] currentTime in
            guard let self = self, !self.didTriggerWatched else { return }
            let duration = item.duration.seconds
            let current = currentTime.seconds
            guard duration.isFinite, duration > 0 else { return }
            let remaining = duration - current
            let tenPercent = duration * 0.10
            let threshold = max(tenPercent, 30.0)
            if remaining <= threshold {
                self.didTriggerWatched = true
                self.markWatched()
            }
            // Update Now Playing elapsed time
            self.nowPlayingManager?.updateElapsedTime(currentTime: current,
                                                      duration: duration,
                                                      rate: self.player?.rate ?? 0)
        }
    }

    private func markWatched() {
        // Extract the video ID from the URL filename
        guard let url = (player?.currentItem?.asset as? AVURLAsset)?.url else { return }
        let filename = url.lastPathComponent
        let id = filename.components(separatedBy: ".").first ?? filename
        
        let payload: [String: Any] = ["id": id, "is_watched": true]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        guard let endpoint = URL(string: Configuration.watchedEndpoint) else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(Configuration.apiToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error posting watched status: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("Watched status updated successfully (HTTP \(httpResponse.statusCode))")
            }
        }.resume()
    }
    
    // MARK: - Idle Timer & Playback Observation

    private func observePlaybackForIdleTimer() {
        guard let player = player else { return }
        timeControlStatusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { player, _ in
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = (player.timeControlStatus == .playing)
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }

    @objc private func didFinishPlaying() {
        UIApplication.shared.isIdleTimerDisabled = false
        // Dismiss the player and return to ContentView
        if let presentingVC = self.presentingViewController {
            presentingVC.dismiss(animated: true)
        } else {
            self.dismiss(animated: true)
        }
    }
    
    // MARK: - Remote Control (Skip Forward/Backward)

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        #if os(tvOS)
        guard let press = presses.first else {
            super.pressesEnded(presses, with: event)
            return
        }

        switch press.type {
        case .leftArrow:
            skip(by: -10)
        case .rightArrow:
            skip(by: 10)
        default:
            super.pressesEnded(presses, with: event)
        }
        #else
        super.pressesEnded(presses, with: event)
        #endif
    }

    private func skip(by seconds: Double) {
        guard let player = player, player.currentItem != nil else { return }
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = max(0, currentTime + seconds)
        
        // Use 1 as timescale for simplicity since we're dealing with seconds
        let time = CMTime(seconds: newTime, preferredTimescale: 1)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Now Playing & Remote Commands
    private func setupNowPlaying() {
        guard let player = player else { return }
        let duration = player.currentItem?.asset.duration.seconds
        nowPlayingManager = NowPlayingManager(
            player: player,
            onPlay: { [weak self] in self?.player?.play() },
            onPause: { [weak self] in self?.player?.pause() },
            onToggle: { [weak self] in
                guard let self = self else { return }
                if self.player?.rate == 0 { self.player?.play() } else { self.player?.pause() }
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
            player?.pause()
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if options.contains(.shouldResume) {
                player?.play()
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
            player?.pause()
        }
    }
}
