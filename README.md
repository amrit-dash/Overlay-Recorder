# Overlay Recorder

Overlay Recorder is an iOS application built with SwiftUI that allows users to record their screen seamlessly. The app features camera integration, Picture-in-Picture (PiP) capabilities, and a library view for managing recorded content.

## Features

- **Screen Recording:** Leverage the included Broadcast Extension for high-quality screen recording functionality directly from your device.
- **Camera Integration:** Capture yourself simultaneously using the front-facing camera while recording the screen.
- **Picture-in-Picture (PiP):** Minimize the camera view into a floating window that stays on top of other applications during recording.
- **Library View:** Easily access, manage, and review your previous screen recordings.

## Architecture

- `Overlay Recorder/`: Main SwiftUI application target containing the UI (`ContentView`, `LibraryView`) and state management (`AppState`, `CameraManager`, `PiPManager`, `RecordingManager`).
- `OverlayBroadcastExtension/`: App Extension utilizing `SampleHandler.swift` to process and capture screen broadcasting sessions efficiently.

## Requirements

- iOS 15.0+ (or as specified in the project)
- Xcode 14.0+
- Swift 5.0+

## Getting Started

1. Open `Overlay Recorder.xcodeproj` in Xcode.
2. Ensure your signing and capabilities are set up properly, particularly for App Groups if data is shared between the main app and the broadcast extension.
3. Build and run the app on a physical iOS device (Screen recording extensions may not function fully in the Simulator).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.