//
//  DownloadsView.swift
//  TubeTV
//

import SwiftUI

struct DownloadsView: View {
    @StateObject private var api = APIService()
    @StateObject private var downloadManager = DownloadManager.shared
    @EnvironmentObject var settings: AppSettings
    @State private var selectedVideoID: String?
    
    private var columns: [GridItem] {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: 3 columns
            [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        } else {
            // iPhone: 2 columns
            [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
        }
    }
    
    private var downloadedVideos: [Video] {
        downloadManager.getDownloadedVideos(from: api.videos)
    }
    
    var body: some View {
        NavigationView {
            Group {
                if downloadedVideos.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: platformSpacing) {
                            videoGrid
                        }
                        .padding()
                    }
                }
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Downloads")
            .onAppear {
                // Fetch videos to match with downloaded IDs
                if api.videos.isEmpty {
                    api.fetchVideos(unwatchedOnly: false, sortByDownloaded: false)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var platformSpacing: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            18  // iPad
        } else {
            16  // iPhone
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Downloaded Videos")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Long press on any video to download it for offline viewing")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var videoGrid: some View {
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(downloadedVideos) { video in
                VideoCard(
                    video: video,
                    isSelected: selectedVideoID == (video.youtubeID ?? video.id),
                    showDownloadStatus: true
                ) {
                    handleVideoTap(video)
                }
            }
        }
    }
    
    private var gridSpacing: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            24  // iPad
        } else {
            16  // iPhone
        }
    }
    
    private func handleVideoTap(_ video: Video) {
        // Play from local storage if downloaded
        if let videoID = video.youtubeID,
           let localURL = downloadManager.localURL(for: videoID) {
            PlayerPresenter.presentLocal(url: localURL)
            selectedVideoID = videoID
        } else {
            // Fallback to streaming if somehow the file is missing
            PlayerPresenter.present(video: video, token: Configuration.apiToken)
            selectedVideoID = video.youtubeID ?? video.id
        }
    }
}
