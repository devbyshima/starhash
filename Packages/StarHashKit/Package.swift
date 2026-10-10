// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StarHashKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "StarHashKit", targets: ["StarHashKit"])],
    targets: [
        .target(name: "StarHashKit", resources: [.process("Resources")]),
        .testTarget(name: "StarHashKitTests", dependencies: ["StarHashKit"]),
    ]
)
