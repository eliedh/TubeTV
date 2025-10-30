//
//  VideoCard.swift
//  TubeTV
//
//  Created by Copilot on 22.10.25.
//

import SwiftUI

struct VideoCard: View {
    let video: Video
    let isSelected: Bool
    let showDownloadStatus: Bool
    let onTap: () -> Void
    
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var showDownloadOptions = false
    
    init(video: Video, isSelected: Bool, showDownloadStatus: Bool = false, onTap: @escaping () -> Void) {
        self.video = video
        self.isSelected = isSelected
        self.showDownloadStatus = showDownloadStatus
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: cardSpacing) {
                // Thumbnail
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: video.derivedThumbnailURLString ?? "")) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Color.red
                        @unknown default:
                            Color.gray
                        }
                    }
                    .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                    .cornerRadius(cornerRadius)
                    .shadow(radius: 5)
                    .opacity(video.watched ? 0.5 : 1.0)
                    
                    // Download status indicators (iOS only)
                    #if os(iOS)
                    if showDownloadStatus || downloadManager.isDownloaded(videoID: video.youtubeID ?? "") {
                        downloadStatusBadge
                    } else if let progress = downloadManager.downloadProgress[video.youtubeID ?? ""] {
                        downloadProgressView(progress: progress)
                    }
                    #endif
                }
                
                // Title
                Text(video.title)
                    .font(titleFont)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(titleLineLimit)
                    .frame(maxWidth: thumbnailSize.width)
            }
            .padding(cardPadding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: shadowColor, radius: shadowRadius)
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .contextMenu {
            downloadContextMenu
        }
        #endif
    }
    
    // MARK: - iOS Download UI Components
    
    #if os(iOS)
    @ViewBuilder
    private var downloadStatusBadge: some View {
        Image(systemName: "arrow.down.circle.fill")
            .font(.title2)
            .foregroundColor(.green)
            .background(Circle().fill(Color.black.opacity(0.7)).padding(-4))
            .padding(8)
    }
    
    @ViewBuilder
    private func downloadProgressView(progress: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 44, height: 44)
            
            CircularProgressView(progress: progress)
                .frame(width: 36, height: 36)
        }
        .padding(8)
    }
    
    @ViewBuilder
    private var downloadContextMenu: some View {
        if let videoID = video.youtubeID {
            if downloadManager.isDownloaded(videoID: videoID) {
                Button(role: .destructive) {
                    downloadManager.deleteVideo(videoID: videoID)
                } label: {
                    Label("Delete Download", systemImage: "trash")
                }
            } else if downloadManager.activeDownloads.contains(videoID) {
                Button(role: .destructive) {
                    downloadManager.cancelDownload(videoID: videoID)
                } label: {
                    Label("Cancel Download", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    downloadManager.downloadVideo(video)
                } label: {
                    Label("Download for Offline", systemImage: "arrow.down.circle")
                }
            }
        }
    }
    #endif
    
    // MARK: - Platform-specific properties
    
    private var thumbnailSize: CGSize {
        #if os(tvOS)
        CGSize(width: 400, height: 225)
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Larger than iPhone but smaller than tvOS
            CGSize(width: 240, height: 135)
        } else {
            // iPhone: Compact size
            CGSize(width: 160, height: 90)
        }
        #endif
    }
    
    private var cardSpacing: CGFloat {
        #if os(tvOS)
        12
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            10  // iPad: between tvOS and iPhone
        } else {
            8   // iPhone
        }
        #endif
    }
    
    private var cardPadding: CGFloat {
        #if os(tvOS)
        16
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            12  // iPad: between tvOS and iPhone
        } else {
            8   // iPhone
        }
        #endif
    }
    
    private var cornerRadius: CGFloat {
        #if os(tvOS)
        16
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            14  // iPad: between tvOS and iPhone
        } else {
            12  // iPhone
        }
        #endif
    }
    
    private var shadowRadius: CGFloat {
        #if os(tvOS)
        8
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            6  // iPad: between tvOS and iPhone
        } else {
            4  // iPhone
        }
        #endif
    }
    
    private var titleFont: Font {
        #if os(tvOS)
        .headline
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            .subheadline  // iPad: between tvOS and iPhone
        } else {
            .caption      // iPhone
        }
        #endif
    }
    
    private var titleLineLimit: Int {
        #if os(tvOS)
        2
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            2  // iPad: same as tvOS for better readability
        } else {
            3  // iPhone: more lines for smaller text
        }
        #endif
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if video.watched {
            return Color(red: 0.3, green: 0.2, blue: 0.2)
        } else {
            return Color(.darkGray)
        }
    }
    
    private var shadowColor: Color {
        isSelected ? Color.blue.opacity(0.5) : Color.black.opacity(0.5)
    }
}

// MARK: - Circular Progress View

#if os(iOS)
struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
#endif
