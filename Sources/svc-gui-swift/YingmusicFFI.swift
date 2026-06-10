import Foundation

final class YingmusicFFI {
    private let handle: UnsafeMutableRawPointer
    private let libHandle: UnsafeMutableRawPointer

    private typealias CreateFunc = @convention(c) (UnsafePointer<CChar>) -> UnsafeMutableRawPointer?
    private typealias DestroyFunc = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias InferFunc = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>, UnsafePointer<CChar>, Int32, Float, UnsafePointer<CChar>) -> Int32

    private typealias CancelFunc = @convention(c) (UnsafeMutableRawPointer?) -> Void

    private let createFn: CreateFunc
    private let destroyFn: DestroyFunc
    private let inferFn: InferFunc
    private let cancelFn: CancelFunc

    init?(configPath: String) {
        let bundleDir = Bundle.main.bundlePath
        let dylibName = "libyingmusic.dylib"
        let dylibPaths = [
            URL(fileURLWithPath: bundleDir).appendingPathComponent(dylibName).path,
            URL(fileURLWithPath: bundleDir).appendingPathComponent("Contents/MacOS").appendingPathComponent(dylibName).path,
            URL(fileURLWithPath: bundleDir).appendingPathComponent("Contents/Frameworks").appendingPathComponent(dylibName).path,
            NSHomeDirectory() + "/.svc-gui/" + dylibName,
        ]
        guard let dylibPath = dylibPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            fatalError("Cannot find \(dylibName)")
        }

        guard let lib = dlopen(dylibPath, RTLD_NOW) else {
            let err = String(cString: dlerror())
            fatalError("Failed to load yingmusic dylib at \(dylibPath): \(err)")
        }

        guard let createPtr = dlsym(lib, "yingmusic_create"),
              let destroyPtr = dlsym(lib, "yingmusic_destroy"),
              let inferPtr = dlsym(lib, "yingmusic_infer"),
              let cancelPtr = dlsym(lib, "yingmusic_cancel")
        else {
            dlclose(lib)
            return nil
        }

        libHandle = lib
        let createFn = unsafeBitCast(createPtr, to: CreateFunc.self)
        let destroyFn = unsafeBitCast(destroyPtr, to: DestroyFunc.self)
        let inferFn = unsafeBitCast(inferPtr, to: InferFunc.self)
        self.createFn = createFn
        self.destroyFn = destroyFn
        self.inferFn = inferFn
        self.cancelFn = unsafeBitCast(cancelPtr, to: CancelFunc.self)

        let h = configPath.withCString { createFn($0) }
        guard let h else {
            dlclose(lib)
            return nil
        }
        handle = h
    }

    func cancel() {
        cancelFn(handle)
    }

    func infer(source: String, target: String, steps: Int, pitch: Float, output: String) -> Bool {
        return source.withCString { src in
            target.withCString { tgt in
                output.withCString { out in
                    inferFn(handle, src, tgt, Int32(steps), pitch, out) == 0
                }
            }
        }
    }

    deinit {
        destroyFn(handle)
        dlclose(libHandle)
    }
}
