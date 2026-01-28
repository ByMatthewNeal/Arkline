import Foundation
import AVFoundation

// MARK: - Voice Recording Service

/// Service for recording audio using AVAudioRecorder.
/// Handles microphone permissions, recording state, and file management.
@MainActor
final class VoiceRecordingService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var recordingURL: URL?
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?

    // MARK: - Recording Settings

    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func hasPermission() -> Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    // MARK: - Recording Controls

    func startRecording() async throws {
        // Check permission
        guard await requestPermission() else {
            errorMessage = "Microphone permission denied"
            throw RecordingError.permissionDenied
        }

        // Setup audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        // Create unique file URL
        let fileName = "broadcast_\(UUID().uuidString).m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)

        // Create recorder
        audioRecorder = try AVAudioRecorder(url: audioURL, settings: recordingSettings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()

        // Start recording
        guard audioRecorder?.record() == true else {
            throw RecordingError.recordingFailed
        }

        recordingURL = audioURL
        isRecording = true
        isPaused = false
        recordingTime = 0
        errorMessage = nil

        // Start timers
        startTimers()
    }

    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        audioRecorder?.pause()
        isPaused = true
        stopTimers()
    }

    func resumeRecording() {
        guard isRecording, isPaused else { return }
        audioRecorder?.record()
        isPaused = false
        startTimers()
    }

    func stopRecording() -> URL? {
        stopTimers()

        audioRecorder?.stop()
        isRecording = false
        isPaused = false

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)

        return recordingURL
    }

    func cancelRecording() {
        let url = stopRecording()

        // Delete the file
        if let url = url {
            try? FileManager.default.removeItem(at: url)
        }

        recordingURL = nil
        recordingTime = 0
    }

    // MARK: - Timer Management

    private func startTimers() {
        // Recording time timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingTime += 0.1
            }
        }

        // Audio level timer
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevel()
            }
        }
    }

    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func updateAudioLevel() {
        audioRecorder?.updateMeters()
        let level = audioRecorder?.averagePower(forChannel: 0) ?? -160
        // Normalize from -160...0 to 0...1
        audioLevel = max(0, min(1, (level + 50) / 50))
    }

    // MARK: - Utility

    func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        if recordingURL == url {
            recordingURL = nil
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceRecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                errorMessage = "Recording finished unexpectedly"
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            errorMessage = error?.localizedDescription ?? "Encoding error occurred"
        }
    }
}

// MARK: - Recording Error

enum RecordingError: LocalizedError {
    case permissionDenied
    case recordingFailed
    case noRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record audio"
        case .recordingFailed:
            return "Failed to start recording"
        case .noRecording:
            return "No recording available"
        }
    }
}
