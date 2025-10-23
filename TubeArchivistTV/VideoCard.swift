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
            VStack(spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: video.derivedThumbnailURLString ?? "")) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 400, height: 225)
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
                .frame(width: 400, height: 225)
                .cornerRadius(12)
                .shadow(radius: 5)
                .opacity(video.watched ? 0.5 : 1.0)
                
                // Title
                Text(video.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 400)
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(16)
            .shadow(color: shadowColor, radius: 8)
        }
        .buttonStyle(.plain)
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
