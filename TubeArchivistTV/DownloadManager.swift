//
//  DownloadManager.swift
//  TubeTV
//

import Foundation
import Combine

@MainActor
class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloadedVideos: Set<String> = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var activeDownloads: Set<String> = []
    
    private var session: URLSession!
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private let fileManager = FileManager.default
    
    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.tubetv.download")
        config.httpAdditionalHeaders = ["Authorization": "Token \(Configuration.apiToken)"]
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
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
        let url = cacheDirectory().appendingPathComponent("\(videoID).mp4")
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
    
    /// Download a video
    func downloadVideo(_ video: Video) {
        guard let videoID = video.youtubeID else {
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
            return
        }
        
        // Start download
        let task = session.downloadTask(with: url)
        task.taskDescription = videoID
        activeTasks[videoID] = task
        activeDownloads.insert(videoID)
        downloadProgress[videoID] = 0.0
        task.resume()
        
        print("Started download for video: \(videoID)")
    }
    
    /// Delete a downloaded video
    func deleteVideo(videoID: String) {
        guard let fileURL = localURL(for: videoID) else {
            print("Video not found: \(videoID)")
            return
        }
        
        do {
            try fileManager.removeItem(at: fileURL)
            downloadedVideos.remove(videoID)
            saveDownloadedVideos()
            print("Deleted video: \(videoID)")
        } catch {
            print("Error deleting video: \(error.localizedDescription)")
        }
    }
    
    /// Cancel an active download
    func cancelDownload(videoID: String) {
        guard let task = activeTasks[videoID] else { return }
        task.cancel()
        activeTasks.removeValue(forKey: videoID)
        activeDownloads.remove(videoID)
        downloadProgress.removeValue(forKey: videoID)
        print("Cancelled download for video: \(videoID)")
    }
    
    /// Get all downloaded videos from the API's video list
    func getDownloadedVideos(from allVideos: [Video]) -> [Video] {
        return allVideos.filter { video in
            guard let videoID = video.youtubeID else { return false }
            return isDownloaded(videoID: videoID)
        }
    }
    
    // MARK: - Private Methods
    
    private func cacheDirectory() -> URL {
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VideoDownloads", isDirectory: true)
    }
    
    private func ensureCacheDirectoryExists() {
        let directory = cacheDirectory()
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    private func loadDownloadedVideos() {
        ensureCacheDirectoryExists()
        
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
    }
    
    private func saveDownloadedVideos() {
        UserDefaults.standard.set(Array(downloadedVideos), forKey: "downloadedVideos")
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
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let videoID = downloadTask.taskDescription else { return }
        
        // Use a local FileManager instance since we're in a nonisolated context
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VideoDownloads", isDirectory: true)
        let destinationURL = cacheDir.appendingPathComponent("\(videoID).mp4")
        
        do {
            // Ensure directory exists
            if !fileManager.fileExists(atPath: cacheDir.path) {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // Move downloaded file to cache
            try fileManager.moveItem(at: location, to: destinationURL)
            
            // Update state on MainActor
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.downloadedVideos.insert(videoID)
                self.saveDownloadedVideos()
                self.activeDownloads.remove(videoID)
                self.activeTasks.removeValue(forKey: videoID)
                self.downloadProgress.removeValue(forKey: videoID)
                
                print("Download completed for video: \(videoID)")
            }
        } catch {
            print("Error saving downloaded video: \(error.localizedDescription)")
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let videoID = downloadTask.taskDescription else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        Task { @MainActor in
            downloadProgress[videoID] = progress
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let videoID = task.taskDescription else { return }
        
        if let error = error {
            print("Download failed for video \(videoID): \(error.localizedDescription)")
            
            Task { @MainActor in
                activeDownloads.remove(videoID)
                activeTasks.removeValue(forKey: videoID)
                downloadProgress.removeValue(forKey: videoID)
            }
        }
    }
}
