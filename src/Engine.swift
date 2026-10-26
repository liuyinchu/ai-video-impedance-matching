import Foundation
import AppKit
import AVFoundation
import CoreGraphics
import CoreVideo

struct Scene: Codable {
    let id: Int
    let kicker: String
    let title: String
    let subtitle: String
    let narration: [String]
}

struct TimedCue: Codable {
    let text: String
    /// Absolute position on the full video timeline, in seconds.
    let start: Double
    let duration: Double
    /// Repository-relative path to the spoken sentence.
    let audio: String
}

struct TimedScene: Codable {
    let scene: Scene
    let start: Double
    let duration: Double
    let cues: [TimedCue]
}

private enum VideoError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let value): return value }
    }
}

private let fileManager = FileManager.default
private let videoWidth = 1280
private let videoHeight = 720
private let frameRate: Int32 = 30
private let timeScale: CMTimeScale = 60_000

private func announce(_ value: String) {
    print(value)
    fflush(stdout)
}

private func directory(_ path: String) throws {
    try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
}

private func removeIfPresent(_ path: String) throws {
    if fileManager.fileExists(atPath: path) { try fileManager.removeItem(atPath: path) }
}

private func mediaTime(_ seconds: Double) -> CMTime {
    CMTime(seconds: seconds, preferredTimescale: timeScale)
}

private func readJSON<T: Decodable>(_ type: T.Type, from path: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(contentsOf: URL(fileURLWithPath: path)))
}

private func writeJSON<T: Encodable>(_ value: T, to path: String) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(value).write(to: URL(fileURLWithPath: path), options: .atomic)
}

private func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        throw VideoError.message("Command failed (\(process.terminationStatus)): \(executable)")
    }
}

private func secondsInAsset(_ path: String) throws -> Double {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let value = CMTimeGetSeconds(asset.duration)
    guard value.isFinite, value > 0 else {
        throw VideoError.message("No valid media duration: \(path)")
    }
    return value
}

private func srtStamp(_ seconds: Double) -> String {
    let milliseconds = max(0, Int((seconds * 1000).rounded()))
    return String(format: "%02d:%02d:%02d,%03d", milliseconds / 3_600_000,
                  milliseconds / 60_000 % 60, milliseconds / 1000 % 60,
                  milliseconds % 1000)
}

private func prepare() throws {
    try directory("build/microsoft-audio")
    try directory("output")
    let scenes = try readJSON([Scene].self, from: "content/scenes.json")
    guard !scenes.isEmpty else { throw VideoError.message("No scenes in content/scenes.json") }
    let voice = ProcessInfo.processInfo.environment["NARRATION_VOICE"] ?? "zh-CN-YunxiNeural"
    let rate = ProcessInfo.processInfo.environment["NARRATION_RATE"] ?? "-8%"
    var position = 0.0
    var timeline: [TimedScene] = []
    var subtitleBlocks: [String] = []
    var subtitleIndex = 1

    for scene in scenes {
        var scenePosition = 0.5
        var cues: [TimedCue] = []
        for (sentenceIndex, text) in scene.narration.enumerated() {
            let stem = String(format: "%02d-%02d", scene.id, sentenceIndex + 1)
            let audioPath = "build/microsoft-audio/\(stem).mp3"
            let textPath = "build/microsoft-audio/\(stem).txt"
            let settingsPath = "build/microsoft-audio/\(stem).voice-settings.txt"
            let settings = "provider=microsoft-edge-neural\nvoice=\(voice)\nrate=\(rate)\n"
            let previousSettings = try? String(contentsOfFile: settingsPath, encoding: .utf8)
            let previousText = try? String(contentsOfFile: textPath, encoding: .utf8)
            let existingSize = (try? fileManager.attributesOfItem(atPath: audioPath)[.size] as? NSNumber)?.intValue ?? 0
            if previousText != text || previousSettings != settings || existingSize <= 0 {
                try text.write(toFile: textPath, atomically: true, encoding: .utf8)
                announce("Voice \(stem): \(text)")
                try run(fileManager.currentDirectoryPath + "/scripts/microsoft-tts.sh", [textPath, audioPath, voice, rate])
                try settings.write(toFile: settingsPath, atomically: true, encoding: .utf8)
            } else {
                announce("Voice \(stem): reusing existing audio")
            }
            let duration = try secondsInAsset(audioPath)
            let start = position + scenePosition
            let cue = TimedCue(text: text, start: start, duration: duration, audio: audioPath)
            cues.append(cue)
            for caption in captionSegments(for: cue) {
                subtitleBlocks.append("\(subtitleIndex)\n\(srtStamp(caption.start)) --> \(srtStamp(caption.start + caption.duration))\n\(caption.text)\n")
                subtitleIndex += 1
            }
            scenePosition += duration
            if sentenceIndex < scene.narration.count - 1 { scenePosition += 0.2 }
        }
        let duration = scenePosition + 0.5
        timeline.append(TimedScene(scene: scene, start: position, duration: duration, cues: cues))
        announce(String(format: "Scene %02d ready: %.2f seconds", scene.id, duration))
        position += duration
    }
    try writeJSON(timeline, to: "build/timeline.json")
    try writeJSON(["provider": "Microsoft Edge Online Neural", "voice": voice, "rate": rate], to: "build/speech-provider.json")
    try subtitleBlocks.joined(separator: "\n").write(toFile: "output/impedance-matching.zh-CN.srt", atomically: true, encoding: .utf8)
    announce(String(format: "Prepared %d scenes / %d captions / %.2f seconds", scenes.count, subtitleIndex - 1, position))
}

private func loadTimeline() throws -> [TimedScene] {
    let timeline = try readJSON([TimedScene].self, from: "build/timeline.json")
    guard !timeline.isEmpty else { throw VideoError.message("Timeline is empty; run prepare first") }
    return timeline
}

private func captionAt(_ time: Double, in scene: TimedScene) -> String {
    guard let cue = scene.cues.first(where: { time >= $0.start && time < $0.start + $0.duration }) else { return "" }
    return captionSegments(for: cue).first(where: { time >= $0.start && time < $0.start + $0.duration })?.text ?? ""
}

private func makeBitmap() throws -> CGContext {
    guard let context = CGContext(data: nil, width: videoWidth, height: videoHeight,
                                  bitsPerComponent: 8, bytesPerRow: videoWidth * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    else { throw VideoError.message("Cannot create preview bitmap context") }
    return context
}

private func preview() throws {
    let timeline = try loadTimeline()
    let totalDuration = timeline.last!.start + timeline.last!.duration
    try directory("output/frames")
    for timedScene in timeline {
        try autoreleasepool {
            let context = try makeBitmap()
            let elapsed = timedScene.duration * 0.5
            let time = timedScene.start + elapsed
            drawFrame(context: context, width: videoWidth, height: videoHeight,
                      scene: timedScene.scene, elapsed: elapsed, duration: timedScene.duration,
                      caption: captionAt(time, in: timedScene), globalTime: time,
                      totalDuration: totalDuration)
            guard let image = context.makeImage() else { throw VideoError.message("Cannot create preview image") }
            let rep = NSBitmapImageRep(cgImage: image)
            guard let data = rep.representation(using: .png, properties: [:]) else {
                throw VideoError.message("Cannot encode PNG preview")
            }
            let path = String(format: "output/frames/scene-%02d.png", timedScene.scene.id)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            announce("Preview \(path)")
        }
    }
}

private func renderSilent(_ timeline: [TimedScene]) throws {
    try directory("build")
    let path = "build/silent.mp4"
    try removeIfPresent(path)
    let totalDuration = timeline.last!.start + timeline.last!.duration
    let frameCount = Int(ceil(totalDuration * Double(frameRate)))
    let writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: path), fileType: .mp4)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: videoWidth,
        AVVideoHeightKey: videoHeight,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 4_000_000,
            AVVideoExpectedSourceFrameRateKey: frameRate,
            AVVideoMaxKeyFrameIntervalKey: frameRate * 2,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: videoWidth,
        kCVPixelBufferHeightKey as String: videoHeight,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
    guard writer.canAdd(input) else { throw VideoError.message("Cannot add H.264 video input") }
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? VideoError.message("Cannot start video writer") }
    writer.startSession(atSourceTime: .zero)
    guard let pool = adaptor.pixelBufferPool else { throw VideoError.message("Cannot create pixel buffer pool") }
    var sceneIndex = 0
    var previousPercent = -1

    for frame in 0..<frameCount {
        try autoreleasepool {
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed { throw writer.error ?? VideoError.message("Video writer failed") }
                Thread.sleep(forTimeInterval: 0.003)
            }
            let globalTime = Double(frame) / Double(frameRate)
            while sceneIndex + 1 < timeline.count && globalTime >= timeline[sceneIndex + 1].start {
                sceneIndex += 1
            }
            let timedScene = timeline[sceneIndex]
            var optionalBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &optionalBuffer)
            guard status == kCVReturnSuccess, let buffer = optionalBuffer else {
                throw VideoError.message("Cannot allocate video pixel buffer: \(status)")
            }
            CVPixelBufferLockBaseAddress(buffer, [])
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
            guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                          width: videoWidth, height: videoHeight,
                                          bitsPerComponent: 8,
                                          bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            else { throw VideoError.message("Cannot create frame drawing context") }
            // Coordinate conversion belongs to drawFrame, shared with PNG previews.
            drawFrame(context: context, width: videoWidth, height: videoHeight,
                      scene: timedScene.scene,
                      elapsed: max(0, globalTime - timedScene.start),
                      duration: timedScene.duration,
                      caption: captionAt(globalTime, in: timedScene),
                      globalTime: globalTime, totalDuration: totalDuration)
            let presentationTime = CMTime(value: Int64(frame), timescale: frameRate)
            guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? VideoError.message("Cannot append video frame \(frame)")
            }
        }
        let percent = (frame + 1) * 100 / frameCount
        if percent >= previousPercent + 2 || frame == frameCount - 1 {
            previousPercent = percent
            announce(String(format: "Rendering %3d%% | frame %d/%d | scene %02d", percent, frame + 1, frameCount, timeline[sceneIndex].scene.id))
        }
    }
    input.markAsFinished()
    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting { semaphore.signal() }
    semaphore.wait()
    guard writer.status == .completed else { throw writer.error ?? VideoError.message("Cannot finish video") }
    announce("Silent video ready: \(path)")
}

private func muxAudio(_ timeline: [TimedScene]) throws {
    try directory("output")
    let outputPath = "output/impedance-matching.mp4"
    try removeIfPresent(outputPath)
    let composition = AVMutableComposition()
    let videoAsset = AVURLAsset(url: URL(fileURLWithPath: "build/silent.mp4"))
    guard let sourceVideo = videoAsset.tracks(withMediaType: .video).first,
          let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
          let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    else { throw VideoError.message("Cannot create video/audio composition tracks") }
    try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: sourceVideo, at: .zero)
    videoTrack.preferredTransform = sourceVideo.preferredTransform
    for timedScene in timeline {
        for cue in timedScene.cues {
            let asset = AVURLAsset(url: URL(fileURLWithPath: cue.audio))
            guard let source = asset.tracks(withMediaType: .audio).first else {
                throw VideoError.message("No audio track: \(cue.audio)")
            }
            let range = CMTimeRange(start: .zero, duration: asset.duration)
            try audioTrack.insertTimeRange(range, of: source, at: mediaTime(cue.start))
        }
    }
    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
        throw VideoError.message("Cannot create MP4 export session")
    }
    exporter.outputURL = URL(fileURLWithPath: outputPath)
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    let semaphore = DispatchSemaphore(value: 0)
    exporter.exportAsynchronously { semaphore.signal() }
    var previousProgress = -1
    while semaphore.wait(timeout: .now() + 1) == .timedOut {
        let progress = Int(exporter.progress * 100)
        if progress >= previousProgress + 5 {
            previousProgress = progress
            announce("Muxing audio: \(progress)%")
        }
    }
    guard exporter.status == .completed else {
        throw exporter.error ?? VideoError.message("MP4 export failed: \(exporter.status.rawValue)")
    }
    let duration = try secondsInAsset(outputPath)
    announce(String(format: "Final video: %@ (%.2f seconds)", outputPath, duration))
}

@main
struct ImpedanceVideo {
    static func main() {
        do {
            let command = CommandLine.arguments.dropFirst().first ?? "help"
            switch command {
            case "prepare": try prepare()
            case "preview": try preview()
            case "verify": try verify()
            case "silent": try renderSilent(loadTimeline())
            case "mux": try muxAudio(loadTimeline())
            case "render":
                let timeline = try loadTimeline()
                try renderSilent(timeline)
                try muxAudio(timeline)
            default:
                announce("Usage: build/impedance-video prepare|preview|silent|mux|render|verify")
                announce("Run scripts/build.sh first. Commands operate in the repository root.")
            }
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

private func codecName(_ track: AVAssetTrack) -> String {
    guard let description = track.formatDescriptions.first else { return "unknown" }
    let code = CMFormatDescriptionGetMediaSubType(description as! CMFormatDescription)
    let bytes: [UInt8] = [UInt8((code >> 24) & 0xff), UInt8((code >> 16) & 0xff),
                          UInt8((code >> 8) & 0xff), UInt8(code & 0xff)]
    return String(bytes: bytes, encoding: .ascii) ?? String(code)
}

private func extractVideoFrame(asset: AVAsset, track: AVAssetTrack, at seconds: Double, to path: String) throws {
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else { throw VideoError.message("Cannot decode verification frame") }
    reader.add(output)
    reader.timeRange = CMTimeRange(start: mediaTime(seconds), duration: mediaTime(1.0))
    guard reader.startReading() else { throw reader.error ?? VideoError.message("Cannot start verification reader") }
    defer { reader.cancelReading() }
    guard let sample = output.copyNextSampleBuffer(), let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
        throw reader.error ?? VideoError.message("No video frame at \(seconds) seconds")
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
          let image = context.makeImage(),
          let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { throw VideoError.message("Cannot save decoded video frame") }
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    let actualTime = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
    announce(String(format: "Decoded frame %.3fs -> %@", actualTime, path))
}

private func verifyVideoContinuity(asset: AVAsset, track: AVAssetTrack) throws {
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else { throw VideoError.message("Cannot create full video decoder") }
    reader.add(output)
    guard reader.startReading() else { throw reader.error ?? VideoError.message("Cannot start full video decoder") }
    var frames = 0
    var previous = -1.0
    var maximumGap = 0.0
    while let sample = output.copyNextSampleBuffer() {
        try autoreleasepool {
            let time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
            guard time.isFinite, time >= previous else {
                throw VideoError.message("Video presentation timestamps are invalid or decrease")
            }
            if previous >= 0 { maximumGap = max(maximumGap, time - previous) }
            guard let buffer = CMSampleBufferGetImageBuffer(sample),
                  CVPixelBufferGetWidth(buffer) == videoWidth,
                  CVPixelBufferGetHeight(buffer) == videoHeight else {
                throw VideoError.message("A video frame could not be decoded at the expected dimensions")
            }
            previous = time
            frames += 1
        }
    }
    guard reader.status == .completed else { throw reader.error ?? VideoError.message("Full video decode failed") }
    let duration = CMTimeGetSeconds(asset.duration)
    let minimumFrames = Int((duration * Double(frameRate)).rounded(.down)) - 1
    guard frames >= minimumFrames, previous >= duration - 0.1,
          maximumGap < 1.5 / Double(frameRate) else {
        throw VideoError.message("Full video decode has missing frames or timestamp gaps")
    }
    announce(String(format: "Full video decode: %d frames, last %.3fs, maximum frame gap %.6fs", frames, previous, maximumGap))
}

private func verifyAudio(asset: AVAsset, track: AVAssetTrack) throws {
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false
    ])
    guard reader.canAdd(output) else { throw VideoError.message("Cannot decode verification audio") }
    reader.add(output)
    guard reader.startReading() else { throw reader.error ?? VideoError.message("Cannot read verification audio") }
    var squareSum = 0.0
    var peak = 0.0
    var sampleCount: Int64 = 0
    var nonzeroCount: Int64 = 0
    var clippedCount: Int64 = 0
    var audioWindows: [Int: (square: Double, count: Int)] = [:]
    while let sample = output.copyNextSampleBuffer() {
        try autoreleasepool {
            guard let block = CMSampleBufferGetDataBuffer(sample) else {
                throw VideoError.message("Missing PCM audio sample buffer")
            }
            let byteCount = CMBlockBufferGetDataLength(block)
            guard byteCount % MemoryLayout<Float>.size == 0 else {
                throw VideoError.message("Unexpected PCM audio byte size")
            }
            var floats = [Float](repeating: 0, count: byteCount / MemoryLayout<Float>.size)
            let copyStatus = floats.withUnsafeMutableBytes { raw in
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: byteCount, destination: raw.baseAddress!)
            }
            guard copyStatus == kCMBlockBufferNoErr else { throw VideoError.message("Cannot copy PCM audio") }
            let window = Int(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample)) / 20)
            var windowStats = audioWindows[window] ?? (square: 0.0, count: 0)
            for value in floats {
                guard value.isFinite else { throw VideoError.message("Audio contains a non-finite sample") }
                let amplitude = abs(Double(value))
                squareSum += amplitude * amplitude
                windowStats.square += amplitude * amplitude
                windowStats.count += 1
                peak = max(peak, amplitude)
                sampleCount += 1
                if amplitude > 0.00001 { nonzeroCount += 1 }
                if amplitude >= 0.999 { clippedCount += 1 }
            }
            audioWindows[window] = windowStats
        }
    }
    guard reader.status == .completed else { throw reader.error ?? VideoError.message("Audio verification decode failed") }
    guard sampleCount > 0 else { throw VideoError.message("Audio track has no decoded samples") }
    let rms = sqrt(squareSum / Double(sampleCount))
    let rmsDB = rms > 0 ? 20 * log10(rms) : -.infinity
    let peakDB = peak > 0 ? 20 * log10(peak) : -.infinity
    announce(String(format: "Audio PCM: %lld samples, RMS %.6f (%.1f dBFS), peak %.6f (%.1f dBFS), nonzero %.1f%%, near-full-scale %lld", sampleCount, rms, rmsDB, peak, peakDB, Double(nonzeroCount) / Double(sampleCount) * 100, clippedCount))
    guard rms > 0.00001, peak > 0.0001 else { throw VideoError.message("Exported audio is silent or nearly silent") }
    let expectedWindows = Int(ceil(CMTimeGetSeconds(track.timeRange.duration) / 20))
    for window in 0..<expectedWindows {
        guard let stats = audioWindows[window], stats.count > 0,
              sqrt(stats.square / Double(stats.count)) > 0.00001 else {
            throw VideoError.message("Silent or missing audio in 20-second window starting at \(window * 20)s")
        }
    }
    announce("Audio continuity: all \(expectedWindows) consecutive 20-second windows contain non-silent PCM")
}

private func verify() throws {
    let timeline = try loadTimeline()
    let speech = try readJSON([String: String].self, from: "build/speech-provider.json")
    guard let voice = speech["voice"], voice.hasSuffix("Neural"),
          timeline.flatMap({ $0.cues }).allSatisfy({ $0.audio.hasPrefix("build/microsoft-audio/") }) else {
        throw VideoError.message("Narration does not use the configured Microsoft neural audio")
    }
    announce("Narration: \(speech["provider"] ?? "unknown") | \(voice) | rate \(speech["rate"] ?? "unknown")")
    let expectedDuration = timeline.last!.start + timeline.last!.duration
    let path = "output/impedance-matching.mp4"
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let duration = CMTimeGetSeconds(asset.duration)
    guard duration.isFinite, duration > 0 else { throw VideoError.message("Exported MP4 has no valid duration") }
    let videoTracks = asset.tracks(withMediaType: .video)
    let audioTracks = asset.tracks(withMediaType: .audio)
    announce(String(format: "Verify duration: %.3fs / timeline %.3fs / difference %.3fs", duration, expectedDuration, duration - expectedDuration))
    announce("Tracks: \(videoTracks.count) video, \(audioTracks.count) audio")
    guard abs(duration - expectedDuration) < 0.25 else { throw VideoError.message("MP4 duration differs from timeline by at least 0.25 seconds") }
    guard let videoTrack = videoTracks.first, let audioTrack = audioTracks.first else {
        throw VideoError.message("Exported MP4 is missing a video or audio track")
    }
    for (index, track) in videoTracks.enumerated() {
        let size = track.naturalSize
        announce(String(format: "Video %d: %.0fx%.0f, %.3f fps, codec %@, track duration %.3fs", index + 1, size.width, size.height, track.nominalFrameRate, codecName(track), CMTimeGetSeconds(track.timeRange.duration)))
    }
    for (index, track) in audioTracks.enumerated() {
        announce(String(format: "Audio %d: codec %@, track duration %.3fs", index + 1, codecName(track), CMTimeGetSeconds(track.timeRange.duration)))
    }
    guard Int(videoTrack.naturalSize.width) == videoWidth,
          Int(videoTrack.naturalSize.height) == videoHeight,
          abs(videoTrack.nominalFrameRate - Float(frameRate)) < 0.1 else {
        throw VideoError.message("Exported video dimensions or frame rate differ from requested settings")
    }
    var cueCount = 0
    for scene in timeline {
        guard !scene.cues.isEmpty else { throw VideoError.message("Scene \(scene.scene.id) has no spoken sentences") }
        for cue in scene.cues {
            let audioDuration = try secondsInAsset(cue.audio)
            guard abs(audioDuration - cue.duration) < 0.05 else {
                throw VideoError.message("Cached sentence audio duration differs from timeline: \(cue.audio)")
            }
            guard cue.start >= scene.start, cue.start + cue.duration <= scene.start + scene.duration + 0.01 else {
                throw VideoError.message("Sentence audio falls outside its scene: \(cue.audio)")
            }
            cueCount += 1
        }
    }
    announce("Sentence audio checked: \(cueCount) valid clips")
    try directory("output/verify")
    let points: [(String, Double)] = [("first", 0), ("middle", duration * 0.5),
                                      ("last", max(0, duration - 2 / Double(frameRate)))]
    for (label, time) in points {
        try extractVideoFrame(asset: asset, track: videoTrack, at: time, to: "output/verify/frame-\(label).png")
    }
    try verifyVideoContinuity(asset: asset, track: videoTrack)
    try verifyAudio(asset: asset, track: audioTrack)
    announce("Verification passed: decoded video frames and audible PCM audio are present.")
}

private struct CaptionSegment {
    let text: String
    let start: Double
    let duration: Double
}

/// Shared by burnt-in captions and SRT: retain natural phrase boundaries where
/// possible, cap every chunk at 30 grapheme clusters, then share the utterance
/// duration in proportion to the displayed character count.
private func captionSegments(for cue: TimedCue) -> [CaptionSegment] {
    let maximumCharacters = 30
    let boundaries = Set<Character>("，。！？；：、,.!?;:\n")
    var clauses: [String] = []
    var clause = ""
    for character in cue.text {
        clause.append(character)
        if boundaries.contains(character) {
            let cleaned = clause.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty { clauses.append(cleaned) }
            clause = ""
        }
    }
    let trailing = clause.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trailing.isEmpty { clauses.append(trailing) }
    var chunks: [String] = []
    var pending = ""
    for originalClause in clauses {
        var remaining = originalClause
        if pending.count + remaining.count <= maximumCharacters {
            pending += remaining
            continue
        }
        if !pending.isEmpty {
            chunks.append(pending)
            pending = ""
        }
        while remaining.count > maximumCharacters {
            let split = remaining.index(remaining.startIndex, offsetBy: maximumCharacters)
            let part = String(remaining[..<split]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !part.isEmpty { chunks.append(part) }
            remaining = String(remaining[split...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        pending = remaining
    }
    if !pending.isEmpty { chunks.append(pending) }
    let totalCharacters = chunks.reduce(0) { $0 + $1.count }
    guard totalCharacters > 0, cue.duration > 0 else { return [] }
    var usedCharacters = 0
    return chunks.map { chunk in
        let start = cue.start + cue.duration * Double(usedCharacters) / Double(totalCharacters)
        usedCharacters += chunk.count
        let end = cue.start + cue.duration * Double(usedCharacters) / Double(totalCharacters)
        return CaptionSegment(text: chunk, start: start, duration: end - start)
    }
}
