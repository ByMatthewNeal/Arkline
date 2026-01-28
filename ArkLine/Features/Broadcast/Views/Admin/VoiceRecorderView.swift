import SwiftUI

// MARK: - Voice Recorder View

/// View for recording voice notes and transcribing them to text.
struct VoiceRecorderView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @StateObject private var recordingService = VoiceRecordingService()
    @StateObject private var transcriptionService = TranscriptionService()

    @Binding var audioURL: URL?
    @Binding var transcribedText: String

    @State private var showingTranscription = false

    var body: some View {
        NavigationStack {
            VStack(spacing: ArkSpacing.xl) {
                Spacer()

                // Waveform visualization
                waveformView

                // Recording time
                Text(recordingService.formattedTime(recordingService.recordingTime))
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                // Status text
                Text(statusText)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                // Controls
                controlButtons

                // Transcription button
                if recordingService.recordingURL != nil && !recordingService.isRecording {
                    transcribeButton
                }

                Spacer()
                    .frame(height: ArkSpacing.xl)
            }
            .padding(ArkSpacing.md)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Voice Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recordingService.cancelRecording()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .disabled(recordingService.recordingURL == nil || recordingService.isRecording)
                }
            }
            .sheet(isPresented: $showingTranscription) {
                transcriptionSheet
            }
            .alert("Error", isPresented: .constant(recordingService.errorMessage != nil)) {
                Button("OK") {
                    recordingService.errorMessage = nil
                }
            } message: {
                Text(recordingService.errorMessage ?? "")
            }
        }
    }

    // MARK: - Status Text

    private var statusText: String {
        if recordingService.isRecording {
            return recordingService.isPaused ? "Paused" : "Recording..."
        } else if recordingService.recordingURL != nil {
            return "Recording saved"
        } else {
            return "Tap to start recording"
        }
    }

    // MARK: - Waveform View

    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(recordingService.isRecording && !recordingService.isPaused ? AppColors.accent : AppColors.textTertiary)
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: recordingService.audioLevel)
            }
        }
        .frame(height: 80)
    }

    private func barHeight(for index: Int) -> CGFloat {
        if recordingService.isRecording && !recordingService.isPaused {
            // Animated bars based on audio level
            let baseHeight: CGFloat = 10
            let maxHeight: CGFloat = 80
            let variation = sin(Double(index) * 0.5 + recordingService.recordingTime * 3)
            let levelMultiplier = CGFloat(recordingService.audioLevel)
            return baseHeight + (maxHeight - baseHeight) * levelMultiplier * CGFloat(0.5 + variation * 0.5)
        } else {
            // Static bars
            return 10
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: ArkSpacing.xxl) {
            // Cancel/Delete button
            if recordingService.isRecording || recordingService.recordingURL != nil {
                Button {
                    recordingService.cancelRecording()
                } label: {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(AppColors.error)
                        .frame(width: 56, height: 56)
                        .background(AppColors.error.opacity(0.1))
                        .clipShape(Circle())
                }
            }

            // Main record button
            Button {
                handleRecordTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(recordingService.isRecording ? AppColors.error : AppColors.accent)
                        .frame(width: 80, height: 80)

                    if recordingService.isRecording && !recordingService.isPaused {
                        // Stop icon
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 28, height: 28)
                    } else if recordingService.isPaused {
                        // Resume icon
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    } else {
                        // Record icon
                        Circle()
                            .fill(.white)
                            .frame(width: 28, height: 28)
                    }
                }
            }

            // Pause button
            if recordingService.isRecording && !recordingService.isPaused {
                Button {
                    recordingService.pauseRecording()
                } label: {
                    Image(systemName: "pause")
                        .font(.title2)
                        .foregroundColor(AppColors.accent)
                        .frame(width: 56, height: 56)
                        .background(AppColors.accent.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
    }

    // MARK: - Transcribe Button

    private var transcribeButton: some View {
        Button {
            showingTranscription = true
            transcribeAudio()
        } label: {
            HStack {
                Image(systemName: "text.bubble")
                Text("Transcribe to Text")
            }
            .font(ArkFonts.bodySemibold)
            .foregroundColor(AppColors.accent)
            .padding(.horizontal, ArkSpacing.lg)
            .padding(.vertical, ArkSpacing.sm)
            .background(AppColors.accent.opacity(0.1))
            .cornerRadius(ArkSpacing.sm)
        }
    }

    // MARK: - Transcription Sheet

    private var transcriptionSheet: some View {
        NavigationStack {
            VStack(spacing: ArkSpacing.md) {
                if transcriptionService.isTranscribing {
                    VStack(spacing: ArkSpacing.md) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Transcribing...")
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = transcriptionService.errorMessage {
                    VStack(spacing: ArkSpacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.warning)
                        Text(error)
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    TextEditor(text: $transcriptionService.transcription)
                        .font(ArkFonts.body)
                        .padding(ArkSpacing.sm)
                        .background(AppColors.cardBackground(colorScheme))
                        .cornerRadius(ArkSpacing.sm)
                        .padding()
                }
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingTranscription = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Text") {
                        transcribedText = transcriptionService.transcription
                        showingTranscription = false
                    }
                    .disabled(transcriptionService.transcription.isEmpty || transcriptionService.isTranscribing)
                }
            }
        }
    }

    // MARK: - Actions

    private func handleRecordTap() {
        if recordingService.isRecording {
            if recordingService.isPaused {
                recordingService.resumeRecording()
            } else {
                _ = recordingService.stopRecording()
            }
        } else {
            Task {
                try? await recordingService.startRecording()
            }
        }
    }

    private func transcribeAudio() {
        guard let url = recordingService.recordingURL else { return }

        Task {
            do {
                _ = try await transcriptionService.transcribe(audioURL: url)
            } catch {
                // Error is already handled in the service
            }
        }
    }

    private func saveAndDismiss() {
        audioURL = recordingService.recordingURL
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    VoiceRecorderView(
        audioURL: .constant(nil),
        transcribedText: .constant("")
    )
}
