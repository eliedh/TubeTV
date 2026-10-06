import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var api = APIService()
    @EnvironmentObject var settings: AppSettings
    @State private var selectedVideoID: String?
    @State private var showUnwatchedOnly = false
    @State private var sortByDownloaded = true
    @State private var showContinueWatching = false
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Layout.sectionSpacing) {
                    controlsBar
                    if let errorMessage = api.errorMessage, !api.videos.isEmpty {
                        inlineErrorBanner(message: errorMessage)
                    }
                    contentBody
                    if api.hasMorePages && !api.videos.isEmpty {
                        paginationFooter
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
                if api.videos.isEmpty && !api.isLoading {
                    reload()
                }
            }
            .onChange(of: showContinueWatching) { reload() }
            .onChange(of: showUnwatchedOnly) { reload() }
            .onChange(of: sortByDownloaded) { reload() }
            .onReceive(NotificationCenter.default.publisher(for: .playerDidClose)) { notification in
                // Update just the played video's watched state / progress
                guard let videoID = notification.object as? String else { return }
                Task {
                    await api.refreshVideo(videoID: videoID)
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

    // MARK: - View Components

    @ViewBuilder
    private var controlsBar: some View {
        switch Layout.deviceClass {
        case .tv:
            HStack(spacing: 24) {
                Spacer()
                filterToggles
                refreshButton
            }
        case .pad:
            HStack(spacing: 20) {
                filterToggles
                Spacer()
                refreshButton
            }
        case .phone:
            // Two rows; refreshing is done with pull-to-refresh
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    filterToggle("Continue", isOn: $showContinueWatching, tint: .orange)
                    filterToggle("Unwatched", isOn: $showUnwatchedOnly)
                }
                HStack {
                    filterToggle(sortByDownloaded ? "Sorted: New Downloads" : "Sorted: Published", isOn: $sortByDownloaded)
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
    }

    /// Toggles shown in a single row on tvOS and iPad
    @ViewBuilder
    private var filterToggles: some View {
        filterToggle("Continue Watching", isOn: $showContinueWatching)
        filterToggle("Unwatched Only", isOn: $showUnwatchedOnly)
        filterToggle(sortByDownloaded ? "Sort: Downloaded" : "Sort: Published", isOn: $sortByDownloaded)
    }

    private func filterToggle(_ title: String, isOn: Binding<Bool>, tint: Color = .blue) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(Layout.deviceClass == .phone ? Font.subheadline.weight(.medium) : Font.headline)
                .foregroundColor(.white)
        }
        #if os(iOS)
        .toggleStyle(SwitchToggleStyle(tint: tint))
        #endif
    }

    private var refreshButton: some View {
        Button(action: { reload() }) {
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

    private var videoGrid: some View {
        LazyVGrid(columns: Layout.gridColumns, spacing: Layout.gridSpacing) {
            ForEach(api.videos) { video in
                VideoCard(
                    video: video,
                    isSelected: selectedVideoID == (video.youtubeID ?? video.id)
                ) {
                    handleVideoTap(video)
                }
                .onAppear {
                    loadMoreIfNeeded(currentVideo: video)
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
                reload()
            }
        } else if api.videos.isEmpty {
            fullScreenMessage(
                title: "No Videos Found",
                message: (showUnwatchedOnly || showContinueWatching) ? "Try turning off the filters or refreshing your library." : "Refresh to try loading your TubeArchivist library again.",
                buttonTitle: "Refresh"
            ) {
                reload()
            }
        } else {
            videoGrid
        }
    }

    /// Spinner while the next page loads (triggered automatically while scrolling);
    /// a manual button only when the automatic load failed
    @ViewBuilder
    private var paginationFooter: some View {
        if api.errorMessage != nil && !api.isLoadingMore {
            Button(action: { api.loadMoreVideos() }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Loading More")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.3, green: 0.3, blue: 0.3))
                )
            }
            .padding(.bottom, 30)
        } else {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .onAppear {
                    api.loadMoreVideos()
                }
        }
    }

    // MARK: - Actions

    private func reload() {
        api.fetchVideos(unwatchedOnly: showUnwatchedOnly, sortByDownloaded: sortByDownloaded, continueWatching: showContinueWatching)
    }

    /// Starts loading the next page once one of the last few cards scrolls into view
    private func loadMoreIfNeeded(currentVideo: Video) {
        guard api.hasMorePages, api.errorMessage == nil else { return }
        if api.videos.suffix(Layout.prefetchThreshold).contains(where: { $0.id == currentVideo.id }) {
            api.loadMoreVideos()
        }
    }

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
