//
//  Overlay_RecorderApp.swift
//  Overlay Recorder
//
//  Created by Amrit Dash on 10/04/26.
//

import SwiftUI
import AVFoundation

@main
struct Overlay_RecorderApp: App {
    init() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
