// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatWhisper",
    platforms: [.macOS("15.0")],
    dependencies: [
        .package(url: "https://github.com/ivan-digital/qwen3-asr-swift", revision: "f6e539a5e37ef017dbe23c5a58053753a56e2ba4"),
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.31.4"),
    ],
    targets: [
        .executableTarget(
            name: "CatWhisper",
            dependencies: [
                .product(name: "Qwen3ASR", package: "qwen3-asr-swift"),
                .product(name: "AudioCommon", package: "qwen3-asr-swift"),
                .product(name: "NemotronStreamingASR", package: "qwen3-asr-swift"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
