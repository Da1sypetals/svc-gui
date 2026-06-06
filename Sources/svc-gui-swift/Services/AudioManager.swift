import Foundation
import AVFoundation

enum PlaybackState {
    case idle, playing, paused, finished
}

final class AudioManager: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var tick: ((Double, Double) -> Void)?
    private var ended: (() -> Void)?
    private(set) var state: PlaybackState = .idle

    func load(_ url: URL, tick: @escaping (Double, Double) -> Void, ended: @escaping () -> Void) {
        teardown()
        self.tick = tick
        self.ended = ended
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            state = .playing
            startTimer()
        } catch {
            state = .idle
            ended()
        }
    }

    func togglePlayPause() {
        guard let p = player else { return }
        switch state {
        case .playing:
            p.pause()
            stopTimer()
            state = .paused
        case .paused, .finished:
            p.play()
            state = .playing
            startTimer()
        case .idle:
            break
        }
    }

    func seek(to seconds: Double) {
        guard let p = player else { return }
        p.currentTime = max(0, min(seconds, p.duration))
        tick?(p.currentTime, p.duration)
    }

    func isPlayingFile(_ url: URL) -> Bool {
        state != .idle && player?.url?.path == url.path
    }

    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        stopTimer()
        state = .finished
        // Report final position so UI shows 100%
        tick?(p.duration, p.duration)
        ended?()
    }

    func teardown() {
        stopTimer()
        player?.stop()
        player?.delegate = nil
        player = nil
        tick = nil
        ended = nil
        state = .idle
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let p = self.player, p.isPlaying else { return }
            self.tick?(p.currentTime, p.duration)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    override init() {
        super.init()
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
}
