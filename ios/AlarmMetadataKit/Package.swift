// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AlarmMetadataKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "AlarmMetadataKit", targets: ["AlarmMetadataKit"]),
    ],
    targets: [
        .target(
            name: "AlarmMetadataKit",
            path: "Sources/AlarmMetadataKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ]
)
