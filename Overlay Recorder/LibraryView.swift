import SwiftUI
import Photos
import AVKit
#if canImport(UIKit)
import UIKit
#endif

struct LibraryView: View {
    @Binding var selection: AppScreen?
    @Binding var columnVisibility: NavigationSplitViewVisibility
    
    @State private var recordings: [URL] = []
    @State private var isLoading = true
    @State private var selectedRecordings = Set<URL>()
    @Environment(\.editMode) private var editMode
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading Recordings...")
            } else if recordings.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    
                    Text("No Recordings Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your screen recordings will appear here once you save them.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else {
                List(selection: editMode?.wrappedValue.isEditing == true ? $selectedRecordings : nil) {
                    ForEach(recordings, id: \.self) { url in
                        ZStack {
                            RecordingCard(url: url)
                            
                            NavigationLink(destination: VideoDetailView(url: url, onDelete: {
                                deleteRecording(url: url)
                            })) {
                                EmptyView()
                            }
                            .opacity(0)
                            .buttonStyle(PlainButtonStyle())
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRecording(url: url)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            ShareLink(item: url) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    selection = .studio
                    columnVisibility = .all
                }) {
                    HStack {
                        Image(systemName: "chevron.backward")
                        Text("Studio")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            if !selectedRecordings.isEmpty {
                ToolbarItemGroup(placement: .bottomBar) {
                    ShareLink(items: Array(selectedRecordings)) {
                        Label("Share Selected", systemImage: "square.and.arrow.up")
                    }
                    Spacer()
                    Button(role: .destructive, action: deleteSelected) {
                        Image(systemName: "trash")
                        Text("Delete Selected")
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .onAppear(perform: loadRecordings)
    }
    
    private func deleteSelected() {
        for url in selectedRecordings {
            try? FileManager.default.removeItem(at: url)
        }
        selectedRecordings.removeAll()
        loadRecordings()
    }
    
    private func loadRecordings() {
        DispatchQueue.global(qos: .userInitiated).async {
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Recordings", isDirectory: true)
            try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
            
            if let files = try? FileManager.default.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: [.creationDateKey]) {
                let sortedFiles = files.filter { $0.pathExtension == "mp4" }.sorted {
                    let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
                DispatchQueue.main.async {
                    self.recordings = sortedFiles
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.recordings = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func deleteRecording(url: URL) {
        try? FileManager.default.removeItem(at: url)
        loadRecordings()
    }
}

struct RecordingCard: View {
    let url: URL
    
    @State private var duration: Double = 0
    @State private var creationDate: Date = Date()
    @State private var thumbnail: UIImage?
    
    var durationString: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "0:00"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 60)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 80, height: 60)
                        .cornerRadius(12)
                }
                
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(thumbnail == nil ? .blue : .white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack {
                    Text(creationDate.formatted(date: .abbreviated, time: .shortened))
                    Spacer()
                    Text(durationString)
                        .monospacedDigit()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            if let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate {
                self.creationDate = date
            }
            Task {
                let asset = AVURLAsset(url: url)
                if let dur = try? await asset.load(.duration) {
                    await MainActor.run {
                        self.duration = dur.seconds
                    }
                }
                
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 160, height: 120) // Keep thumbnail memory low
                
                let cgImage: CGImage? = await withCheckedContinuation { continuation in
                    generator.generateCGImageAsynchronously(for: .zero) { image, _, _ in
                        continuation.resume(returning: image)
                    }
                }
                
                if let cgImage = cgImage {
                    await MainActor.run {
                        self.thumbnail = UIImage(cgImage: cgImage)
                    }
                }
            }
        }
    }
}

struct VideoDetailView: View {
    let url: URL
    var onDelete: () -> Void
    
    @State private var player: AVPlayer?
    @State private var isShowingEditor = false
    @State private var isSaving = false
    @State private var saveMessage: String?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.bottom)
            } else {
                ProgressView("Loading Video...")
            }
            
            if let message = saveMessage {
                Text(message)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
                    .transition(.opacity)
            }
        }
        .blur(radius: isShowingEditor ? 10 : 0)
        .navigationTitle("Player")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.backward")
                        Text("Library")
                    }
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: saveToGallery) {
                    if isSaving {
                        ProgressView().progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                .disabled(isSaving)
                
                
                    Button("Trim") {
                        player?.pause()
                        isShowingEditor = true
                    }
                    .fullScreenCover(isPresented: $isShowingEditor) {
                        CustomVideoTrimmer(videoURL: url, onSave: { newURL in
                            isShowingEditor = false
                            presentationMode.wrappedValue.dismiss()
                        }, onCancel: {
                            isShowingEditor = false
                        })
                    }
                
                Button(role: .destructive, action: {
                    onDelete()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
            self.player = AVPlayer(url: url)
            self.player?.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private func saveToGallery() {
        isSaving = true
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.saveMessage = "Permission Denied"
                    self.isSaving = false
                    clearMessage()
                }
                return
            }
            
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
                if success || albumCollection != nil {
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
                        }) { success2, error2 in
                            DispatchQueue.main.async {
                                self.isSaving = false
                                if success2 {
                                    self.saveMessage = "Saved to Gallery!"
                                } else {
                                    self.saveMessage = "Failed to save: \(error2?.localizedDescription ?? "Unknown error")"
                                }
                                self.clearMessage()
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.isSaving = false
                            self.saveMessage = "Failed to find album"
                            self.clearMessage()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isSaving = false
                        self.saveMessage = "Failed to create album: \(error?.localizedDescription ?? "Unknown")"
                        self.clearMessage()
                    }
                }
            }
        }
    }
    
    private func clearMessage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                self.saveMessage = nil
            }
        }
    }
}

struct CustomVideoTrimmer: View {
    let videoURL: URL
    let onSave: (URL) -> Void
    let onCancel: () -> Void
    
    @State private var player: AVPlayer?
    @State private var startTime: Double = 0
    @State private var endTime: Double = 1
    @State private var duration: Double = 1
    @State private var isExporting = false
    @State private var isPlaying = false
    @State private var timeObserverToken: Any?
    @State private var thumbnails: [UIImage] = []
    
    private var screenHeight: CGFloat {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            return windowScene.screen.bounds.height
        }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.screen.bounds.height
        }
        return 800
        #else
        return 800
        #endif
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if let player = player {
                        VideoPlayer(player: player)
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: screenHeight * 0.45)
                            .background(Color.black)
                    } else {
                        Rectangle()
                            .fill(Color.black)
                            .frame(maxWidth: .infinity, maxHeight: screenHeight * 0.45)
                            .overlay(ProgressView().tint(.white))
                    }
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Trim Video")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Adjust start and end times")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                Button(action: togglePlay) {
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 48))
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 16) {
                                // Filmstrip Timeline
                                if !thumbnails.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Timeline Preview")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                            
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                HStack(spacing: 0) {
                                                    ForEach(0..<thumbnails.count, id: \.self) { i in
                                                        Image(uiImage: thumbnails[i])
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: geo.size.width / CGFloat(thumbnails.count), height: 48)
                                                            .clipped()
                                                    }
                                                }
                                                
                                                // Darken areas outside trim
                                                let safeDuration = max(duration, 0.1)
                                                let startX = (startTime / safeDuration) * geo.size.width
                                                let endX = (endTime / safeDuration) * geo.size.width
                                                
                                                Rectangle()
                                                    .fill(Color.black.opacity(0.6))
                                                    .frame(width: max(0, startX))
                                                
                                                Rectangle()
                                                    .fill(Color.black.opacity(0.6))
                                                    .frame(width: max(0, geo.size.width - endX))
                                                    .offset(x: endX)
                                                    
                                                // Highlight borders
                                                Rectangle()
                                                    .stroke(Color.yellow, lineWidth: 2)
                                                    .frame(width: max(0, endX - startX))
                                                    .offset(x: startX)
                                            }
                                        }
                                        .frame(height: 48)
                                        .cornerRadius(8)
                                        .padding(.horizontal)
                                    }
                                }
                                
                                // Start time slider
                                VStack(spacing: 8) {
                                    HStack {
                                        Image(systemName: "scissors")
                                            .foregroundColor(.blue)
                                        Text("Start Time")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(formatTime(startTime))
                                            .font(.subheadline)
                                            .monospacedDigit()
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Slider(value: $startTime, in: 0...max(endTime - 0.1, 0), step: 0.1) { _ in
                                        seek(to: startTime)
                                    }
                                    .tint(.blue)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                
                                // End time slider
                                VStack(spacing: 8) {
                                    HStack {
                                        Image(systemName: "scissors")
                                            .foregroundColor(.red)
                                        Text("End Time")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(formatTime(endTime))
                                            .font(.subheadline)
                                            .monospacedDigit()
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Slider(value: $endTime, in: min(startTime + 0.1, duration)...duration, step: 0.1) { _ in
                                        seek(to: endTime)
                                    }
                                    .tint(.red)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                            .padding(.horizontal)
                            
                            Spacer()
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Edit Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: trimVideo) {
                        if isExporting {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .onAppear(perform: setupPlayer)
            .onDisappear {
                player?.pause()
                if let token = timeObserverToken {
                    player?.removeTimeObserver(token)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func setupPlayer() {
        let asset = AVURLAsset(url: videoURL)
        Task {
            if let dur = try? await asset.load(.duration) {
                await MainActor.run {
                    self.duration = dur.seconds
                    self.endTime = dur.seconds
                    
                    #if os(iOS)
                    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try? AVAudioSession.sharedInstance().setActive(true)
                    #endif
                    
                    let p = AVPlayer(url: videoURL)
                    self.player = p
                    
                    self.timeObserverToken = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
                        if time.seconds >= self.endTime {
                            p.pause()
                            self.isPlaying = false
                            p.seek(to: CMTime(seconds: self.startTime, preferredTimescale: 600))
                        }
                    }
                    
                    self.generateThumbnails(for: asset, duration: dur.seconds)
                }
            }
        }
    }
    
    private func generateThumbnails(for asset: AVAsset, duration: Double) {
        guard duration > 0 else { return }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)
        
        let count = 8
        var times: [NSValue] = []
        let step = duration / Double(count)
        for i in 0..<count {
            let time = CMTime(seconds: step * Double(i) + step / 2, preferredTimescale: 600)
            times.append(NSValue(time: time))
        }
        
        // Ensure placeholders
        self.thumbnails = Array(repeating: UIImage(), count: count)
        
        generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, image, actualTime, result, error in
            if let cgImage = image {
                let uiImage = UIImage(cgImage: cgImage)
                // Find index by comparing seconds to avoid precision issues
                if let index = times.firstIndex(where: { abs($0.timeValue.seconds - requestedTime.seconds) < 0.01 }) {
                    DispatchQueue.main.async {
                        if self.thumbnails.count > index {
                            self.thumbnails[index] = uiImage
                        }
                    }
                }
            }
        }
    }
    
    private func togglePlay() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
        } else {
            if p.currentTime().seconds >= endTime {
                p.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
            }
            p.play()
        }
        isPlaying.toggle()
    }
    
    private func seek(to time: Double) {
        player?.pause()
        isPlaying = false
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }
    
    private func trimVideo() {
        isExporting = true
        let asset = AVURLAsset(url: videoURL)
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Recordings", isDirectory: true)
        let newFileName = "Trimmed_\(Date().timeIntervalSince1970).mp4"
        let outputURL = docsDir.appendingPathComponent(newFileName)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) ?? AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            isExporting = false
            return
        }
        
        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let end = CMTime(seconds: endTime, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: start, end: end)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = timeRange
        
        Task {
            if #available(iOS 18.0, *) {
                do {
                    try await exportSession.export(to: outputURL, as: .mp4)
                    await MainActor.run {
                        self.isExporting = false
                        try? FileManager.default.removeItem(at: self.videoURL)
                        self.onSave(outputURL)
                    }
                } catch {
                    await MainActor.run {
                        self.isExporting = false
                        print("Export failed: \(error.localizedDescription)")
                        self.onCancel()
                    }
                }
            } else {
                        Task { @MainActor in
            do {
                try await exportSession.export(to: outputURL, as: .mp4)
                self.isExporting = false
                try? FileManager.default.removeItem(at: self.videoURL)
                self.onSave(outputURL)
            } catch {
                self.isExporting = false
                print("Export failed: \(error.localizedDescription)")
                self.onCancel()
            }
        }
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? "0:00"
}}