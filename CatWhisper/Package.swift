// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatWhisper",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/ivan-digital/qwen3-asr-swift", revision: "ba91e9e23af90afdf4323e85c0583d82a5acaabc"),
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.30.0"),
    ],
    targets: [
        .executableTarget(
            name: "CatWhisper",
            dependencies: [
                .product(name: "Qwen3ASR", package: "qwen3-asr-swift"),
                .product(name: "Qwen3Common", package: "qwen3-asr-swift"),
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
