import Foundation
import AVFoundation
import Supabase

// MARK: - Briefing Audio Service
/// Plays TTS audio of the daily briefing via the briefing-tts edge function.
/// Caches MP3 files to disk for offline replay.

@Observable
final class BriefingAudioService {
    static let shared = BriefingAudioService()

    // MARK: - Types

    enum PlaybackState {
        case idle
        case loading
        case playing
        case paused
    }

    // MARK: - Public State

    var playbackState: PlaybackState = .idle
    var playbackProgress: Double = 0

    // MARK: - Private

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var currentBriefingKey: String?

    private struct TTSRequest: Encodable {
        let briefingKey: String
        let summaryText: String
    }

    private struct TTSResponse: Decodable {
        let audioUrl: String
    }

    private init() {}

    // MARK: - Public API

    func play(summary: MarketSummary) async {
        let briefingKey = summary.briefingKey

        // If already playing this briefing, just resume
        if currentBriefingKey == briefingKey && playbackState == .paused {
            togglePlayPause()
            return
        }

        // Stop any current playback
        cleanup()

        await MainActor.run {
            playbackState = .loading
            playbackProgress = 0
        }
        currentBriefingKey = briefingKey

        do {
            let fileURL = try await resolveAudioFile(briefingKey: briefingKey, summaryText: summary.summary)
            await startPlayback(fileURL: fileURL)
        } catch {
            logError("Briefing audio failed: \(error.localizedDescription)", category: .network)
            await MainActor.run {
                playbackState = .idle
            }
        }
    }

    func togglePlayPause() {
        guard let player else { return }

        switch playbackState {
        case .playing:
            player.pause()
            playbackState = .paused
        case .paused:
            player.play()
            playbackState = .playing
        default:
            break
        }
    }

    func stop() {
        cleanup()
        playbackState = .idle
        playbackProgress = 0
        currentBriefingKey = nil
    }

    // MARK: - Audio Resolution

    /// Returns a local file URL for the briefing audio, fetching from the edge function if not cached.
    private func resolveAudioFile(briefingKey: String, summaryText: String) async throws -> URL {
        let cachedURL = cacheFileURL(for: briefingKey)

        // Check disk cache
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            logDebug("Briefing audio cache hit: \(briefingKey)", category: .data)
            return cachedURL
        }

        // Call edge function to get audio URL
        guard SupabaseManager.shared.isConfigured else {
            throw BriefingAudioError.notConfigured
        }

        let request = TTSRequest(briefingKey: briefingKey, summaryText: summaryText)

        let data: Data = try await SupabaseManager.shared.functions.invoke(
            "briefing-tts",
            options: FunctionInvokeOptions(body: request),
            decode: { data, _ in data }
        )

        let response = try JSONDecoder().decode(TTSResponse.self, from: data)

        guard let audioURL = URL(string: response.audioUrl) else {
            throw BriefingAudioError.invalidURL
        }

        // Download MP3
        let (downloadedURL, _) = try await URLSession.shared.download(from: audioURL)

        // Ensure cache directory exists
        let cacheDir = cachedURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        // Move to cache location (overwrite if exists)
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            try FileManager.default.removeItem(at: cachedURL)
        }
        try FileManager.default.moveItem(at: downloadedURL, to: cachedURL)

        logDebug("Briefing audio cached: \(briefingKey)", category: .data)
        return cachedURL
    }

    // MARK: - Playback

    @MainActor
    private func startPlayback(fileURL: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logError("Audio session setup failed: \(error.localizedDescription)", category: .general)
        }

        let playerItem = AVPlayerItem(url: fileURL)
        let avPlayer = AVPlayer(playerItem: playerItem)
        player = avPlayer

        // Periodic time observer for progress
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let current = CMTimeGetSeconds(time)
            if let item = avPlayer.currentItem {
                let duration = CMTimeGetSeconds(item.duration)
                if duration.isFinite && duration > 0 && current.isFinite {
                    self.playbackProgress = current / duration
                }
            }
        }

        // End of playback observer
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.playbackState = .idle
            self?.playbackProgress = 0
            self?.currentBriefingKey = nil
        }

        avPlayer.play()
        playbackState = .playing
    }

    // MARK: - Cache

    private func cacheFileURL(for briefingKey: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches
            .appendingPathComponent("BriefingAudio", isDirectory: true)
            .appendingPathComponent("\(briefingKey).mp3")
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
    }
}

// MARK: - Error

enum BriefingAudioError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Audio service is not available"
        case .invalidURL:
            return "Invalid audio URL received"
        case .downloadFailed:
            return "Failed to download audio file"
        }
    }
}
