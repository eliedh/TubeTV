//
//  DownloadsView.swift
//  TubeTV
//

import SwiftUI

struct DownloadsView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
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

    /// Comes from metadata stored with each download, so this works offline and
    /// isn't limited to whatever happens to be on the first page of the library
    private var downloadedVideos: [Video] {
        downloadManager.downloadedVideoList
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
                    // PlayerPresenter plays the local file when one exists
                    PlayerPresenter.present(video: video)
                    selectedVideoID = video.youtubeID ?? video.id
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
}
