import UniformTypeIdentifiers

func audioTypes() -> [UTType] {
    var types: [UTType] = [.wav, .mp3, .mpeg4Audio, .aiff, .audio]
    if let flac = UTType(filenameExtension: "flac") { types.append(flac) }
    return types
}
