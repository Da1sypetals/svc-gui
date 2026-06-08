import Foundation

final class LogPipe {
    private var pipe: Pipe?
    private let logHandler: (String) -> Void

    init(logHandler: @escaping (String) -> Void) {
        self.logHandler = logHandler
    }

    func redirect() -> Int32 {
        let p = Pipe()
        pipe = p
        let saved = dup(STDERR_FILENO)
        dup2(p.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        p.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                self?.logHandler(text)
            }
        }

        return saved
    }

    func restore(saved: Int32) {
        pipe?.fileHandleForReading.readabilityHandler = nil
        if saved >= 0 {
            dup2(saved, STDERR_FILENO)
            close(saved)
        }
        pipe = nil
    }
}
