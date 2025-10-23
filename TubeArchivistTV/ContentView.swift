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
            // iPhone: Vertical compact layout
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Toggle(isOn: $showUnwatchedOnly) {
                        Text("Unwatched Only")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: showUnwatchedOnly) {
                        api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded)
                    }
                    
                    Spacer()
                    
                    Button(action: { api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded) }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
                
                HStack {
                    Toggle(isOn: $sortByDownloaded) {
                        Text(sortByDownloaded ? "Sort: Downloaded" : "Sort: Published")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: sortByDownloaded) {
                        api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded)
                    }
                    
                    Spacer()
                }
            }
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
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.gray)
            .cornerRadius(10)
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Actions
    
    private func handleVideoTap(_ video: Video) {
        PlayerPresenter.present(video: video, token: Configuration.apiToken)
        selectedVideoID = video.youtubeID ?? video.id
    }
}
