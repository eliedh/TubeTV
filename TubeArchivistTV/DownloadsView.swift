//
//  DownloadsView.swift
//  TubeTV
//

import SwiftUI

struct DownloadsView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    @EnvironmentObject var settings: AppSettings
    @State private var selectedVideoID: String?
    @State private var pendingBulkDelete: BulkDelete?
    @AppStorage(DownloadManager.wifiOnlyDefaultsKey) private var wifiOnly = false

    private enum BulkDelete: Identifiable {
        case watched, all
        var id: Self { self }
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
                        VStack(spacing: Layout.sectionSpacing) {
                            storageSummary
                            videoGrid
                        }
                        .padding()
                    }
                }
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    manageMenu
                }
            }
            .confirmationDialog(
                confirmationTitle,
                isPresented: Binding(
                    get: { pendingBulkDelete != nil },
                    set: { if !$0 { pendingBulkDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingBulkDelete
            ) { action in
                Button("Delete", role: .destructive) {
                    switch action {
                    case .watched: downloadManager.deleteWatchedVideos()
                    case .all: downloadManager.deleteAllVideos()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var storageSummary: some View {
        HStack {
            Image(systemName: "internaldrive")
            Text("\(downloadedVideos.count) \(downloadedVideos.count == 1 ? "video" : "videos") · \(formattedStorage)")
            Spacer()
            if wifiOnly {
                Label("Wi-Fi only", systemImage: "wifi")
                    .labelStyle(.titleAndIcon)
            }
        }
        .font(.subheadline)
        .foregroundColor(.gray)
    }

    private var formattedStorage: String {
        ByteCountFormatter.string(fromByteCount: downloadManager.storageUsed, countStyle: .file)
    }

    private var manageMenu: some View {
        Menu {
            Button(role: .destructive) {
                pendingBulkDelete = .watched
            } label: {
                Label("Delete Watched (\(downloadManager.watchedDownloadIDs.count))", systemImage: "eye")
            }
            .disabled(downloadManager.watchedDownloadIDs.isEmpty)

            Button(role: .destructive) {
                pendingBulkDelete = .all
            } label: {
                Label("Delete All Downloads", systemImage: "trash")
            }
            .disabled(downloadedVideos.isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
        }
    }

    private var confirmationTitle: String {
        switch pendingBulkDelete {
        case .watched:
            let count = downloadManager.watchedDownloadIDs.count
            return "Delete \(count) watched \(count == 1 ? "download" : "downloads")?"
        case .all:
            return "Delete all downloads (\(formattedStorage))?"
        case nil:
            return ""
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
        LazyVGrid(columns: Layout.gridColumns, spacing: Layout.gridSpacing) {
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
}
