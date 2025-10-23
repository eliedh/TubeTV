# TubeTV

A minimal Apple TV client for [TubeArchivist](https://www.tubearchivist.com/) - your self-hosted YouTube media server.

## About This Project

This is a lightweight tvOS app developed primarily using AI code generation to meet my specific viewing needs on Apple TV. It's **not intended to be a feature-complete client** with all TubeArchivist capabilities, but rather a focused video browser optimized for the TV viewing experience.

## Features

### Configuration
- **Settings screen** with persistent storage
- **Connection test** to verify server and API token
- **First-run setup** automatically prompts for configuration
- **Easy access** to settings via gear icon in navigation bar

### Video Browsing
- **Retrieves all videos** from your TubeArchivist server
- **Sort toggle**: Easily switch between sorting by download date (newest downloads first) or published date
- **Grid layout** optimized for Apple TV interface
- **Video thumbnails** with titles (always from YouTube CDN)
- **Watched status indicators** - dimmed thumbnails for watched videos
- **Unwatched filter** - toggle to show only unwatched content
- **Pagination** - load more videos as you scroll through your archive
- **Refresh** - manually reload the video list

### Video Playback
- **Full-screen playback** with native tvOS player controls
- **Playback speed control** - 0.5×, 0.75×, 1.0×, 1.25×, 1.5×, 2.0×
- **Skip controls** - Left/Right arrows to skip 10 seconds
- **Auto-mark as watched** - automatically updates when 10% or 30 seconds remain (whichever is longer)

### Remote Controls
- **Arrow Keys**: Skip forward/backward 10 seconds
- **Swipe Down**: Access transport bar with speed controls
- **Menu Button**: Exit player and return to grid

## Setup

1. Clone this repository
2. Open `TubeTV.xcodeproj` in Xcode
3. Build and run on Apple TV Simulator or device
4. On first launch, you'll be prompted to configure your server:
   - Enter your TubeArchivist server URL (e.g., `http://192.168.1.100:8000`)
   - Enter your API token
   - Test the connection to verify settings
   - Save settings

Settings are persisted between app sessions and can be changed anytime from the settings button (gear icon) in the navigation bar.

## Requirements

- Xcode 13.0+
- tvOS 13.0+
- A running [TubeArchivist](https://github.com/tubearchivist/tubearchivist) instance

## Limitations

This app was built to solve my specific use case and may not include features you'd expect from a full-featured client:
- No search functionality (yet)
- No channel/playlist browsing
- No download management
- Limited error handling UI

Feel free to fork and extend it for your own needs!

## Technology Stack

- **Swift** & **SwiftUI** for the UI
- **AVKit** for video playback
- **URLSession** for API communication
- Developed with heavy assistance from AI code generation tools

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [TubeArchivist](https://github.com/tubearchivist/tubearchivist) - The amazing self-hosted YouTube archiving solution
- AI coding assistants for helping build this quickly
