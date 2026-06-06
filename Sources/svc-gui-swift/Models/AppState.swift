import Foundation
import Combine

class AppState: ObservableObject {
    // MARK: - Audio storage
    let storage = FileStorage()

    @Published var recordings: [AudioFile] = []
    @Published var timbres: [AudioFile] = []
    @Published var outputs: [AudioFile] = []

    // MARK: - Selection
    @Published var selectedRecordingID: String?
    @Published var selectedTimbreID: String?

    // MARK: - Parameters
    @Published var diffusionSteps: Int = 16
    @Published var pitchShift: Int = 12

    // MARK: - Generation
    @Published var isGenerating = false
    @Published var generationError: String?

    // MARK: - Audio playback / recording
    private let audioManager = AudioManager()
    @Published var isPlaying = false
    @Published var isRecording = false
    @Published var currentPlaybackTime: Double = 0
    @Published var playbackDuration: Double = 0
    @Published var meterLevel: CGFloat = 0

    // MARK: - FFI
    private var ffi: YingmusicFFI?

    let diffusionStepValues = [1, 2, 4, 8, 16, 24, 32, 48, 64]

    init() {
        reloadAllFiles()
    }

    func reloadAllFiles() {
        recordings = storage.listRecordings()
        timbres = storage.listTimbres()
        outputs = storage.listOutputs()
    }

    // MARK: - Import

    func importRecording(from url: URL) {
        guard let file = storage.importRecording(from: url) else { return }
        recordings.append(file)
    }

    func importTimbre(from url: URL) {
        guard let file = storage.importTimbre(from: url) else { return }
        timbres.insert(file, at: 0)
        if selectedTimbreID == nil {
            selectedTimbreID = file.id
        }
    }

    // MARK: - Record

    func startRecording() {
        audioManager.startRecording { [weak self] level in
            DispatchQueue.main.async {
                self?.meterLevel = CGFloat(level)
            }
        }
        isRecording = true
        meterLevel = 0
    }

    func stopRecording() {
        guard let tempURL = audioManager.stopRecording() else {
            isRecording = false
            return
        }
        let file = storage.addRecording(from: tempURL)
        recordings.append(file)
        isRecording = false
        meterLevel = 0
    }

    // MARK: - Playback

    func play(file: AudioFile) {
        if audioManager.isPlayingFile(file.url), audioManager.state != .idle {
            audioManager.togglePlayPause()
            isPlaying = (audioManager.state == .playing)
            return
        }
        audioManager.load(file.url,
            tick: { [weak self] cur, dur in
                DispatchQueue.main.async {
                    self?.currentPlaybackTime = cur
                    self?.playbackDuration = dur
                }
            },
            ended: { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                }
            }
        )
        isPlaying = true
    }

    func togglePlayPause() {
        audioManager.togglePlayPause()
        isPlaying = (audioManager.state == .playing)
    }

    func seekPlayback(to time: Double) {
        audioManager.seek(to: time)
        currentPlaybackTime = time
    }

    // MARK: - Delete / Rename

    func deleteRecording(_ file: AudioFile) {
        storage.delete(file: file, kind: .recording)
        recordings.removeAll { $0.id == file.id }
        if selectedRecordingID == file.id { selectedRecordingID = nil }
    }

    func deleteTimbre(_ file: AudioFile) {
        storage.delete(file: file, kind: .timbre)
        timbres.removeAll { $0.id == file.id }
        if selectedTimbreID == file.id { selectedTimbreID = nil }
    }

    func deleteOutput(_ file: AudioFile) {
        storage.delete(file: file, kind: .output)
        outputs.removeAll { $0.id == file.id }
    }

    func renameRecording(_ file: AudioFile, to newName: String) {
        storage.rename(file: file, kind: .recording, to: newName)
        reloadAllFiles()
    }

    func renameOutput(_ file: AudioFile, to newName: String) {
        storage.rename(file: file, kind: .output, to: newName)
        reloadAllFiles()
    }

    // MARK: - Generate

    func generate() {
        guard let recID = selectedRecordingID,
              let recording = recordings.first(where: { $0.id == recID }),
              let timbreID = selectedTimbreID,
              let timbre = timbres.first(where: { $0.id == timbreID })
        else {
            generationError = "请先选择音源和音色"
            return
        }

        isGenerating = true
        generationError = nil

        if ffi == nil {
            guard let configPath = Bundle.main.path(forResource: "yingmusic-svc", ofType: "toml")
                    ?? findConfigPath()
            else {
                generationError = "找不到配置文件 yingmusic-svc.toml"
                isGenerating = false
                return
            }
            ffi = YingmusicFFI(configPath: configPath)
        }

        let outputName = storage.generateOutputName(
            timbreName: timbre.name,
            steps: diffusionSteps,
            pitch: pitchShift
        )
        let outputPath = storage.outputURL(for: outputName).path

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, let ffi = self.ffi else { return }
            let success = ffi.infer(
                source: recording.url.path,
                target: timbre.url.path,
                steps: self.diffusionSteps,
                pitch: Float(self.pitchShift),
                output: outputPath
            )

            DispatchQueue.main.async {
                self.isGenerating = false
                if success {
                    let output = AudioFile(url: URL(fileURLWithPath: outputPath), name: outputName)
                    self.outputs.insert(output, at: 0)
                } else {
                    self.generationError = "生成失败，请查看日志"
                }
            }
        }
    }

    private func findConfigPath() -> String? {
        let candidates = [
            NSHomeDirectory() + "/.svc-gui/yingmusic-svc.toml",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }
}
