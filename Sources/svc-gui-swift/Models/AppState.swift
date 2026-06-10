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

    // MARK: - Algorithm
    @Published var selectedAlgorithm: SVCAlgorithm = .rvc
    @Published var rvcModels: [RvcModelInfo] = []
    @Published var selectedRvcModelID: String?

    // MARK: - Parameters
    @Published var diffusionSteps: Int = 16
    @Published var pitchShift: Int = 9
    @Published var rvcIndexRate: Float = 0.3
    @Published var rvcVolumeEnvelope: Float = 1.0
    @Published var rvcProtect: Float = 0.33
    @Published var rvcF0Autotune: Bool = false
    @Published var rvcF0AutotuneStrength: Float = 1.0

    // MARK: - Generation
    @Published var isGenerating = false
    @Published var generationError: String?
    @Published var logs: String = ""
    private var cancelGenerationFlag = false
    private var generationInProgress = false

    // MARK: - Audio playback / recording
    private let audioManager = AudioManager()
    @Published var isPlaying = false
    @Published var isRecording = false
    @Published var currentPlaybackTime: Double = 0
    @Published var playbackDuration: Double = 0
    @Published var meterLevel: CGFloat = 0
    @Published var playingFileName: String? = nil

    // MARK: - FFI
    private var ffi: YingmusicFFI?
    private var rvcFFI: RvcFFI?

    static let diffusionStepValues = [1, 2, 4, 8, 16, 24, 32, 48, 64]

    init() {
        reloadAllFiles()
        scanRvcModels()
    }

    func reloadAllFiles() {
        recordings = storage.listRecordings()
        timbres = storage.listTimbres()
        outputs = storage.listOutputs()
    }

    func scanRvcModels() {
        let baseDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".svc-gui/rvc/models")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil)
        else { return }
        var models: [RvcModelInfo] = []
        for dir in contents where dir.hasDirectoryPath {
            let safetensors = dir.appendingPathComponent("model.safetensors")
            guard FileManager.default.fileExists(atPath: safetensors.path) else { continue }
            let index = dir.appendingPathComponent("model.index")
            let idxPath = FileManager.default.fileExists(atPath: index.path) ? index.path : nil
            models.append(RvcModelInfo(
                id: dir.lastPathComponent,
                name: dir.lastPathComponent,
                modelPath: safetensors.path,
                indexPath: idxPath
            ))
        }
        rvcModels = models
        if selectedRvcModelID == nil || !rvcModels.contains(where: { $0.id == selectedRvcModelID }) {
            selectedRvcModelID = rvcModels.first?.id
        }
    }

    // MARK: - Import

    func importRecording(from url: URL) {
        guard storage.importRecording(from: url) != nil else { return }
        recordings = storage.listRecordings()
    }

    func importTimbre(from url: URL) {
        guard storage.importTimbre(from: url) != nil else { return }
        timbres = storage.listTimbres()
        if selectedTimbreID == nil, let last = timbres.last {
            selectedTimbreID = last.id
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
        _ = storage.addRecording(from: tempURL)
        recordings = storage.listRecordings()
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
                    self?.playingFileName = nil
                }
            }
        )
        isPlaying = true
        playingFileName = file.name
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
        switch selectedAlgorithm {
        case .yingmusic: generateYingMusic()
        case .rvc: generateRvc()
        }
    }

    func generateYingMusic() {
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
        cancelGenerationFlag = false
        generationInProgress = true

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

            let pipe = LogPipe { text in
                DispatchQueue.main.async {
                    self.logs.append(text)
                }
            }
            let saved = pipe.redirect()

            let success = ffi.infer(
                source: recording.url.path,
                target: timbre.url.path,
                steps: self.diffusionSteps,
                pitch: Float(self.pitchShift),
                output: outputPath
            )

            pipe.restore(saved: saved)

            DispatchQueue.main.async {
                if self.cancelGenerationFlag {
                    try? FileManager.default.removeItem(atPath: outputPath)
                    self.isGenerating = false
                    self.generationInProgress = false
                    return
                }
                self.isGenerating = false
                self.generationInProgress = false
                if success {
                    self.outputs = self.storage.listOutputs()
                } else {
                    self.generationError = "生成失败，请查看日志"
                }
            }
        }
    }

    func generateRvc() {
        guard let recID = selectedRecordingID,
              let recording = recordings.first(where: { $0.id == recID }),
              let modelID = selectedRvcModelID,
              let model = rvcModels.first(where: { $0.id == modelID })
        else {
            generationError = "请先选择音源和模型"
            return
        }

        isGenerating = true
        generationError = nil
        cancelGenerationFlag = false
        generationInProgress = true

        if rvcFFI == nil {
            let commonDir = NSHomeDirectory() + "/.svc-gui/rvc/common/"
            let hubertPath = commonDir + "hubert.safetensors"
            let rmvpePath = commonDir + "rmvpe.safetensors"
            rvcFFI = RvcFFI(modelPath: model.modelPath, hubertPath: hubertPath, rmvpePath: rmvpePath)
        }

        let outputName = storage.generateOutputName(
            timbreName: model.name,
            steps: 0,
            pitch: pitchShift
        )
        let outputPath = storage.outputURL(for: outputName).path

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, let rvc = self.rvcFFI else { return }

            let pipe = LogPipe { text in
                DispatchQueue.main.async { self.logs.append(text) }
            }
            let saved = pipe.redirect()

            let success = rvc.infer(
                input: recording.url.path,
                output: outputPath,
                pitch: self.pitchShift,
                indexPath: model.indexPath,
                indexRate: self.rvcIndexRate,
                volume: self.rvcVolumeEnvelope,
                protect: self.rvcProtect,
                f0Autotune: self.rvcF0Autotune,
                f0AutotuneStrength: self.rvcF0AutotuneStrength
            )

            pipe.restore(saved: saved)

            DispatchQueue.main.async {
                if self.cancelGenerationFlag {
                    try? FileManager.default.removeItem(atPath: outputPath)
                    self.isGenerating = false
                    self.generationInProgress = false
                    return
                }
                self.isGenerating = false
                self.generationInProgress = false
                if success {
                    self.outputs = self.storage.listOutputs()
                } else {
                    self.generationError = "生成失败，请查看日志"
                }
            }
        }
    }

    func cancelGeneration() {
        ffi?.cancel()
        rvcFFI?.cancel()
        cancelGenerationFlag = true
    }

    private func findConfigPath() -> String? {
        let candidates = [
            NSHomeDirectory() + "/.svc-gui/yingmusic-svc.toml",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }
}
