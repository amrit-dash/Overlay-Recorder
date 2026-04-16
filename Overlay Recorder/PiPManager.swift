import Foundation
import AVKit
import UIKit
import SwiftUI
import Combine

class CameraPreviewView: UIView {
    var isCircleMask: Bool = true {
        didSet {
            setNeedsLayout()
        }
    }

    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let layer = previewLayer {
                self.layer.addSublayer(layer)
                self.layer.masksToBounds = true
                layer.videoGravity = .resizeAspectFill
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
        if isCircleMask {
            self.layer.cornerRadius = min(bounds.width, bounds.height) / 2
        } else {
            self.layer.cornerRadius = 16 // nice rounded rectangle for fill
        }
    }
}

class PiPManager: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    static let shared = PiPManager()
    
    private var pipController: AVPictureInPictureController?
    private var pipVideoCallViewController: AVPictureInPictureVideoCallViewController?
    var sourceView = UIView()
    
    @Published var isPiPActive = false
    
    override private init() {
        super.init()
        setupPiP()
    }
    
    private func setupPiP() {
        // Removed AVAudioSession configuration to prevent conflict with ReplayKit
        // RPScreenRecorder needs to manage its own audio streams
        
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("PiP is not supported on this device.")
            return
        }
        
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("PiP is not supported on this device.")
            return
        }
        
        let pipVideoCallViewController = AVPictureInPictureVideoCallViewController()
        
        // Setup Camera View
        let cameraView = CameraPreviewView()
        cameraView.previewLayer = CameraManager.shared.previewLayer
        
        pipVideoCallViewController.view.addSubview(cameraView)
        pipVideoCallViewController.preferredContentSize = CGSize(width: 300, height: 300)
        
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cameraView.leadingAnchor.constraint(equalTo: pipVideoCallViewController.view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: pipVideoCallViewController.view.trailingAnchor),
            cameraView.topAnchor.constraint(equalTo: pipVideoCallViewController.view.topAnchor),
            cameraView.bottomAnchor.constraint(equalTo: pipVideoCallViewController.view.bottomAnchor)
        ])
        
        self.pipVideoCallViewController = pipVideoCallViewController
        
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: pipVideoCallViewController
        )
        
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        pipController?.canStartPictureInPictureAutomaticallyFromInline = false
    }
    
    func startPiP() {
        print("startPiP called. Supported: \(AVPictureInPictureController.isPictureInPictureSupported()), Possible: \(pipController?.isPictureInPicturePossible ?? false)")
        
        if pipController?.isPictureInPictureActive == false {
            pipController?.startPictureInPicture()
        }
    }
    
    func stopPiP() {
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
    }
    
    func updateLayout(aspectRatio: AppState.PiPAspectRatio, mask: AppState.PiPMask) {
        guard let vc = pipVideoCallViewController else { return }
        let size: CGSize
        switch aspectRatio {
        case .ratio16_9: size = CGSize(width: 320, height: 180)
        case .ratio9_16: size = CGSize(width: 180, height: 320)
        case .ratio1_1: size = CGSize(width: 300, height: 300)
        case .ratio4_3: size = CGSize(width: 320, height: 240)
        }
        vc.preferredContentSize = size
        
        if let cameraView = vc.view.subviews.first as? CameraPreviewView {
            cameraView.isCircleMask = (mask == .circle)
        }
    }
    
    // MARK: - AVPictureInPictureControllerDelegate
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPiPActive = true
        }
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPiPActive = false
        }
    }
}

struct PiPSourceView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        return PiPManager.shared.sourceView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
