import SwiftUI
import Speech
import AVFoundation

/// A mic button that streams live speech-to-text into a text binding.
/// Uses `AVAudioEngine` + `SFSpeechAudioBufferRecognitionRequest` for real-time transcription.
/// Auto-stops after ~60 s or when the user taps the button again.
struct LiveDictationButton: View {
    @Binding var text: String
    @State private var engine = DictationEngine()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            if engine.isRecording {
                engine.stop()
            } else {
                engine.start { transcript in
                    text = transcript
                }
            }
        } label: {
            Image(systemName: engine.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 16))
                .foregroundColor(engine.isRecording ? AppColors.error : AppColors.textPrimary(colorScheme).opacity(0.4))
                .symbolEffect(.pulse, isActive: engine.isRecording)
        }
    }
}

// MARK: - Dictation Engine

@Observable
@MainActor
private final class DictationEngine {
    var isRecording = false

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private static let maxDuration: TimeInterval = 60

    func start(onTranscript: @escaping (String) -> Void) {
        // Request permissions then begin
        Task {
            let speechOK = await requestSpeechPermission()
            let micOK = await requestMicPermission()
            guard speechOK, micOK else { return }
            beginRecording(onTranscript: onTranscript)
        }
    }

    func stop() {
        recognitionRequest?.endAudio()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        timeoutTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        timeoutTask = nil
        isRecording = false
    }

    // MARK: - Private

    private func beginRecording(onTranscript: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable else { return }

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            engine.prepare()
            try engine.start()
        } catch {
            logError("Audio engine start failed: \(error.localizedDescription)", category: .data)
            return
        }

        self.audioEngine = engine
        self.recognitionRequest = request
        self.isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    onTranscript(result.bestTranscription.formattedString)
                }
                if error != nil || (result?.isFinal == true) {
                    self?.stop()
                }
            }
        }

        // Auto-stop after max duration
        timeoutTask = Task {
            try? await Task.sleep(for: .seconds(Self.maxDuration))
            guard !Task.isCancelled else { return }
            stop()
        }
    }

    private func requestSpeechPermission() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { return true }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { newStatus in
                continuation.resume(returning: newStatus == .authorized)
            }
        }
    }

    private func requestMicPermission() async -> Bool {
        let status = AVAudioApplication.shared.recordPermission
        if status == .granted { return true }
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
