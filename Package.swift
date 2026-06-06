// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "svc-gui-swift",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "svc-gui-swift",
            path: "Sources/svc-gui-swift"
        ),
    ]
)
