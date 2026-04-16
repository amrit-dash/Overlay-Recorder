import ReplayKit
import AVFoundation

class SampleHandler: RPBroadcastSampleHandler {
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioAppInput: AVAssetWriterInput?
    private var audioMicInput: AVAssetWriterInput?
    
    private var isWriterStarted = false
    private var sessionStartTime: CMTime?
    private var outputURL: URL?
    
    private var audioSource: String = "Microphone Only"
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        let sharedDefaults = UserDefaults(suiteName: "group.amrit.dash.Overlay-Recorder")
        audioSource = sharedDefaults?.string(forKey: "audioSource") ?? "Microphone Only"
        
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        let groupID = "group.amrit.dash.Overlay-Recorder"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            print("No app group found")
            return
        }
        
        let recordingsDir = containerURL.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        
        let fileName = "ScreenRecording_\(Date().timeIntervalSince1970).mp4"
        outputURL = recordingsDir.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: outputURL!.path) {
            try? FileManager.default.removeItem(at: outputURL!)
        }
        
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL!, fileType: .mp4)
        } catch {
            print("Failed to create Asset Writer: \(error)")
        }
        
        // Setup observer to stop recording from main app
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center,
                                        Unmanaged.passUnretained(self).toOpaque(),
                                        { (center, observer, name, object, userInfo) in
                                            guard let observer = observer else { return }
                                            let handler = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
                                            handler.perform(#selector(RPBroadcastSampleHandler.finishBroadcastWithError(_:)), with: nil)
                                        },
                                        "com.amrit.dash.Overlay-Recorder.stopBroadcast" as CFString,
                                        nil,
                                        .deliverImmediately)
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque(), CFNotificationName("com.amrit.dash.Overlay-Recorder.stopBroadcast" as CFString), nil)
        
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        if assetWriter?.status == .writing {
            videoInput?.markAsFinished()
            audioAppInput?.markAsFinished()
            audioMicInput?.markAsFinished()
            
            assetWriter?.finishWriting {
                dispatchGroup.leave()
            }
        } else {
            assetWriter?.cancelWriting()
            if let outputURL = outputURL, FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.wait() // Wait synchronously for completion before returning, as required by extension lifecycle
        
        // Notify main app that a new recording is available
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName("com.amrit.dash.Overlay-Recorder.recordingFinished" as CFString), nil, nil, true)
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        if assetWriter == nil { return }
        
        switch sampleBufferType {
        case .video:
            if !isWriterStarted {
                setupVideoInput(sampleBuffer: sampleBuffer)
                if audioSource == "App Audio Only" || audioSource == "Both (App & Mic)" {
                    setupAudioAppInput()
                }
                if audioSource == "Microphone Only" || audioSource == "Both (App & Mic)" {
                    setupAudioMicInput()
                }
                assetWriter?.startWriting()
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                assetWriter?.startSession(atSourceTime: pts)
                sessionStartTime = pts
                isWriterStarted = true
            }
            if let videoInput = videoInput, videoInput.isReadyForMoreMediaData {
                videoInput.append(sampleBuffer)
            }
        case .audioApp:
            if isWriterStarted {
                if let audioAppInput = audioAppInput, audioAppInput.isReadyForMoreMediaData {
                    if let start = sessionStartTime, CMSampleBufferGetPresentationTimeStamp(sampleBuffer) >= start {
                        audioAppInput.append(sampleBuffer)
                    }
                }
            }
        case .audioMic:
            if isWriterStarted {
                if let audioMicInput = audioMicInput, audioMicInput.isReadyForMoreMediaData {
                    if let start = sessionStartTime, CMSampleBufferGetPresentationTimeStamp(sampleBuffer) >= start {
                        audioMicInput.append(sampleBuffer)
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func setupVideoInput(sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        var width = Int(dimensions.width)
        var height = Int(dimensions.height)
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
    }
    
    private func setupAudioAppInput() {
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100.0,
            AVEncoderBitRateKey: 128000
        ]
        audioAppInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioAppInput?.expectsMediaDataInRealTime = true
        if let aai = audioAppInput, assetWriter!.canAdd(aai) {
            assetWriter!.add(aai)
        } else {
            audioAppInput = nil
        }
    }
    
    private func setupAudioMicInput() {
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100.0,
            AVEncoderBitRateKey: 128000
        ]
        audioMicInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioMicInput?.expectsMediaDataInRealTime = true
        if let ami = audioMicInput, assetWriter!.canAdd(ami) {
            assetWriter!.add(ami)
        } else {
            audioMicInput = nil
        }
    }
}
