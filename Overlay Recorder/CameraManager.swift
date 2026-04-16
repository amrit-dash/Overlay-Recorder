import Foundation
import AVFoundation
import UIKit
import Combine

class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()
    
    let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    @Published var isSessionRunning = false
    @Published var minZoomUI: CGFloat = 1.0
    @Published var systemCenterStageEnabled: Bool = false
    
    var previewLayer: AVCaptureVideoPreviewLayer
    
    private override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        super.init()
        checkPermissionsAndSetup()
        setupOrientationObserver()
    }
    
    private func setupOrientationObserver() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(updateOrientation), name: UIDevice.orientationDidChangeNotification, object: nil)
        updateOrientation()
    }
    
    private var rotationCoordinator: Any?

    @objc func updateOrientation() {
        DispatchQueue.main.async {
            guard let connection = self.previewLayer.connection,
                  let device = self.videoDeviceInput?.device else { return }
            
            if #available(iOS 17.0, *) {
                // Use iOS 17 RotationCoordinator for accurate camera orientation
                if self.rotationCoordinator == nil || (self.rotationCoordinator as? AVCaptureDevice.RotationCoordinator)?.device !== device {
                    self.rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: self.previewLayer)
                }
                
                if let coordinator = self.rotationCoordinator as? AVCaptureDevice.RotationCoordinator {
                    if connection.isVideoRotationAngleSupported(coordinator.videoRotationAngleForHorizonLevelPreview) {
                        connection.videoRotationAngle = coordinator.videoRotationAngleForHorizonLevelPreview
                    }
                }
            } else {
                let orientation = UIDevice.current.orientation
                guard connection.isVideoOrientationSupported else { return }
                
                var videoOrientation: AVCaptureVideoOrientation = .portrait
                switch orientation {
                case .portrait: videoOrientation = .portrait
                case .portraitUpsideDown: videoOrientation = .portraitUpsideDown
                case .landscapeLeft: videoOrientation = .landscapeRight
                case .landscapeRight: videoOrientation = .landscapeLeft
                default: return
                }
                connection.videoOrientation = videoOrientation
            }
            
            // Fix mirrored front camera layout
            if device.position == .front {
                if connection.isVideoMirroringSupported {
                    if connection.automaticallyAdjustsVideoMirroring {
                        connection.automaticallyAdjustsVideoMirroring = false
                    }
                    connection.isVideoMirrored = true
                }
            }
        }
    }
    private func checkPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupSession()
                }
            }
        default:
            break
        }
    }
    
    private func setupSession() {
        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.hd1920x1080) {
            captureSession.sessionPreset = .hd1920x1080
        }
        
        // Sync system center stage
        DispatchQueue.main.async {
            self.systemCenterStageEnabled = AVCaptureDevice.isCenterStageEnabled
        }
        
        // This is CRITICAL for ReplayKit to work while AVCaptureSession is running
        if #available(iOS 16.0, *) {
            if captureSession.isMultitaskingCameraAccessSupported {
                captureSession.isMultitaskingCameraAccessEnabled = true
            }
        }
        
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(iOS 13.0, *) {
            deviceTypes = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInUltraWideCamera, .builtInWideAngleCamera]
        }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .front)
        
        guard let videoDevice = discoverySession.devices.first else {
            captureSession.commitConfiguration()
            return
        }
        
        updateMinZoomUI(for: videoDevice)
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            }
        } catch {
            print("Error setting up video input: \(error)")
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.commitConfiguration()
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    func switchCamera(to position: AVCaptureDevice.Position) {
        captureSession.beginConfiguration()
        
        if let currentInput = videoDeviceInput {
            captureSession.removeInput(currentInput)
        }
        
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(iOS 13.0, *) {
            deviceTypes = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInUltraWideCamera, .builtInWideAngleCamera]
        }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: position)
        
        guard let videoDevice = discoverySession.devices.first else {
            captureSession.commitConfiguration()
            return
        }
        
        updateMinZoomUI(for: videoDevice)
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            }
        } catch {
            print("Error switching camera: \(error)")
        }
        
        // Ensure orientation is correct after switching camera
        updateOrientation()
        
        captureSession.commitConfiguration()
    }
    
    private func updateMinZoomUI(for device: AVCaptureDevice) {
        var hasUltraWide = false
        if #available(iOS 13.0, *) {
            hasUltraWide = (device.deviceType == .builtInDualWideCamera || device.deviceType == .builtInTripleCamera || device.deviceType == .builtInUltraWideCamera)
        }
        
        DispatchQueue.main.async {
            self.minZoomUI = hasUltraWide ? 0.5 : 1.0
        }
    }
    
    func toggleCenterStage(_ isEnabled: Bool) {
        guard let device = videoDeviceInput?.device else { return }
        if device.activeFormat.isCenterStageSupported {
            AVCaptureDevice.centerStageControlMode = .app
            AVCaptureDevice.isCenterStageEnabled = isEnabled
            DispatchQueue.main.async {
                self.systemCenterStageEnabled = isEnabled
            }
        }
    }
    
    func toggleStudioLight(_ isEnabled: Bool) {
        // No-op: Studio light can only be controlled via iOS Control Center.
    }
    
    func setResolution(_ resolution: AppState.CameraResolution) {
        captureSession.beginConfiguration()
        let preset: AVCaptureSession.Preset
        switch resolution {
        case .hd720p: preset = .hd1280x720
        case .hd1080p: preset = .hd1920x1080
        case .uhd4K: preset = .hd4K3840x2160
        }
        
        if captureSession.canSetSessionPreset(preset) {
            captureSession.sessionPreset = preset
        } else {
            print("Preset \(preset.rawValue) not supported by current camera.")
            if captureSession.canSetSessionPreset(.hd1920x1080) {
                captureSession.sessionPreset = .hd1920x1080
            }
        }
        captureSession.commitConfiguration()
    }
    
    func setZoom(_ zoomFactorUI: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            var baseMultiplier: CGFloat = 1.0
            if #available(iOS 13.0, *) {
                if device.deviceType == .builtInDualWideCamera || device.deviceType == .builtInTripleCamera || device.deviceType == .builtInUltraWideCamera {
                    baseMultiplier = 2.0
                }
            }
            
            let hardwareZoom = zoomFactorUI * baseMultiplier
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0) // Safe UI cap
            device.videoZoomFactor = max(1.0, min(hardwareZoom, maxZoom))
            device.unlockForConfiguration()
        } catch {
            print("Error locking configuration to set zoom: \(error)")
        }
    }
}
