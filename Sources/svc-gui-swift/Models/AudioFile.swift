import Foundation

struct AudioFile: Identifiable, Equatable {
    let id: String
    let url: URL
    var name: String

    init(url: URL, name: String) {
        self.id = url.lastPathComponent
        self.url = url
        self.name = name
    }
}
