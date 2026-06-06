import Foundation
import AVFoundation

enum PlaybackState {
    case idle, playing, paused, finished
}

final class AudioManager: NSObject, AVAudioPlayerDelegate {
    // ── Playback ────────────────────────────────────────────
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var tick: ((Double, Double) -> Void)?
    private var ended: (() -> Void)?
    private(set) var state: PlaybackState = .idle

    // ── Recording ───────────────────────────────────────────
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var onMeter: ((Float) -> Void)?
    private var tempRecordURL: URL?

    override init() {
        super.init()
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    // MARK: Playback

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

    // MARK: Recording

    var isRecording: Bool { recorder?.isRecording ?? false }

    func startRecording(onMeter: @escaping (Float) -> Void) {
        tempRecordURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
        ]
        do {
            recorder = try AVAudioRecorder(url: tempRecordURL!, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            self.onMeter = onMeter
            startMeterTimer()
        } catch {
            onMeter(0)
        }
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        stopMeterTimer()
        recorder = nil
        onMeter = nil
        return tempRecordURL
    }

    // MARK: Private

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

    private func startMeterTimer() {
        stopMeterTimer()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let rec = self.recorder else { return }
            rec.updateMeters()
            let db = rec.averagePower(forChannel: 0)
            self.onMeter?(max(0, min(1, (db + 60) / 60)))
        }
    }

    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
    }
}
