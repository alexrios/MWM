// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MWM",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "mwm",
            targets: ["MWM"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MWM",
            dependencies: ["MWMCore"],
            path: "Sources/MWM"
        ),
        .systemLibrary(
            name: "MWMCore",
            path: "Sources/MWMCore",
            pkgConfig: "mwm-core"
        )
    ]
)
