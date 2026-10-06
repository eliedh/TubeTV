//
//  DownloadManager.swift
//  TubeTV
//

import Foundation
import Combine

@MainActor
class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    static let sessionIdentifier = "com.tubetv.download"
    /// UserDefaults key for the "download over Wi-Fi only" setting
    static let wifiOnlyDefaultsKey = "downloadsWiFiOnly"

    @Published var downloadedVideos: Set<String> = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var activeDownloads: Set<String> = []
    /// Videos whose last download attempt failed, with a user-facing reason
    @Published var failedDownloads: [String: String] = [:]
    /// Metadata for downloaded (and in-flight) videos, so the Downloads tab works offline
    @Published private(set) var storedVideos: [String: Video] = [:]
    /// Disk space used by downloads (videos, thumbnails, metadata), in bytes
    @Published private(set) var storageUsed: Int64 = 0

    /// Completion handler handed to us by the system when it relaunches the app for background downloads
    var backgroundCompletionHandler: (() -> Void)?

    private var session: URLSession!
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private let fileManager = FileManager.default

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        migrateFromCachesIfNeeded()
        loadDownloadedVideos()
        resumePendingDownloads()
    }

    // MARK: - Public Methods

    /// Check if a video is already downloaded
    func isDownloaded(videoID: String) -> Bool {
        return downloadedVideos.contains(videoID)
    }

    /// Get the local file URL for a downloaded video
    func localURL(for videoID: String) -> URL? {
        let url = Self.videoFileURL(for: videoID)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    /// Get the locally saved thumbnail for a downloaded video
    func localThumbnailURL(for videoID: String) -> URL? {
        let url = Self.thumbnailFileURL(for: videoID)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    /// Download a video
    func downloadVideo(_ video: Video) {
        guard let videoID = video.canonicalVideoID else {
            print("Cannot download video without YouTube ID")
            return
        }

        // Check if already downloaded or downloading
        if isDownloaded(videoID: videoID) {
            print("Video already downloaded: \(videoID)")
            return
        }

        if activeDownloads.contains(videoID) {
            print("Video already downloading: \(videoID)")
            return
        }

        // Create download URL
        let urlString = video.derivedURLString
        guard let url = URL(string: urlString) else {
            print("Invalid video URL: \(urlString)")
            failedDownloads[videoID] = "Invalid video URL"
            return
        }

        // Persist metadata up front so a download that finishes while the app is
        // suspended (or after a relaunch) still shows up in the Downloads tab
        saveMetadata(video, for: videoID)
        saveThumbnail(for: video, videoID: videoID)

        // Start download
        var request = Configuration.makeAuthorizedRequest(url: url)
        if UserDefaults.standard.bool(forKey: Self.wifiOnlyDefaultsKey) {
            // The background session waits for Wi-Fi instead of using cellular / hotspot data
            request.allowsCellularAccess = false
            request.allowsExpensiveNetworkAccess = false
        }
        let task = session.downloadTask(with: request)
        task.taskDescription = videoID
        activeTasks[videoID] = task
        activeDownloads.insert(videoID)
        failedDownloads.removeValue(forKey: videoID)
        downloadProgress[videoID] = 0.0
        task.resume()

        print("Started download for video: \(videoID)")
    }

    /// Delete a downloaded video
    func deleteVideo(videoID: String) {
        do {
            if let fileURL = localURL(for: videoID) {
                try fileManager.removeItem(at: fileURL)
            }
            removeSidecarFiles(for: videoID)
            downloadedVideos.remove(videoID)
            saveDownloadedVideos()
            updateStorageUsed()
            print("Deleted video: \(videoID)")
        } catch {
            print("Error deleting video: \(error.localizedDescription)")
        }
    }

    /// Cancel an active download
    func cancelDownload(videoID: String) {
        activeTasks[videoID]?.cancel()
        activeTasks.removeValue(forKey: videoID)
        activeDownloads.remove(videoID)
        downloadProgress.removeValue(forKey: videoID)
        if !isDownloaded(videoID: videoID) {
            removeSidecarFiles(for: videoID)
        }
        print("Cancelled download for video: \(videoID)")
    }

    /// Downloaded videos already marked as watched
    var watchedDownloadIDs: [String] {
        downloadedVideos.filter { storedVideos[$0]?.watched == true }
    }

    /// Deletes every downloaded video that has been watched
    func deleteWatchedVideos() {
        for videoID in watchedDownloadIDs {
            deleteVideo(videoID: videoID)
        }
    }

    /// Deletes all downloads
    func deleteAllVideos() {
        for videoID in downloadedVideos {
            deleteVideo(videoID: videoID)
        }
    }

    /// All downloaded videos with their stored metadata, newest first
    var downloadedVideoList: [Video] {
        downloadedVideos
            .compactMap { storedVideos[$0] }
            .sorted { $0.published > $1.published }
    }

    /// Keep stored resume position / watched state in sync with local playback, so
    /// offline viewing resumes from the right place even across app launches
    func updatePlaybackState(videoID: String, position: Double?, watched: Bool) {
        guard let video = storedVideos[videoID] else { return }
        saveMetadata(video.withPlayback(position: position, watched: watched), for: videoID)
    }

    /// Downloads made by older versions have no stored metadata; fill it in from fetched server data
    func backfillMetadata(from videos: [Video]) {
        for video in videos {
            guard let videoID = video.canonicalVideoID,
                  isDownloaded(videoID: videoID),
                  storedVideos[videoID] == nil else { continue }
            saveMetadata(video, for: videoID)
            if localThumbnailURL(for: videoID) == nil {
                saveThumbnail(for: video, videoID: videoID)
            }
        }
    }

    // MARK: - File Locations

    /// Application Support (not Caches) so iOS doesn't purge offline videos under storage pressure.
    /// tvOS has no persistent local storage for apps, so it keeps using Caches.
    nonisolated static func downloadsDirectory() -> URL {
        #if os(tvOS)
        let base = FileManager.SearchPathDirectory.cachesDirectory
        #else
        let base = FileManager.SearchPathDirectory.applicationSupportDirectory
        #endif
        return FileManager.default.urls(for: base, in: .userDomainMask)[0]
            .appendingPathComponent("VideoDownloads", isDirectory: true)
    }

    nonisolated static func videoFileURL(for videoID: String) -> URL {
        downloadsDirectory().appendingPathComponent("\(videoID).mp4")
    }

    nonisolated static func thumbnailFileURL(for videoID: String) -> URL {
        downloadsDirectory().appendingPathComponent("\(videoID).jpg")
    }

    nonisolated static func metadataFileURL(for videoID: String) -> URL {
        downloadsDirectory().appendingPathComponent("\(videoID).json")
    }

    nonisolated static func ensureDownloadsDirectoryExists() throws {
        var directory = downloadsDirectory()
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Videos can be re-downloaded from the server, so keep them out of iCloud backups
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
    }

    // MARK: - Private Methods

    /// Earlier versions stored downloads in Caches; move them so they survive storage pressure
    private func migrateFromCachesIfNeeded() {
        #if !os(tvOS)
        let legacyDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VideoDownloads", isDirectory: true)
        guard let legacyFiles = try? fileManager.contentsOfDirectory(at: legacyDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        try? Self.ensureDownloadsDirectoryExists()
        for file in legacyFiles {
            let destination = Self.downloadsDirectory().appendingPathComponent(file.lastPathComponent)
            if !fileManager.fileExists(atPath: destination.path) {
                try? fileManager.moveItem(at: file, to: destination)
            }
        }
        try? fileManager.removeItem(at: legacyDirectory)
        #endif
    }

    private func loadDownloadedVideos() {
        try? Self.ensureDownloadsDirectoryExists()

        // Load from UserDefaults
        if let saved = UserDefaults.standard.array(forKey: "downloadedVideos") as? [String] {
            downloadedVideos = Set(saved)
        }

        // Verify files still exist and clean up missing ones
        var validVideos: Set<String> = []
        for videoID in downloadedVideos {
            if localURL(for: videoID) != nil {
                validVideos.insert(videoID)
            }
        }

        if validVideos != downloadedVideos {
            downloadedVideos = validVideos
            saveDownloadedVideos()
        }
        updateStorageUsed()

        // Load stored metadata
        let decoder = JSONDecoder()
        let files = (try? fileManager.contentsOfDirectory(at: Self.downloadsDirectory(), includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let video = try? decoder.decode(Video.self, from: data),
               let videoID = video.canonicalVideoID {
                storedVideos[videoID] = video
            }
        }
    }

    private func updateStorageUsed() {
        let files = (try? fileManager.contentsOfDirectory(
            at: Self.downloadsDirectory(),
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        storageUsed = files.reduce(0) { total, file in
            total + Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    private func saveDownloadedVideos() {
        UserDefaults.standard.set(Array(downloadedVideos), forKey: "downloadedVideos")
    }

    private func saveMetadata(_ video: Video, for videoID: String) {
        storedVideos[videoID] = video
        do {
            try Self.ensureDownloadsDirectoryExists()
            let data = try JSONEncoder().encode(video)
            try data.write(to: Self.metadataFileURL(for: videoID), options: .atomic)
        } catch {
            print("Error saving metadata for \(videoID): \(error.localizedDescription)")
        }
    }

    private func saveThumbnail(for video: Video, videoID: String) {
        guard let thumbnailURL = video.thumbnailURL else { return }
        Task {
            do {
                let data = try await ImageLoader.shared.data(for: thumbnailURL)
                try Self.ensureDownloadsDirectoryExists()
                try data.write(to: Self.thumbnailFileURL(for: videoID), options: .atomic)
            } catch {
                print("Error saving thumbnail for \(videoID): \(error.localizedDescription)")
            }
        }
    }

    private func removeSidecarFiles(for videoID: String) {
        try? fileManager.removeItem(at: Self.metadataFileURL(for: videoID))
        try? fileManager.removeItem(at: Self.thumbnailFileURL(for: videoID))
        storedVideos.removeValue(forKey: videoID)
    }

    private func resumePendingDownloads() {
        Task {
            let tasks = await session.allTasks
            for task in tasks {
                if let downloadTask = task as? URLSessionDownloadTask,
                   let videoID = task.taskDescription {
                    activeTasks[videoID] = downloadTask
                    activeDownloads.insert(videoID)
                }
            }
        }
    }

    private func markFailed(videoID: String, reason: String) {
        activeDownloads.remove(videoID)
        activeTasks.removeValue(forKey: videoID)
        downloadProgress.removeValue(forKey: videoID)
        failedDownloads[videoID] = reason
        if !isDownloaded(videoID: videoID) {
            removeSidecarFiles(for: videoID)
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let videoID = downloadTask.taskDescription else { return }

        // A background download "finishes" even when the server answered with an error page
        // (e.g. 401/404). Don't save that HTML as an .mp4.
        if let httpResponse = downloadTask.response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let statusCode = httpResponse.statusCode
            print("Download failed for video \(videoID): HTTP \(statusCode)")
            Task { @MainActor in
                self.markFailed(videoID: videoID, reason: "Server returned HTTP \(statusCode)")
            }
            return
        }

        // The temporary file is deleted as soon as this method returns, so move it synchronously
        let fileManager = FileManager.default
        let destinationURL = DownloadManager.videoFileURL(for: videoID)

        do {
            try DownloadManager.ensureDownloadsDirectoryExists()

            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            // Move downloaded file into place
            try fileManager.moveItem(at: location, to: destinationURL)

            // Update state on MainActor
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.downloadedVideos.insert(videoID)
                self.saveDownloadedVideos()
                self.activeDownloads.remove(videoID)
                self.activeTasks.removeValue(forKey: videoID)
                self.downloadProgress.removeValue(forKey: videoID)
                self.failedDownloads.removeValue(forKey: videoID)
                self.updateStorageUsed()

                print("Download completed for video: \(videoID)")
            }
        } catch {
            print("Error saving downloaded video: \(error.localizedDescription)")
            let message = error.localizedDescription
            Task { @MainActor in
                self.markFailed(videoID: videoID, reason: message)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let videoID = downloadTask.taskDescription,
              totalBytesExpectedToWrite > 0 else { return } // Unknown length (-1) would give a negative progress

        let progress = min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))

        Task { @MainActor in
            // Ignore late progress callbacks after cancel/completion
            guard activeDownloads.contains(videoID) else { return }
            downloadProgress[videoID] = progress
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let videoID = task.taskDescription, let error else { return }

        if (error as? URLError)?.code == .cancelled {
            // User-initiated cancel; state was already cleaned up in cancelDownload
            Task { @MainActor in
                activeDownloads.remove(videoID)
                activeTasks.removeValue(forKey: videoID)
                downloadProgress.removeValue(forKey: videoID)
            }
            return
        }

        print("Download failed for video \(videoID): \(error.localizedDescription)")
        let message = error.localizedDescription
        Task { @MainActor in
            markFailed(videoID: videoID, reason: message)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            backgroundCompletionHandler?()
            backgroundCompletionHandler = nil
        }
    }
}
