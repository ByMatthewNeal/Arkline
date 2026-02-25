import SwiftUI
import AVFoundation

// MARK: - Audio Player View

struct AudioPlayerView: View {
    let url: URL
    @Environment(\.colorScheme) private var colorScheme

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var isSeeking = false
    @State private var timeObserver: Any?
    @State private var endObserver: NSObjectProtocol?

    var body: some View {
        VStack(spacing: ArkSpacing.xs) {
            HStack(spacing: ArkSpacing.md) {
                // Play/Pause button
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.accent)
                }
                .buttonStyle(.plain)

                // Progress slider
                VStack(spacing: 2) {
                    Slider(
                        value: $currentTime,
                        in: 0...max(duration, 0.01),
                        onEditingChanged: sliderEditingChanged
                    )
                    .tint(AppColors.accent)

                    // Time labels
                    HStack {
                        Text(formatTime(currentTime))
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .monospacedDigit()

                        Spacer()

                        Text(formatTime(duration))
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .monospacedDigit()
                    }
                }
            }

            HStack {
                Text("Voice Note")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Setup

    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: playerItem)
        player = avPlayer

        // Load duration
        Task {
            if let asset = avPlayer.currentItem?.asset {
                do {
                    let cmDuration = try await asset.load(.duration)
                    let seconds = CMTimeGetSeconds(cmDuration)
                    if seconds.isFinite && seconds > 0 {
                        await MainActor.run {
                            duration = seconds
                        }
                    }
                } catch {
                    // Duration unavailable — will update from time observer
                }
            }
        }

        // Periodic time observer
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard !isSeeking else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite {
                currentTime = seconds
            }
            // Update duration if not yet available
            if duration == 0, let item = avPlayer.currentItem {
                let itemDuration = CMTimeGetSeconds(item.duration)
                if itemDuration.isFinite && itemDuration > 0 {
                    duration = itemDuration
                }
            }
        }

        // End of playback observer
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            isPlaying = false
            avPlayer.seek(to: .zero)
            currentTime = 0
        }
    }

    // MARK: - Playback

    private func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func sliderEditingChanged(_ editing: Bool) {
        isSeeking = editing
        if !editing {
            let targetTime = CMTime(seconds: currentTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        player?.pause()
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        endObserver = nil
        player = nil
        isPlaying = false
    }

    // MARK: - Formatting

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
}
