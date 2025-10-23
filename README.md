# TubeTV

A cross-platform client for [TubeArchivist](https://www.tubearchivist.com/) - your self-hosted YouTube media server. Works on both Apple TV and iPhone/iPad.

## About This Project

This is a lightweight SwiftUI app developed primarily using AI code generation to meet specific viewing needs across Apple devices. It's **not intended to be a feature-complete client** with all TubeArchivist capabilities, but rather a focused video browser optimized for both TV and mobile viewing experiences.

## Supported Platforms

- **Apple TV (tvOS 13.0+)** - Optimized for big screen viewing with remote control
- **iPhone (iOS 13.0+)** - Compact layout for mobile browsing
- **iPad (iOS 13.0+)** - Touch-optimized interface

## Features

### Configuration
- **Settings screen** with persistent storage across all platforms
- **Connection test** to verify server and API token
- **First-run setup** automatically prompts for configuration
- **Easy access** to settings via gear icon in navigation bar

### Video Browsing
- **Retrieves all videos** from your TubeArchivist server
- **Sort toggle**: Easily switch between sorting by download date (newest downloads first) or published date
- **Adaptive grid layout** - 3 columns on Apple TV and iPad, 2 columns on iPhone
- **Video thumbnails** with titles (always from YouTube CDN)
- **Watched status indicators** - dimmed thumbnails for watched videos
- **Unwatched filter** - toggle to show only unwatched content
- **Pagination** - load more videos as you scroll through your archive
- **Refresh** - manually reload the video list

### Video Playback
- **Full-screen playback** with native player controls
- **Playback speed control**:
  - **Apple TV**: Menu-based speed selection (0.5×, 0.75×, 1.0×, 1.25×, 1.5×, 2.0×)
  - **iPhone/iPad**: Double-tap to cycle through speeds with visual feedback
- **Skip controls** (Apple TV only) - Left/Right arrows to skip 10 seconds
- **Auto-mark as watched** - automatically updates when 10% or 30 seconds remain (whichever is longer)

### Platform-Specific Features

#### Apple TV
- **Remote Controls**: Arrow keys for skipping, Menu button to exit
- **Focus-based navigation** optimized for remote control
- **Transport bar integration** for speed control
- **Larger thumbnails** for big screen viewing

#### iPad
- **Optimized layout**: 3-column grid like Apple TV but sized for tablet
- **Touch controls** with horizontal control layout
- **Medium-sized thumbnails** (240×135) perfect for tablet viewing
- **Native iPad app icons** and proper interface scaling
- **Landscape and portrait** orientation support

#### iPhone/iPad
#### iPhone
- **Touch-optimized controls** with compact layout
- **Swipe gestures** and touch interactions
- **Smaller thumbnails** optimized for mobile screens
- **Portrait and landscape** orientation support

## Setup

1. Clone this repository
2. Open `TubeArchivistTV.xcodeproj` in Xcode
3. Select your target device (Apple TV, iPhone, or iPad)
4. Build and run on simulator or device
5. On first launch, you'll be prompted to configure your server:
   - Enter your TubeArchivist server URL (e.g., `http://192.168.1.100:8000`)
   - Enter your API token
   - Test the connection to verify settings
   - Save settings

Settings are persisted between app sessions and can be changed anytime from the settings button (gear icon) in the navigation bar.

## Requirements

- **Xcode 13.0+**
- **Apple TV**: tvOS 13.0+
- **iPhone/iPad**: iOS 13.0+
- A running [TubeArchivist](https://github.com/tubearchivist/tubearchivist) instance

## App Icons

The app includes optimized icons for all platforms:
- **iPhone**: 60x60, 120x120, 180x180 pixels
- **iPad**: 40x40, 76x76, 83.5x83.5, 152x152, 167x167 pixels
- **Apple TV**: 400x240, 1280x768 pixels
- **App Store**: 1024x1024 pixels

Add your custom app icon images to `Assets.xcassets/AppIcon.appiconset/` following the naming convention in `Contents.json`.

## Limitations

This app was built to solve specific use cases and may not include features you'd expect from a full-featured client:
- No search functionality (yet)
- No channel/playlist browsing
- No download management
- Limited error handling UI

Feel free to fork and extend it for your own needs!

## Technology Stack

- **Swift** & **SwiftUI** for cross-platform UI
- **AVKit** for video playback on all platforms
- **URLSession** for API communication
- **Conditional compilation** for platform-specific optimizations
- Developed with heavy assistance from AI code generation tools

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [TubeArchivist](https://github.com/tubearchivist/tubearchivist) - The amazing self-hosted YouTube archiving solution
- AI coding assistants for helping build this quickly
