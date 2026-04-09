import SwiftUI

struct ContentView: View {
    @StateObject private var api = APIService()
    @EnvironmentObject var settings: AppSettings
    @State private var selectedVideoID: String?
    @State private var showUnwatchedOnly = false
    @State private var sortByDownloaded = true
    @State private var showContinueWatching = false
    @State private var showSettings = false

    private var columns: [GridItem] {
        #if os(tvOS)
        [
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20)
        ]
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: 3 columns like tvOS but with tighter spacing
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
        #endif
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: platformSpacing) {
                    controlsBar
                    if let errorMessage = api.errorMessage, !api.videos.isEmpty {
                        inlineErrorBanner(message: errorMessage)
                    }
                    contentBody
                    if api.hasMorePages && !api.videos.isEmpty {
                        loadMoreButton
                    }
                }
                .padding()
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            #if os(iOS)
            .refreshable {
                await api.reloadVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching)
            }
            #endif
            .onAppear {
                if api.videos.isEmpty {
                    api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching)
                }
            }
            .navigationTitle("TubeTV")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: settings)
            }
        }
        #if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
    
    private var platformSpacing: CGFloat {
        #if os(tvOS)
        20
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            18  // iPad: between tvOS and iPhone
        } else {
            16  // iPhone
        }
        #endif
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var controlsBar: some View {
        #if os(tvOS)
        HStack(spacing: 24) {
            Spacer()
            Toggle(isOn: $showContinueWatching) {
                Text("Continue Watching")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .onChange(of: showContinueWatching) {
                api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching)
            }
            Toggle(isOn: $showUnwatchedOnly) {
                Text("Unwatched Only")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .onChange(of: showUnwatchedOnly) {
                api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching)
            }
            Toggle(isOn: $sortByDownloaded) {
                Text(sortByDownloaded ? "Sort: Downloaded" : "Sort: Published")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .onChange(of: sortByDownloaded) {
                api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching)
            }
            Button(action: { api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching) }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Horizontal layout similar to tvOS but more compact
            HStack(spacing: 20) {
                Toggle(isOn: $showContinueWatching) {
                    Text("Continue Watching")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: showContinueWatching) {
                    api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching)
                }
                
                Toggle(isOn: $showUnwatchedOnly) {
                    Text("Unwatched Only")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: showUnwatchedOnly) {
                    api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching)
                }
                
                Toggle(isOn: $sortByDownloaded) {
                    Text(sortByDownloaded ? "Sort: Downloaded" : "Sort: Published")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: sortByDownloaded) {
                    api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching)
                }
                
                Spacer()
                
                Button(action: { api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            }
        } else {
            // iPhone: Optimized touch-friendly layout
            VStack(spacing: 12) {
                // First row: Continue Watching + Unwatched filter
                HStack(spacing: 12) {
                    Toggle(isOn: $showContinueWatching) {
                        Text("Continue")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .onChange(of: showContinueWatching) {
                        api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching)
                    }
                    
                    Toggle(isOn: $showUnwatchedOnly) {
                        Text("Unwatched")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: showUnwatchedOnly) {
                        api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching)
                    }
                }
                
                // Second row: Sort toggle (full width)
                HStack {
                    Toggle(isOn: $sortByDownloaded) {
                        Text(sortByDownloaded ? "Sorted: New Downloads" : "Sorted: Published")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: sortByDownloaded) {
                        api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching)
                    }
                    
                    Spacer()
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            )
        }
        #endif
    }
    
    private var videoGrid: some View {
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(api.videos) { video in
                VideoCard(
                    video: video,
                    isSelected: selectedVideoID == (video.youtubeID ?? video.id)
                ) {
                    handleVideoTap(video)
                }
            }
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if api.isLoading && api.videos.isEmpty {
            ProgressView("Loading videos...")
                .foregroundColor(.white)
                .padding(.top, 40)
        } else if let errorMessage = api.errorMessage, api.videos.isEmpty {
            fullScreenMessage(
                title: "Couldn’t Load Videos",
                message: errorMessage,
                buttonTitle: "Retry"
            ) {
                api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded)
            }
        } else if api.videos.isEmpty {
            fullScreenMessage(
                title: "No Videos Found",
                message: showUnwatchedOnly ? "Try turning off the unwatched filter or refreshing your library." : "Refresh to try loading your TubeArchivist library again.",
                buttonTitle: "Refresh"
            ) {
                api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded)
            }
        } else {
            videoGrid
        }
    }
    
    private var gridSpacing: CGFloat {
        #if os(tvOS)
        30
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            24  // iPad: between tvOS and iPhone
        } else {
            16  // iPhone
        }
        #endif
    }
    
    private var loadMoreButton: some View {
        Button(action: { api.loadMoreVideos() }) {
            HStack(spacing: 8) {
                if api.isLoadingMore {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "chevron.down")
                    Text("Load More")
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.3, green: 0.3, blue: 0.3))
            )
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(api.isLoadingMore)
        .padding(.bottom, 30)
    }
    
    // MARK: - Actions
    
    private func handleVideoTap(_ video: Video) {
        PlayerPresenter.present(video: video)
        selectedVideoID = video.youtubeID ?? video.id
    }

    private func inlineErrorBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .foregroundColor(.white)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            Spacer()
            Button("Dismiss") {
                api.dismissError()
            }
            .foregroundColor(.white)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.28, green: 0.12, blue: 0.12))
        )
    }

    private func fullScreenMessage(title: String, message: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)

            Button(action: action) {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
