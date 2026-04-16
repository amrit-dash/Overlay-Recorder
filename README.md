# 🎥 Overlay Recorder

[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg?style=flat-square)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg?style=flat-square)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-14.0+-blue.svg?style=flat-square)](https://developer.apple.com/xcode/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

**Overlay Recorder** is a powerful iOS application built with SwiftUI that empowers users to record their screens seamlessly while simultaneously overlaying their camera feed. Perfect for tutorials, reaction videos, gameplay, and presentations!

---

## ✨ Features

- 📱 **High-Quality Screen Recording:** Leverage the robust Broadcast Extension to capture your screen with high fidelity.
- 📸 **Camera Integration:** Record yourself simultaneously using the front-facing camera while broadcasting the screen.
- 🖼 **Picture-in-Picture (PiP):** Minimize the camera view into a sleek floating window that stays on top of other applications during active recording.
- 📁 **Library Management:** Easily access, manage, play, and review all your previous screen recordings in a dedicated Library view.
- 🎨 **Modern UI/UX:** A beautiful, responsive interface designed natively with SwiftUI.

---

## 🏗 Architecture

The project is structured into two main targets to ensure optimal performance and modularity:

- **`Overlay Recorder/`** (Main App Target)
  - Contains the primary SwiftUI interfaces (`ContentView`, `LibraryView`).
  - Manages the core application state (`AppState`).
  - Handles real-time functionalities via `CameraManager`, `PiPManager`, and `RecordingManager`.

- **`OverlayBroadcastExtension/`** (App Extension)
  - Contains `SampleHandler.swift`.
  - Captures and processes the screen broadcasting session efficiently in the background.

---

## 📋 Requirements

| Requirement | Version |
| ----------- | ------- |
| **OS**      | iOS 15.0+ |
| **Language**| Swift 5.0+ |
| **IDE**     | Xcode 14.0+ |

---

## 🚀 Getting Started

Follow these steps to set up the project locally.

### 1. Clone the Repository
```bash
git clone https://github.com/amrit-dash/Overlay-Recorder.git
cd Overlay-Recorder
```

### 2. Open the Project
Open the Xcode project file:
```bash
open "Overlay Recorder.xcodeproj"
```

### 3. Configure Signing & Capabilities
To ensure the app and broadcast extension work together seamlessly:
1. Select the project file in Xcode's Project Navigator.
2. For **both** the `Overlay Recorder` and `OverlayBroadcastExtension` targets:
   - Go to the **Signing & Capabilities** tab.
   - Update the **Bundle Identifier** and **Team** to your own Apple Developer account.
   - Verify that **App Groups** are properly configured, as they are essential for sharing data between the main app and the broadcast extension.

### 4. Build and Run
- Select your physical iOS device as the run destination.
- Hit `Cmd + R` or click the **Play** button.
- *Note: Screen recording extensions require a physical device and may not function fully in the iOS Simulator.*

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/amrit-dash/Overlay-Recorder/issues).

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'feat: add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with ❤️ by Amrit Dash
</p>
