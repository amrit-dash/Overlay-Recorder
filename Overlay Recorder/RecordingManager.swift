import Foundation
import ReplayKit
import AVFoundation
import Photos
import Combine

class RecordingManager: ObservableObject {
    static let shared = RecordingManager()
    
    @Published var isRecording = false
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var appAudioInput: AVAssetWriterInput?
    private var micAudioInput: AVAssetWriterInput?
    
    private var isWriterStarted = false
    private var sessionStartTime: CMTime?
    private var outputURL: URL?
    private var currentResolution: AppState.RecordingResolution = .hd1080p
    private let writerQueue = DispatchQueue(label: "com.amrit.dash.Overlay-Recorder.writerQueue")
    
    func startRecording(resolution: AppState.RecordingResolution, fps: AppState.RecordingFPS) {
        guard !isRecording else { return }
        
        self.currentResolution = resolution
        self.isWriterStarted = false
        self.sessionStartTime = nil
        self.assetWriter = nil
        self.videoInput = nil
        self.appAudioInput = nil
        self.micAudioInput = nil
        
        // Ensure microphone permission is granted before trying to use ReplayKit with mic
        if #available(iOS 17.0, *) {
            let permission = AVAudioApplication.shared.recordPermission
            if permission == .undetermined {
                AVAudioApplication.requestRecordPermission { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            self?.performStartRecording()
                        } else {
                            print("Microphone permission denied. Starting without mic.")
                            self?.performStartRecording(withMic: false)
                        }
                    }
                }
            } else {
                let hasMic = (permission == .granted)
                performStartRecording(withMic: hasMic)
            }
        } else {
            let audioSession = AVAudioSession.sharedInstance()
            if audioSession.recordPermission == .undetermined {
                audioSession.requestRecordPermission { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            self?.performStartRecording()
                        } else {
                            print("Microphone permission denied. Starting without mic.")
                            self?.performStartRecording(withMic: false)
                        }
                    }
                }
            } else {
                let hasMic = (audioSession.recordPermission == .granted)
                performStartRecording(withMic: hasMic)
            }
        }
    }
    
    private func performStartRecording(withMic: Bool = true) {
        // Pausing camera session to guarantee hardware is free for ReplayKit
        let wasCameraRunning = CameraManager.shared.captureSession.isRunning
        
        let startBlock = {
            self.executeReplayKitStart(withMic: withMic, resumeCamera: wasCameraRunning)
        }
        
        if wasCameraRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                CameraManager.shared.captureSession.stopRunning()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startBlock()
                }
            }
        } else {
            if Thread.isMainThread {
                startBlock()
            } else {
                DispatchQueue.main.async {
                    startBlock()
                }
            }
        }
    }
    
    private func executeReplayKitStart(withMic: Bool, resumeCamera: Bool) {
        RPScreenRecorder.shared().isMicrophoneEnabled = withMic
        
        let captureHandler: (CMSampleBuffer, RPSampleBufferType, Error?) -> Void = { [weak self] (sampleBuffer, bufferType, error) in
            guard let self = self, error == nil else {
                if let error = error {
                    print("Capture error: \(error)")
                }
                return
            }
            
            self.writerQueue.async {
                self.handleSampleBuffer(sampleBuffer: sampleBuffer, bufferType: bufferType)
            }
        }
        
        let startCompletion: (Error?) -> Void = { [weak self] error in
            if let error = error as? NSError {
                print("Failed to start capture: \(error)")
                
                if error.code == -5803 || error.code == -5807 {
                    if withMic {
                        print("Retrying capture without microphone...")
                        RPScreenRecorder.shared().isMicrophoneEnabled = false
                        RPScreenRecorder.shared().startCapture(handler: captureHandler, completionHandler: { error2 in
                            if let error2 = error2 {
                                print("Retry failed: \(error2)")
                            } else {
                                DispatchQueue.main.async {
                                    self?.isRecording = true
                                }
                            }
                            if resumeCamera { CameraManager.shared.startSession() }
                        })
                    } else {
                        if resumeCamera { CameraManager.shared.startSession() }
                    }
                } else {
                    if resumeCamera { CameraManager.shared.startSession() }
                }
            } else {
                DispatchQueue.main.async {
                    self?.isRecording = true
                }
                if resumeCamera { CameraManager.shared.startSession() }
            }
        }
        
        // Stop any stuck capture first only if it thinks it is recording
        if RPScreenRecorder.shared().isRecording {
            RPScreenRecorder.shared().stopCapture { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    RPScreenRecorder.shared().startCapture(handler: captureHandler, completionHandler: startCompletion)
                }
            }
        } else {
            RPScreenRecorder.shared().startCapture(handler: captureHandler, completionHandler: startCompletion)
        }
    }
    
    private func setupAssetWriter(sampleBuffer: CMSampleBuffer) {
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "ScreenRecording_\(Date().timeIntervalSince1970).mp4"
        outputURL = documentDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: outputURL!.path) {
            try? fileManager.removeItem(at: outputURL!)
        }
        
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL!, fileType: .mp4)
        } catch {
            print("Failed to create Asset Writer: \(error)")
            return
        }
        
        // Video Settings based on incoming buffer to prevent append failures
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        var width = Int(dimensions.width)
        var height = Int(dimensions.height)
        
        // Ensure dimensions are even (H.264 requirement)
        width = width % 2 == 0 ? width : width + 1
        height = height % 2 == 0 ? height : height + 1
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspect
        ]
        
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        
        if let orientationAttachment = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber,
           let orientation = CGImagePropertyOrientation(rawValue: orientationAttachment.uint32Value) {
            let w = CGFloat(width)
            let h = CGFloat(height)
            switch orientation {
            case .down, .downMirrored:
                videoInput?.transform = CGAffineTransform(rotationAngle: .pi).translatedBy(x: -w, y: -h)
            case .left, .leftMirrored:
                videoInput?.transform = CGAffineTransform(rotationAngle: .pi / 2).translatedBy(x: 0, y: -h)
            case .right, .rightMirrored:
                videoInput?.transform = CGAffineTransform(rotationAngle: -.pi / 2).translatedBy(x: -w, y: 0)
            default:
                videoInput?.transform = .identity
            }
        }
        
        if let vi = videoInput, assetWriter!.canAdd(vi) {
            assetWriter!.add(vi)
        } else {
            videoInput = nil
        }
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100.0,
            AVEncoderBitRateKey: 128000
        ]
        
        let sharedDefaults = UserDefaults(suiteName: "group.amrit.dash.Overlay-Recorder")
        let audioSource = sharedDefaults?.string(forKey: "audioSource") ?? "Microphone Only"
        
        if audioSource == "App Audio Only" || audioSource == "Both (App & Mic)" {
            appAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            appAudioInput?.expectsMediaDataInRealTime = true
            if let aai = appAudioInput, assetWriter!.canAdd(aai) {
                assetWriter!.add(aai)
            } else {
                appAudioInput = nil
            }
        }
        
        if audioSource == "Microphone Only" || audioSource == "Both (App & Mic)" {
            micAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            micAudioInput?.expectsMediaDataInRealTime = true
            if let ami = micAudioInput, assetWriter!.canAdd(ami) {
                assetWriter!.add(ami)
            } else {
                micAudioInput = nil
            }
        }
    }
    
    private func handleSampleBuffer(sampleBuffer: CMSampleBuffer, bufferType: RPSampleBufferType) {
        if assetWriter == nil {
            if bufferType == .video {
                setupAssetWriter(sampleBuffer: sampleBuffer)
            } else {
                // Drop audio samples until video starts and writer is set up
                return
            }
        }
        
        switch bufferType {
        case .video:
            if !isWriterStarted {
                assetWriter?.startWriting()
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                assetWriter?.startSession(atSourceTime: pts)
                sessionStartTime = pts
                isWriterStarted = true
            }
            if videoInput?.isReadyForMoreMediaData == true {
                videoInput?.append(sampleBuffer)
            }
        case .audioApp:
            if isWriterStarted, appAudioInput?.isReadyForMoreMediaData == true {
                if let start = sessionStartTime, CMSampleBufferGetPresentationTimeStamp(sampleBuffer) >= start {
                    appAudioInput?.append(sampleBuffer)
                }
            }
        case .audioMic:
            if isWriterStarted, micAudioInput?.isReadyForMoreMediaData == true {
                if let start = sessionStartTime, CMSampleBufferGetPresentationTimeStamp(sampleBuffer) >= start {
                    micAudioInput?.append(sampleBuffer)
                }
            }
        @unknown default:
            break
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        RPScreenRecorder.shared().stopCapture { [weak self] error in
            guard let self = self else { return }
            
            if self.assetWriter?.status == .writing {
                self.videoInput?.markAsFinished()
                self.appAudioInput?.markAsFinished()
                self.micAudioInput?.markAsFinished()
                
                self.assetWriter?.finishWriting {
                    DispatchQueue.main.async {
                        self.isRecording = false
                        self.isWriterStarted = false
                        if let url = self.outputURL {
                            self.saveToPhotos(url: url)
                        }
                    }
                }
            } else {
                self.assetWriter?.cancelWriting()
                if let url = self.outputURL, FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.removeItem(at: url)
                }
                DispatchQueue.main.async {
                    self.isRecording = false
                    self.isWriterStarted = false
                }
            }
        }
    }
    
    private func saveToPhotos(url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized else { return }
            
            let albumName = "Aradhi's Classroom"
            var assetCollectionPlaceholder: PHObjectPlaceholder?
            var albumCollection: PHAssetCollection?
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
            let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            
            if let existingAlbum = collection.firstObject {
                albumCollection = existingAlbum
            }
            
            PHPhotoLibrary.shared().performChanges({
                if albumCollection == nil {
                    let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                    assetCollectionPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
                }
            }) { success, error in
                if success {
                    if let placeholder = assetCollectionPlaceholder {
                        let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                        albumCollection = fetchResult.firstObject
                    }
                    
                    if let album = albumCollection {
                        PHPhotoLibrary.shared().performChanges({
                            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                            if let placeholder = assetChangeRequest?.placeholderForCreatedAsset {
                                let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                                albumChangeRequest?.addAssets([placeholder] as NSArray)
                            }
                        }) { saved, error in
                            if saved {
                                print("Successfully saved to Photos album")
                            }
                        }
                    }
                } else if let error = error {
                    print("Error creating album: \(error)")
                }
            }
        }
    }
}
