import Foundation
import Speech

// MARK: - Transcription Service

/// Service for transcribing audio to text using iOS Speech Recognition.
@MainActor
final class TranscriptionService: ObservableObject {

    // MARK: - Published State

    @Published var isTranscribing = false
    @Published var transcription: String = ""
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?

    // MARK: - Initialization

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func hasPermission() -> Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - Transcription

    /// Transcribe an audio file to text
    func transcribe(audioURL: URL) async throws -> String {
        // Check permission
        guard await requestPermission() else {
            errorMessage = "Speech recognition permission denied"
            throw TranscriptionError.permissionDenied
        }

        // Check if recognizer is available
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition not available"
            throw TranscriptionError.notAvailable
        }

        isTranscribing = true
        errorMessage = nil

        defer {
            Task { @MainActor in
                isTranscribing = false
            }
        }

        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        // Perform recognition
        return try await withCheckedThrowingContinuation { continuation in
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        continuation.resume(throwing: TranscriptionError.recognitionFailed(error))
                        return
                    }

                    if let result = result, result.isFinal {
                        let text = result.bestTranscription.formattedString
                        self?.transcription = text
                        continuation.resume(returning: text)
                    }
                }
            }
        }
    }

    /// Cancel any ongoing transcription
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        isTranscribing = false
    }

    /// Clear the current transcription
    func clearTranscription() {
        transcription = ""
        errorMessage = nil
    }
}

// MARK: - Transcription Error

enum TranscriptionError: LocalizedError {
    case permissionDenied
    case notAvailable
    case recognitionFailed(Error)
    case noAudioFile

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission is required"
        case .notAvailable:
            return "Speech recognition is not available on this device"
        case .recognitionFailed(let error):
            return "Recognition failed: \(error.localizedDescription)"
        case .noAudioFile:
            return "No audio file to transcribe"
        }
    }
}
