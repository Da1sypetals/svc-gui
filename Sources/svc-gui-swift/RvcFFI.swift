import Foundation

final class RvcFFI {
    private let handle: UnsafeMutableRawPointer
    private let libHandle: UnsafeMutableRawPointer

    private typealias CreateFunc = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafePointer<CChar>) -> UnsafeMutableRawPointer?
    private typealias DestroyFunc = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias CancelFunc = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias InferFunc = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>, UnsafePointer<CChar>, Int32, UnsafePointer<CChar>, Float, Float, Float, Int32, Float) -> Int32

    private let createFn: CreateFunc
    private let destroyFn: DestroyFunc
    private let cancelFn: CancelFunc
    private let inferFn: InferFunc

    init?(modelPath: String, hubertPath: String, rmvpePath: String) {
        let dylibName = "librvc.dylib"
        let bundleDir = Bundle.main.bundlePath
        let dylibPaths = [
            URL(fileURLWithPath: bundleDir).appendingPathComponent(dylibName).path,
            URL(fileURLWithPath: bundleDir).appendingPathComponent("Contents/MacOS").appendingPathComponent(dylibName).path,
            NSHomeDirectory() + "/.svc-gui/" + dylibName,
        ]
        guard let dylibPath = dylibPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            fatalError("Cannot find librvc.dylib")
        }

        guard let lib = dlopen(dylibPath, RTLD_NOW) else {
            fatalError("Failed to load rvc dylib: \(String(cString: dlerror()))")
        }

        guard let createPtr = dlsym(lib, "rvc_create"),
              let destroyPtr = dlsym(lib, "rvc_destroy"),
              let cancelPtr = dlsym(lib, "rvc_cancel"),
              let inferPtr = dlsym(lib, "rvc_infer")
        else {
            dlclose(lib)
            return nil
        }

        libHandle = lib
        let createFn = unsafeBitCast(createPtr, to: CreateFunc.self)
        let destroyFn = unsafeBitCast(destroyPtr, to: DestroyFunc.self)
        let cancelFn = unsafeBitCast(cancelPtr, to: CancelFunc.self)
        let inferFn = unsafeBitCast(inferPtr, to: InferFunc.self)
        self.createFn = createFn
        self.destroyFn = destroyFn
        self.cancelFn = cancelFn
        self.inferFn = inferFn

        let handle = modelPath.withCString { m in
            hubertPath.withCString { h in
                rmvpePath.withCString { r in
                    createFn(m, h, r)
                }
            }
        }
        guard let handle else {
            dlclose(lib)
            return nil
        }
        self.handle = handle
    }

    func cancel() {
        cancelFn(handle)
    }

    func infer(input: String, output: String, pitch: Int, indexPath: String?, indexRate: Float, volume: Float, protect: Float, f0Autotune: Bool, f0AutotuneStrength: Float) -> Bool {
        let ip = indexPath ?? ""
        let autotuneVal: Int32 = f0Autotune ? 1 : 0
        return input.withCString { src in
            output.withCString { out in
                ip.withCString { idx in
                    inferFn(handle, src, out, Int32(pitch), idx, indexRate, volume, protect, autotuneVal, f0AutotuneStrength) == 0
                }
            }
        }
    }

    deinit {
        destroyFn(handle)
        dlclose(libHandle)
    }
}
