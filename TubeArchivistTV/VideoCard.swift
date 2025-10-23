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
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: cardSpacing) {
                // Thumbnail
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
    }
    
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
