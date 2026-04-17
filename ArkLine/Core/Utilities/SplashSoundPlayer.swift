import AVFoundation

/// Plays the splash screen sound effect from a bundled audio file.
final class SplashSoundPlayer {
    private var player: AVAudioPlayer?

    func play() {
        guard let url = Bundle.main.url(forResource: "splash_chime", withExtension: "mp3") else {
            logWarning("splash_chime.mp3 not found in bundle", category: .general)
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            // Sound is ~1.9s; animation sequence completes at ~1.2s. Speed up to match.
            player?.enableRate = true
            player?.rate = 1.6
            player?.play()
        } catch {
            logWarning("Splash sound failed: \(error)", category: .general)
        }
    }
}
