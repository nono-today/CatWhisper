import Foundation
import MLX
import MLXNN
import MLXFast

// MARK: - WhisperTextDecoder

/// The Whisper text decoder.
///
/// Autoregressively generates token sequences conditioned on encoder output
/// via cross-attention. Uses learned positional embeddings and tied output
/// weights (shares the token embedding matrix for the final logit projection).
///
/// Architecture:
///   1. Token embedding + learned positional embedding
///   2. A stack of transformer blocks with self-attention AND cross-attention
///   3. Final layer normalization
///   4. Logit projection via tied embedding weights
class WhisperTextDecoder: Module {

    @ModuleInfo(key: "token_embedding") var tokenEmbedding: Embedding
    @ModuleInfo var blocks: [WhisperResidualAttentionBlock]
    @ModuleInfo var ln: LayerNorm

    /// Learned positional embedding, shape [nTextCtx, nTextState].
    /// Initialized as zeros and replaced by loaded weights.
    var positionalEmbedding: MLXArray

    init(_ config: WhisperConfig) {
        let nState = config.nTextState
        let nHead = config.nTextHead
        let nLayer = config.nTextLayer

        self._tokenEmbedding.wrappedValue = Embedding(
            embeddingCount: config.nVocab,
            dimensions: nState
        )

        self.positionalEmbedding = MLXArray.zeros([config.nTextCtx, nState])

        self._blocks.wrappedValue = (0 ..< nLayer).map { _ in
            WhisperResidualAttentionBlock(
                nState: nState, nHead: nHead, crossAttention: true
            )
        }

        self._ln.wrappedValue = LayerNorm(dimensions: nState)

        super.init()
    }

    /// Decode token IDs into logits, conditioned on encoder audio features.
    ///
    /// - Parameters:
    ///   - tokenIds: input token IDs, shape [batch, seqLen]
    ///   - audioFeatures: encoder output, shape [batch, 1500, nState]
    ///   - selfAttnCaches: optional per-layer self-attention KV caches from previous steps
    ///   - crossAttnCaches: optional per-layer cross-attention KV caches (reusable once computed)
    /// - Returns: A tuple of (logits, newSelfAttnCaches, newCrossAttnCaches) where:
    ///   - logits: shape [batch, seqLen, nVocab]
    ///   - newSelfAttnCaches: updated self-attention KV caches for each layer
    ///   - newCrossAttnCaches: updated cross-attention KV caches for each layer (nil entries for layers without cross-attn)
    func callAsFunction(
        _ tokenIds: MLXArray,
        audioFeatures: MLXArray,
        selfAttnCaches: [(MLXArray, MLXArray)]?,
        crossAttnCaches: [(MLXArray, MLXArray)?]?
    ) -> (MLXArray, [(MLXArray, MLXArray)], [(MLXArray, MLXArray)?]) {
        let seqLen = tokenIds.dim(1)

        // Compute offset from cached keys (number of previously decoded tokens)
        let offset = selfAttnCaches?.first?.0.dim(2) ?? 0

        // Token embedding + positional embedding slice
        var x = tokenEmbedding(tokenIds)
        x = x + positionalEmbedding[offset ..< (offset + seqLen)]

        // Causal mask for self-attention (only needed when processing multiple tokens)
        let mask: MLXArray?
        if seqLen > 1 {
            let totalLen = seqLen + offset
            let rows = (MLXArray(0 ..< Int32(seqLen)) + Int32(offset))
                .expandedDimensions(axis: 1)
            let cols = MLXArray(0 ..< Int32(totalLen))
                .expandedDimensions(axis: 0)
            mask = MLX.where(cols .> rows, MLXArray(Float(-1e9)), MLXArray(Float(0)))
                .expandedDimensions(axes: [0, 1])
        } else {
            mask = nil
        }

        // Run through transformer blocks, collecting updated caches
        var newSelfCaches: [(MLXArray, MLXArray)] = []
        var newCrossCaches: [(MLXArray, MLXArray)?] = []

        for (i, block) in blocks.enumerated() {
            let selfCache = selfAttnCaches?[i]
            let crossCache = crossAttnCaches?[i]

            let (out, selfCacheOut, crossCacheOut) = block(
                x,
                xa: audioFeatures,
                mask: mask,
                selfAttnCache: selfCache,
                crossAttnCache: crossCache
            )
            x = out
            newSelfCaches.append(selfCacheOut)
            newCrossCaches.append(crossCacheOut)
        }

        // Final layer normalization
        x = ln(x)

        // Logit projection via tied embedding weights
        let logits = x.matmul(tokenEmbedding.weight.transposed())

        return (logits, newSelfCaches, newCrossCaches)
    }
}
