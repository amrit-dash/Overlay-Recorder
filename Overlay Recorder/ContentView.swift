import SwiftUI
import AVFoundation
import ReplayKit
import Photos

enum AppScreen: Hashable {
    case studio
    case library
}

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var selection: AppScreen? = .studio
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    

    private func saveRecordingsFromExtension() {
        let groupID = AppGroupHelper.appGroupID
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return }
        let recordingsDir = containerURL.appendingPathComponent("Recordings", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil) else { return }
        
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        
        for fileURL in files where fileURL.pathExtension == "mp4" {
            let destinationURL = docsDir.appendingPathComponent(fileURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            try? FileManager.default.moveItem(at: fileURL, to: destinationURL)
        }
    }

    var body: some View {
        ZStack {
            PiPSourceView()
                .frame(width: 50, height: 50)
                .opacity(0.01)
                
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(appState: appState, selection: $selection)
                    .navigationTitle("Aradhi's Classroom")
            } detail: {
                if selection == .library {
                    LibraryView(selection: $selection, columnVisibility: $columnVisibility)
                } else {
                    MainActionView(appState: appState)
                        .navigationTitle("Studio")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .onChange(of: selection) { _, newSelection in
            if newSelection == .library {
                columnVisibility = .detailOnly
            } else {
                columnVisibility = .all
            }
        }
        .onAppear {
            if appState.isCameraEnabled {
                CameraManager.shared.startSession()
                CameraManager.shared.setZoom(appState.cameraZoom)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("com.amrit.dash.Overlay-Recorder.recordingFinished"))) { _ in
            saveRecordingsFromExtension()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            let isCaptured = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.isCaptured ?? false
            appState.isRecording = isCaptured
            if !isCaptured {
                saveRecordingsFromExtension()
            }
        }
        .onAppear {
            let isCaptured = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.isCaptured ?? false
            appState.isRecording = isCaptured
        }
        .onReceive(PiPManager.shared.$isPiPActive) { isPiPActive in
            appState.isPiPActive = isPiPActive
            // If PiP is disabled, turn off camera to save battery
            if !isPiPActive && appState.isCameraEnabled {
                CameraManager.shared.stopSession()
                appState.isCameraEnabled = false
            }
        }
        .onReceive(CameraManager.shared.$minZoomUI) { minZoom in
            // When cameras switch, update UI limits
            if appState.cameraZoom < minZoom {
                appState.cameraZoom = minZoom
            }
        }
        .onChange(of: appState.pipAspectRatio) { _, newRatio in
            PiPManager.shared.updateLayout(aspectRatio: newRatio, mask: appState.pipMask)
        }
        .onChange(of: appState.pipMask) { _, newMask in
            PiPManager.shared.updateLayout(aspectRatio: appState.pipAspectRatio, mask: newMask)
        }
    }
}

struct SidebarView: View {
    @ObservedObject var appState: AppState
    @Binding var selection: AppScreen?
    @ObservedObject var cameraManager = CameraManager.shared
    
    

    private func saveRecordingsFromExtension() {
        let groupID = AppGroupHelper.appGroupID
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return }
        let recordingsDir = containerURL.appendingPathComponent("Recordings", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil) else { return }
        
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        
        for fileURL in files where fileURL.pathExtension == "mp4" {
            let destinationURL = docsDir.appendingPathComponent(fileURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            try? FileManager.default.moveItem(at: fileURL, to: destinationURL)
        }
    }

    var body: some View {
        List(selection: $selection) {
            Section("Views") {
                NavigationLink(value: AppScreen.studio) {
                    Label("Studio", systemImage: "camera.circle.fill")
                }
                NavigationLink(value: AppScreen.library) {
                    Label("Recordings Library", systemImage: "play.rectangle.on.rectangle")
                }
            }
            
            Section(header: Text("Camera Layout")) {
                Picker("Aspect Ratio", selection: $appState.pipAspectRatio) {
                    ForEach(AppState.PiPAspectRatio.allCases) { ratio in
                        Text(ratio.rawValue).tag(ratio)
                    }
                }
                
                Picker("Mask Shape", selection: $appState.pipMask) {
                    ForEach(AppState.PiPMask.allCases) { mask in
                        Text(mask.rawValue).tag(mask)
                    }
                }
            }
            
            Section(header: Text("Camera Selection")) {
                Picker("Camera", selection: $appState.cameraPosition) {
                    Text("Front Camera").tag(AVCaptureDevice.Position.front as AVCaptureDevice.Position)
                    Text("Back Camera").tag(AVCaptureDevice.Position.back as AVCaptureDevice.Position)
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: appState.cameraPosition) { _, newValue in
                    cameraManager.switchCamera(to: newValue)
                    appState.cameraZoom = cameraManager.minZoomUI
                    cameraManager.setZoom(appState.cameraZoom)
                }
            }
            
            Section(header: Text("Camera Settings")) {
                Picker("Resolution", selection: $appState.cameraResolution) {
                    ForEach(AppState.CameraResolution.allCases) { res in
                        Text(res.rawValue).tag(res)
                    }
                }
                .onChange(of: appState.cameraResolution) { _, newValue in
                    CameraManager.shared.setResolution(newValue)
                }
                
                VStack(alignment: .leading) {
                    Text("Camera Zoom: \(appState.cameraZoom, specifier: "%.1f")x")
                        .foregroundColor(.primary)
                    Slider(value: $appState.cameraZoom, in: cameraManager.minZoomUI...5.0, step: 0.1)
                        .onChange(of: appState.cameraZoom) { _, newValue in
                            cameraManager.setZoom(newValue)
                        }
                }
                
                Toggle("Center Stage", isOn: Binding(
                    get: { cameraManager.systemCenterStageEnabled },
                    set: { newValue in
                        cameraManager.toggleCenterStage(newValue)
                        if !newValue {
                            cameraManager.setZoom(appState.cameraZoom)
                        }
                    }
                ))
            }
            
            Section(header: Text("Recording Quality")) {
                Picker("Audio", selection: $appState.audioSource) {
                    ForEach(AppState.AudioSource.allCases) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                
                Picker("Resolution", selection: $appState.recordingResolution) {
                    ForEach(AppState.RecordingResolution.allCases) { res in
                        Text(res.rawValue).tag(res)
                    }
                }
                
                Picker("Framerate", selection: $appState.recordingFPS) {
                    ForEach(AppState.RecordingFPS.allCases) { fps in
                        Text(fps.rawValue).tag(fps)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct MainActionView: View {
    @ObservedObject var appState: AppState
    @State private var isStartingPiP = false
    @State private var isStartingRecording = false
    @State private var isStoppingRecording = false
    
    func triggerSystemScreenRecording() {
        let picker = RPSystemBroadcastPickerView(frame: .zero)
        picker.preferredExtension = Bundle.main.bundleIdentifier! + ".OverlayBroadcastExtension"
        picker.showsMicrophoneButton = true
        if let button = picker.subviews.first(where: { $0 is UIButton }) as? UIButton {
            button.sendActions(for: .allTouchEvents)
        }
    }
    
    private func saveRecordingsFromExtension() {
        let groupID = AppGroupHelper.appGroupID
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return }
        let recordingsDir = containerURL.appendingPathComponent("Recordings", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil) else { return }
        
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        
        for fileURL in files where fileURL.pathExtension == "mp4" && !fileURL.lastPathComponent.hasPrefix("mixed_") {
            Task {
                let asset = AVURLAsset(url: fileURL)
                let audioTracks = try? await asset.loadTracks(withMediaType: .audio)
                let count = audioTracks?.count ?? 0
                
                if count > 1 {
                    mixAudioUsingExportSession(url: fileURL) { mixedURL, error in
                        guard let finalURL = mixedURL else { return }
                        let destinationURL = docsDir.appendingPathComponent(finalURL.lastPathComponent.replacingOccurrences(of: "mixed_", with: ""))
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try? FileManager.default.removeItem(at: destinationURL)
                        }
                        try? FileManager.default.moveItem(at: finalURL, to: destinationURL)
                    }
                } else {
                    let destinationURL = docsDir.appendingPathComponent(fileURL.lastPathComponent)
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try? FileManager.default.removeItem(at: destinationURL)
                    }
                    try? FileManager.default.moveItem(at: fileURL, to: destinationURL)
                }
            }
        }
    }
    
    private func mixAudioUsingExportSession(url: URL, completion: @escaping (URL?, Error?) -> Void) {
        Task {
            do {
                let asset = AVURLAsset(url: url)
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                
                guard audioTracks.count > 1 else {
                    completion(url, nil)
                    return
                }
                
                let audioOutURL = url.deletingLastPathComponent().appendingPathComponent("temp_audio_\(UUID().uuidString).m4a")
                if FileManager.default.fileExists(atPath: audioOutURL.path) {
                    try FileManager.default.removeItem(at: audioOutURL)
                }
                
                let reader = try AVAssetReader(asset: asset)
                let writer = try AVAssetWriter(outputURL: audioOutURL, fileType: .m4a)
                
                let audioMix = AVMutableAudioMix()
                var inputParameters = [AVMutableAudioMixInputParameters]()
                for track in audioTracks {
                    let param = AVMutableAudioMixInputParameters(track: track)
                    param.setVolume(1.0, at: .zero)
                    inputParameters.append(param)
                }
                audioMix.inputParameters = inputParameters
                
                let mixOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsNonInterleaved: false,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false
                ])
                mixOutput.audioMix = audioMix
                reader.add(mixOutput)
                
                let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 128000
                ])
                audioInput.expectsMediaDataInRealTime = false
                writer.add(audioInput)
                
                writer.startWriting()
                reader.startReading()
                writer.startSession(atSourceTime: .zero)
                
                let audioQueue = DispatchQueue(label: "audioQueue")
                
                nonisolated(unsafe) let safeAudioInput = audioInput
                nonisolated(unsafe) let safeMixOutput = mixOutput
                nonisolated(unsafe) let safeWriter = writer
                
                safeAudioInput.requestMediaDataWhenReady(on: audioQueue) {
                    while safeAudioInput.isReadyForMoreMediaData {
                        var sample: CMSampleBuffer?
                        autoreleasepool {
                            sample = safeMixOutput.copyNextSampleBuffer()
                        }
                        if let sample = sample {
                            safeAudioInput.append(sample)
                        } else {
                            safeAudioInput.markAsFinished()
                            
                            DispatchQueue.main.async {
                                Task {
                                    await safeWriter.finishWriting()
                                    
                                    guard safeWriter.status == .completed else {
                                        try? FileManager.default.removeItem(at: audioOutURL)
                                        completion(nil, safeWriter.error)
                                        return
                                    }
                                    
                                    do {
                                        let mixedAudioAsset = AVURLAsset(url: audioOutURL)
                                        guard let mixedAudioTrack = try await mixedAudioAsset.loadTracks(withMediaType: .audio).first else {
                                            throw NSError(domain: "Mix", code: 2, userInfo: nil)
                                        }
                                        
                                        let composition = AVMutableComposition()
                                        
                                        if let videoTrack = try await asset.loadTracks(withMediaType: .video).first {
                                            let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                                            let timeRange = try await videoTrack.load(.timeRange)
                                            try compVideo?.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                                        }
                                        
                                        let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                                        let audioTimeRange = try await mixedAudioTrack.load(.timeRange)
                                        try compAudio?.insertTimeRange(audioTimeRange, of: mixedAudioTrack, at: .zero)
                                        
                                        let finalOutURL = url.deletingLastPathComponent().appendingPathComponent("mixed_" + url.lastPathComponent)
                                        if FileManager.default.fileExists(atPath: finalOutURL.path) {
                                            try FileManager.default.removeItem(at: finalOutURL)
                                        }
                                        
                                        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
                                            throw NSError(domain: "Export", code: 3, userInfo: nil)
                                        }
                                        exportSession.outputURL = finalOutURL
                                        exportSession.outputFileType = .mp4
                                        exportSession.shouldOptimizeForNetworkUse = true
                                        
                                        if #available(iOS 18.0, *) {
                                            try await exportSession.export(to: finalOutURL, as: .mp4)
                                            try? FileManager.default.removeItem(at: audioOutURL)
                                            try? FileManager.default.removeItem(at: url)
                                            completion(finalOutURL, nil)
                                        } else {
                                            await exportSession.export()
                                            try? FileManager.default.removeItem(at: audioOutURL)
                                            if exportSession.status == .completed || exportSession.status == .waiting {
                                                try? FileManager.default.removeItem(at: url)
                                                completion(finalOutURL, nil)
                                            } else {
                                                completion(nil, exportSession.error)
                                            }
                                        }
                                        
                                    } catch {
                                        try? FileManager.default.removeItem(at: audioOutURL)
                                        completion(nil, error)
                                    }
                                }
                            }
                            break
                        }
                    }
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header Section
                VStack(spacing: 8) {
                    Image(systemName: "video.and.waveform")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                        .padding(.bottom, 16)
                    
                    Text("Studio")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    
                    Text("Set up your camera overlay and record your screen.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                .padding(.bottom, 16)
                
                // Status/Info Cards
                HStack(spacing: 16) {
                    StatusCard(
                        icon: "camera.fill",
                        title: "Camera",
                        subtitle: appState.cameraPosition == .front ? "Front" : "Back",
                        color: .blue
                    )
                    StatusCard(
                        icon: "aspectratio",
                        title: "Layout",
                        subtitle: appState.pipAspectRatio.rawValue,
                        color: .purple
                    )
                    StatusCard(
                        icon: "film",
                        title: "Quality",
                        subtitle: "\(appState.recordingResolution.rawValue) at \(appState.recordingFPS.rawValue)",
                        color: .orange
                    )
                }
                .padding(.bottom, 24)
                
                // Main Action Buttons
                VStack(spacing: 24) {
                    Button(action: {
                        if appState.isPiPActive {
                            PiPManager.shared.stopPiP()
                        } else {
                            isStartingPiP = true
                            if !appState.isCameraEnabled {
                                CameraManager.shared.startSession()
                                appState.isCameraEnabled = true
                                // Apply layout and zoom in case it wasn't set yet
                                PiPManager.shared.updateLayout(aspectRatio: appState.pipAspectRatio, mask: appState.pipMask)
                                CameraManager.shared.setZoom(appState.cameraZoom)
                            }
                            // A slight delay might be needed for the camera session to start before PiP can take it,
                            // but we can try immediate first. If issues occur, use DispatchQueue.main.asyncAfter
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                PiPManager.shared.startPiP()
                                isStartingPiP = false
                            }
                        }
                    }) {
                        HStack(spacing: 20) {
                            if isStartingPiP {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(1.5)
                                    .frame(width: 40, height: 40)
                            } else {
                                Image(systemName: appState.isPiPActive ? "pip.exit" : "pip.enter")
                                    .font(.system(size: 40))
                                    .frame(width: 40, height: 40)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appState.isPiPActive ? "Stop Overlay" : "Start Overlay")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text(appState.isPiPActive ? "Close the floating camera" : "Show camera in a floating window")
                                    .font(.subheadline)
                                    .opacity(0.8)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                        .background(appState.isPiPActive ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                        .foregroundColor(appState.isPiPActive ? .red : .blue)
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(appState.isPiPActive ? Color.red.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(isStartingPiP)
                    
                    Button(action: {
                        if appState.isRecording {
                            isStoppingRecording = true
                            let center = CFNotificationCenterGetDarwinNotifyCenter()
                            CFNotificationCenterPostNotification(center, CFNotificationName("com.amrit.dash.Overlay-Recorder.stopBroadcast" as CFString), nil, nil, true)
                        } else {
                            isStartingRecording = true
                            triggerSystemScreenRecording()
                            
                            // Fallback if they cancel the prompt (gives them 60 seconds to act)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                                if !appState.isRecording {
                                    isStartingRecording = false
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 20) {
                            if isStoppingRecording || isStartingRecording {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: isStoppingRecording ? .red : .green))
                                    .scaleEffect(1.5)
                                    .frame(width: 40, height: 40)
                            } else {
                                Image(systemName: appState.isRecording ? "stop.circle.fill" : "record.circle")
                                    .font(.system(size: 40))
                                    .frame(width: 40, height: 40)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appState.isRecording ? (isStoppingRecording ? "Stopping..." : "Stop Recording") : (isStartingRecording ? "Waiting for system..." : "Start Full Screen Recording"))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text(appState.isRecording ? (isStoppingRecording ? "Saving your recording to library" : "Currently recording your screen") : (isStartingRecording ? "Please accept the screen recording prompt" : "Record your screen with the overlay"))
                                    .font(.subheadline)
                                    .opacity(0.8)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                        .background(appState.isRecording ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                        .foregroundColor(appState.isRecording ? .red : .green)
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(appState.isRecording ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(isStoppingRecording)
                }
                
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: 800)
        }
        .onChange(of: appState.isRecording) { _, isRecording in
            if !isRecording {
                isStoppingRecording = false
            } else {
                isStartingRecording = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIWindow.didBecomeHiddenNotification)) { _ in
            if isStartingRecording && !appState.isRecording {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                    if !appState.isRecording {
                        isStartingRecording = false
                    }
                }
            }
        }
    }
}

struct StatusCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(subtitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
    }
}
