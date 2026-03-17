// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatWhisper",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/ivan-digital/qwen3-asr-swift", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "CatWhisper",
            dependencies: [
                .product(name: "Qwen3ASR", package: "qwen3-asr-swift"),
            ]
        ),
    ]
)
