import SwiftUI
import Combine
import AVFoundation

class AppState: ObservableObject {
    @Published var isCameraEnabled: Bool = false
    @Published var isCenterStageEnabled: Bool = false
    @Published var isStudioLightEnabled: Bool = false
    @Published var cameraPosition: AVCaptureDevice.Position = .front
    @Published var cameraResolution: CameraResolution = .hd1080p
    @Published var recordingResolution: RecordingResolution = .uhd4K
    @Published var recordingFPS: RecordingFPS = .fps60
    
    @Published var isRecording: Bool = false
    @Published var isPiPActive: Bool = false
    
    @Published var cameraZoom: CGFloat = 1.0
    
    @Published var pipAspectRatio: PiPAspectRatio = .ratio1_1
    @Published var pipMask: PiPMask = .fill
    @Published var audioSource: AudioSource {
        didSet {
            let sharedDefaults = UserDefaults(suiteName: "group.amrit.dash.Overlay-Recorder")
            sharedDefaults?.set(audioSource.rawValue, forKey: "audioSource")
        }
    }
    
    init() {
        let sharedDefaults = UserDefaults(suiteName: "group.amrit.dash.Overlay-Recorder")
        let savedAudio = sharedDefaults?.string(forKey: "audioSource") ?? AudioSource.micAudio.rawValue
        self.audioSource = AudioSource(rawValue: savedAudio) ?? .micAudio
    }
    
    enum AudioSource: String, CaseIterable, Identifiable {
        case appAudio = "App Audio Only"
        case micAudio = "Microphone Only"
        case both = "Both (App & Mic)"
        var id: String { rawValue }
    }
    
    enum CameraResolution: String, CaseIterable, Identifiable {
        case hd720p = "720p"
        case hd1080p = "1080p"
        case uhd4K = "4K"
        var id: String { rawValue }
    }
    
    enum RecordingResolution: String, CaseIterable, Identifiable {
        case hd720p = "720p"
        case hd1080p = "1080p"
        case uhd4K = "4K"
        var id: String { rawValue }
    }
    
    enum RecordingFPS: String, CaseIterable, Identifiable {
        case fps24 = "24 FPS"
        case fps30 = "30 FPS"
        case fps60 = "60 FPS"
        var id: String { rawValue }
    }
    
    enum PiPAspectRatio: String, CaseIterable, Identifiable {
        case ratio16_9 = "16:9"
        case ratio9_16 = "9:16"
        case ratio1_1 = "1:1"
        case ratio4_3 = "4:3"
        var id: String { rawValue }
    }
    
    enum PiPMask: String, CaseIterable, Identifiable {
        case circle = "Circle"
        case fill = "Fill (Rectangle)"
        var id: String { rawValue }
    }
}
