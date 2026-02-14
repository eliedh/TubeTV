import SwiftUI

struct ContentView: View {
    @StateObject private var api = APIService()
    @EnvironmentObject var settings: AppSettings
    @State private var selectedVideoID: String?
    @State private var showUnwatchedOnly = false
    @State private var sortByDownloaded = true
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
                    videoGrid
                    if api.hasMorePages {
                        loadMoreButton
                    }
                }
                .padding()
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            #if os(iOS)
            .refreshable {
                // Simulate async operation for refresh
                try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second delay to ensure UI updates
                api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded)
            }
            #endif
            .onAppear { api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded) }
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
            Toggle(isOn: $showUnwatchedOnly) {
                Text("Unwatched Only")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .onChange(of: showUnwatchedOnly) {
                api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded)
            }
            Toggle(isOn: $sortByDownloaded) {
                Text(sortByDownloaded ? "Sort: Downloaded" : "Sort: Published")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .onChange(of: sortByDownloaded) {
                api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded)
            }
            Button(action: { api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded) }) {
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
                Toggle(isOn: $showUnwatchedOnly) {
                    Text("Unwatched Only")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: showUnwatchedOnly) {
                    api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded)
                }
                
                Toggle(isOn: $sortByDownloaded) {
                    Text(sortByDownloaded ? "Sort: Downloaded" : "Sort: Published")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: sortByDownloaded) {
                    api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded)
                }
                
                Spacer()
                
                Button(action: { api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded) }) {
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
                // First row: Unwatched filter with refresh button
                HStack(spacing: 12) {
                    Toggle(isOn: $showUnwatchedOnly) {
                        Text("Unwatched")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: showUnwatchedOnly) {
                        api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded)
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
                        api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded)
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
                Image(systemName: "chevron.down")
                Text("Load More")
                    .font(.headline)
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
        .padding(.bottom, 30)
    }
    
    // MARK: - Actions
    
    private func handleVideoTap(_ video: Video) {
        PlayerPresenter.present(video: video, token: Configuration.apiToken)
        selectedVideoID = video.youtubeID ?? video.id
    }
}
