import SwiftUI

struct ContentView: View {
    @StateObject private var api = APIService()
    @EnvironmentObject var settings: AppSettings
    @State private var selectedVideoID: String?
    @State private var showUnwatchedOnly = false
    @State private var sortByDownloaded = true
    @State private var showSettings = false

    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
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
            .navigationBarItems(trailing: Button(action: { showSettings = true }) {
                Image(systemName: "gear")
                    .font(.title2)
            })
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: settings)
            }
        }
    }
    
    // MARK: - View Components
    
    private var controlsBar: some View {
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
            // .toggleStyle(SwitchToggleStyle(tint: .blue)) // Not available on tvOS
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
    }
    
    private var videoGrid: some View {
        LazyVGrid(columns: columns, spacing: 30) {
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
