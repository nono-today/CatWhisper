import Foundation
import MLX
import MLXNN
import MLXFast
import Qwen3Common
import Qwen3ASR

// MARK: - WhisperModel

/// Top-level Whisper ASR model combining encoder, decoder, tokenizer, and feature extraction.
///
/// Supports loading pretrained weights from HuggingFace and greedy transcription.
class WhisperModel {

    // MARK: - Special token constants

    static let eotToken: Int32 = 50257        // <|endoftext|>
    static let sotToken: Int32 = 50258        // <|startoftranscript|>
    static let zhToken: Int32 = 50260         // <|zh|>
    static let transcribeToken: Int32 = 50359 // <|transcribe|>
    static let noTimestampsToken: Int32 = 50363

    // MARK: - Properties

    let config: WhisperConfig
    let encoder: WhisperAudioEncoder
    let decoder: WhisperTextDecoder
    let featureExtractor: WhisperFeatureExtractor
    var tokenizer: Qwen3Tokenizer?

    // MARK: - Initialization

    init(config: WhisperConfig) {
        self.config = config
        self.encoder = WhisperAudioEncoder(config)
        self.decoder = WhisperTextDecoder(config)
        self.featureExtractor = WhisperFeatureExtractor()
        self.tokenizer = nil
    }

    // MARK: - Transcription

    /// Transcribe raw audio samples to text using greedy decoding.
    ///
    /// - Parameters:
    ///   - audio: Raw audio samples (mono, Float array)
    ///   - sampleRate: Sample rate of the input audio (default 16000)
    ///   - maxTokens: Maximum number of tokens to generate (default 224)
    /// - Returns: Transcribed text string
    func transcribe(
        audio: [Float],
        sampleRate: Int = 16_000,
        maxTokens: Int = 224
    ) -> String {
        // 1. Compute mel spectrogram: [128, nFrames]
        let mel = featureExtractor.process(audio, sampleRate: sampleRate)

        // 2. Pad mel to exactly 3000 frames
        let paddedMel = padMelTo3000(mel)

        // 3. Add batch dimension: [128, 3000] -> [1, 128, 3000]
        let batchedMel = paddedMel.expandedDimensions(axis: 0)

        // 4. Encode audio: [1, 128, 3000] -> [1, 1500, nState]
        let audioFeatures = encoder(batchedMel)

        // 5. Greedy decode
        let initialTokens: [Int32] = [
            Self.sotToken,
            Self.zhToken,
            Self.transcribeToken,
            Self.noTimestampsToken
        ]

        var tokens = initialTokens
        var generatedTokens: [Int32] = []
        var selfAttnCaches: [(MLXArray, MLXArray)]? = nil
        var crossAttnCaches: [(MLXArray, MLXArray)?]? = nil

        for step in 0..<maxTokens {
            // Build input token IDs for this step
            let inputTokens: [Int32]
            if step == 0 {
                // First iteration: pass full prompt
                inputTokens = tokens
            } else {
                // Subsequent iterations: pass only the last token (use caches)
                inputTokens = [tokens.last!]
            }

            let tokenIds = MLXArray(inputTokens).expandedDimensions(axis: 0)

            // Run decoder
            let (logits, newSelfCaches, newCrossCaches) = decoder(
                tokenIds,
                audioFeatures: audioFeatures,
                selfAttnCaches: selfAttnCaches,
                crossAttnCaches: crossAttnCaches
            )

            selfAttnCaches = newSelfCaches
            crossAttnCaches = newCrossCaches

            // Argmax on the last position
            let lastLogits = logits[0..., (logits.dim(1) - 1)..<logits.dim(1), 0...]
            let nextToken = argMax(lastLogits, axis: -1).squeezed().item(Int32.self)

            // Check for end of text
            if nextToken == Self.eotToken {
                break
            }

            tokens.append(nextToken)
            generatedTokens.append(nextToken)
        }

        // 6. Decode with tokenizer
        if let tokenizer {
            return tokenizer.decode(tokens: generatedTokens.map { Int($0) })
        } else {
            // Fallback: return raw token IDs
            return generatedTokens.map { String($0) }.joined(separator: " ")
        }
    }

    // MARK: - Mel Padding

    /// Pad or truncate mel spectrogram to exactly 3000 frames.
    ///
    /// - Parameter mel: Mel spectrogram of shape [128, nFrames]
    /// - Returns: Mel spectrogram of shape [128, 3000]
    private func padMelTo3000(_ mel: MLXArray) -> MLXArray {
        let nFrames = mel.dim(1)
        if nFrames >= 3000 {
            return mel[0..., ..<3000]
        }
        let padWidth = 3000 - nFrames
        return padded(mel, widths: [.init((low: 0, high: 0)), .init((low: 0, high: padWidth))])
    }

    // MARK: - Weight Loading

    /// Load pretrained weights from safetensors files in a directory.
    ///
    /// - Parameter directory: URL of directory containing safetensors files
    func loadWeights(from directory: URL) throws {
        let allWeights = try CommonWeightLoader.loadAllSafetensors(from: directory)

        // Split weights by encoder/decoder prefix
        var encWeights: [String: MLXArray] = [:]
        var decWeights: [String: MLXArray] = [:]

        for (key, value) in allWeights {
            if key.hasPrefix("encoder.") {
                let strippedKey = String(key.dropFirst("encoder.".count))
                encWeights[strippedKey] = value
            } else if key.hasPrefix("decoder.") {
                let strippedKey = String(key.dropFirst("decoder.".count))
                decWeights[strippedKey] = value
            }
        }

        // --- Apply encoder weights ---

        // Conv1d layers (transpose=true for PyTorch -> MLX conversion)
        CommonWeightLoader.applyConv1dWeights(
            to: encoder.conv1, prefix: "conv1", from: encWeights, transpose: true
        )
        CommonWeightLoader.applyConv1dWeights(
            to: encoder.conv2, prefix: "conv2", from: encWeights, transpose: true
        )

        // Positional embedding
        if let posEmb = encWeights["positional_embedding"] {
            encoder.positionalEmbedding = posEmb
        }

        // Encoder transformer blocks (self-attention only, no cross-attention)
        for i in 0..<encoder.blocks.count {
            loadBlockWeights(encoder.blocks[i], prefix: "blocks.\(i)", from: encWeights)
        }

        // Final layer norm
        CommonWeightLoader.applyLayerNormWeights(
            to: encoder.lnPost, prefix: "ln_post", from: encWeights
        )

        // --- Apply decoder weights ---

        // Token embedding
        CommonWeightLoader.applyEmbeddingWeights(
            to: decoder.tokenEmbedding, prefix: "token_embedding", from: decWeights
        )

        // Positional embedding
        if let posEmb = decWeights["positional_embedding"] {
            decoder.positionalEmbedding = posEmb
        }

        // Decoder transformer blocks (with cross-attention)
        for i in 0..<decoder.blocks.count {
            loadBlockWeights(decoder.blocks[i], prefix: "blocks.\(i)", from: decWeights)
        }

        // Final layer norm
        CommonWeightLoader.applyLayerNormWeights(
            to: decoder.ln, prefix: "ln", from: decWeights
        )
    }

    // MARK: - Weight Loading Helpers

    /// Apply weights to a multi-head attention module.
    private func loadAttnWeights(
        _ attn: WhisperMultiHeadAttention,
        prefix: String,
        from weights: [String: MLXArray]
    ) {
        CommonWeightLoader.applyLinearWeights(to: attn.query, prefix: "\(prefix).query", from: weights)
        CommonWeightLoader.applyLinearWeights(to: attn.key, prefix: "\(prefix).key", from: weights)
        CommonWeightLoader.applyLinearWeights(to: attn.value, prefix: "\(prefix).value", from: weights)
        CommonWeightLoader.applyLinearWeights(to: attn.out, prefix: "\(prefix).out", from: weights)
    }

    /// Apply weights to a residual attention block (self-attn, optional cross-attn, MLP).
    private func loadBlockWeights(
        _ block: WhisperResidualAttentionBlock,
        prefix: String,
        from weights: [String: MLXArray]
    ) {
        // Self-attention
        loadAttnWeights(block.attn, prefix: "\(prefix).attn", from: weights)
        CommonWeightLoader.applyLayerNormWeights(
            to: block.attnLn, prefix: "\(prefix).attn_ln", from: weights
        )

        // Cross-attention (decoder blocks only)
        if let crossAttn = block.crossAttn, let crossAttnLn = block.crossAttnLn {
            loadAttnWeights(crossAttn, prefix: "\(prefix).cross_attn", from: weights)
            CommonWeightLoader.applyLayerNormWeights(
                to: crossAttnLn, prefix: "\(prefix).cross_attn_ln", from: weights
            )
        }

        // MLP
        CommonWeightLoader.applyLinearWeights(
            to: block.mlp0, prefix: "\(prefix).mlp.0", from: weights
        )
        CommonWeightLoader.applyLinearWeights(
            to: block.mlp2, prefix: "\(prefix).mlp.2", from: weights
        )
        CommonWeightLoader.applyLayerNormWeights(
            to: block.mlpLn, prefix: "\(prefix).mlp_ln", from: weights
        )
    }

    // MARK: - Pretrained Model Loading

    /// Download and load a pretrained Whisper model from HuggingFace.
    ///
    /// - Parameters:
    ///   - modelId: HuggingFace model ID (e.g. "openai/whisper-large-v3-turbo")
    ///   - progressHandler: Optional callback with (progress 0-1, status message)
    /// - Returns: Fully loaded WhisperModel ready for transcription
    static func fromPretrained(
        modelId: String,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> WhisperModel {
        progressHandler?(0.0, "Downloading model...")

        // 1. Get cache directory for model weights
        let cacheDir = try HuggingFaceDownloader.getCacheDirectory(for: modelId)

        // 2. Download model weights (0-70% progress)
        try await HuggingFaceDownloader.downloadWeights(
            modelId: modelId,
            to: cacheDir,
            progressHandler: { p in
                progressHandler?(p * 0.7, "Downloading weights...")
            }
        )

        // 3. Download tokenizer from openai/whisper-large-v3-turbo (70-80%)
        let tokDir = try HuggingFaceDownloader.getCacheDirectory(
            for: "openai/whisper-large-v3-turbo"
        )
        try await HuggingFaceDownloader.downloadWeights(
            modelId: "openai/whisper-large-v3-turbo",
            to: tokDir,
            additionalFiles: ["vocab.json", "merges.txt", "tokenizer_config.json"],
            progressHandler: { p in
                progressHandler?(0.7 + p * 0.1, "Downloading tokenizer...")
            }
        )

        progressHandler?(0.80, "Loading config...")

        // 4. Load config from cache directory
        let config = try WhisperConfig.load(from: cacheDir)

        progressHandler?(0.82, "Initializing model...")

        // 5. Create model and load tokenizer
        let model = WhisperModel(config: config)

        let vocabPath = tokDir.appendingPathComponent("vocab.json")
        if FileManager.default.fileExists(atPath: vocabPath.path) {
            let tokenizer = Qwen3Tokenizer()
            try tokenizer.load(from: vocabPath)
            model.tokenizer = tokenizer
        }

        progressHandler?(0.85, "Loading weights...")

        // 6. Load weights (85-100%)
        try model.loadWeights(from: cacheDir)

        progressHandler?(1.0, "Ready")

        return model
    }
}
