import Foundation
import AVFoundation

enum FileKind {
    case recording, timbre, output
}

final class FileStorage {
    private let baseDir: URL
    private let recordingsDir: URL
    private let timbresDir: URL
    private let outputsDir: URL

    init() {
        baseDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".svc-gui/audio")
        recordingsDir = baseDir.appendingPathComponent("recordings")
        timbresDir = baseDir.appendingPathComponent("timbres")
        outputsDir = baseDir.appendingPathComponent("outputs")

        for dir in [recordingsDir, timbresDir, outputsDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - List

    func listRecordings() -> [AudioFile] {
        listFiles(in: recordingsDir)
    }

    func listTimbres() -> [AudioFile] {
        listFiles(in: timbresDir)
    }

    func listOutputs() -> [AudioFile] {
        listFiles(in: outputsDir).sorted { a, b in
            a.name < b.name
        }
    }

    private let audioExtensions = Set(["wav", "m4a", "mp3", "aac", "aiff", "aif", "caf", "flac"])

    private func listFiles(in dir: URL) -> [AudioFile] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ) else { return [] }
        var files: [AudioFile] = []
        for url in contents {
            guard audioExtensions.contains(url.pathExtension.lowercased()) else { continue }
            let name = url.deletingPathExtension().lastPathComponent
            files.append(AudioFile(url: url, name: name))
        }
        files.sort { a, b in
            let da = (try? a.url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let db = (try? b.url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return da < db
        }
        return files
    }

    // MARK: - Import

    func importRecording(from url: URL) -> AudioFile? {
        importFile(from: url, to: recordingsDir)
    }

    func importTimbre(from url: URL) -> AudioFile? {
        importFile(from: url, to: timbresDir)
    }

    private func importFile(from source: URL, to dir: URL) -> AudioFile? {
        guard validateMonoAudio(url: source) else { return nil }
        var dest = dir.appendingPathComponent(source.lastPathComponent)
        let stem = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var counter = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = dir.appendingPathComponent("\(stem)_\(counter).\(ext)")
            counter += 1
        }
        do {
            try FileManager.default.copyItem(at: source, to: dest)
            return AudioFile(url: dest, name: dest.deletingPathExtension().lastPathComponent)
        } catch {
            return nil
        }
    }

    // MARK: - Recording

    func addRecording(from tempURL: URL) -> AudioFile {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd_HH_mm_ss"
        let dateStr = formatter.string(from: Date())
        let name = dateStr
        var dest = recordingsDir.appendingPathComponent("\(name).wav")
        var counter = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = recordingsDir.appendingPathComponent("\(name)_\(counter).wav")
            counter += 1
        }
        try? FileManager.default.moveItem(at: tempURL, to: dest)
        return AudioFile(url: dest, name: dest.deletingPathExtension().lastPathComponent)
    }

    // MARK: - Output naming

    func generateOutputName(timbreName: String, steps: Int, pitch: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd_HH_mm_ss"
        let dateStr = formatter.string(from: Date())
        let prefix = pitch >= 0 ? "p" : "n"
        return "\(dateStr)_\(timbreName)_s\(steps)_\(prefix)\(abs(pitch))"
    }

    func outputURL(for name: String) -> URL {
        outputsDir.appendingPathComponent("\(name).wav")
    }

    // MARK: - Mutations

    func delete(file: AudioFile, kind: FileKind) {
        try? FileManager.default.removeItem(at: file.url)
    }

    func rename(file: AudioFile, kind: FileKind, to newName: String) {
        let dir: URL
        switch kind {
        case .recording: dir = recordingsDir
        case .timbre: dir = timbresDir
        case .output: dir = outputsDir
        }
        let newURL = dir.appendingPathComponent("\(newName).wav")
        try? FileManager.default.moveItem(at: file.url, to: newURL)
    }

    // MARK: - Validation

    func validateMonoAudio(url: URL) -> Bool {
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else { return false }
        let desc = track.formatDescriptions.first as! CMAudioFormatDescription
        let basic = CMAudioFormatDescriptionGetStreamBasicDescription(desc)!.pointee
        return basic.mChannelsPerFrame == 1
    }

    func validateMonoAudio(at path: String) -> Bool {
        validateMonoAudio(url: URL(fileURLWithPath: path))
    }
}
