import Foundation

enum SVCAlgorithm: String, CaseIterable, Identifiable {
    case rvc = "RVC"
    case yingmusic = "YingMusic-SVC"

    var id: String { rawValue }
}

struct RvcModelInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let modelPath: String
    let indexPath: String?
}
