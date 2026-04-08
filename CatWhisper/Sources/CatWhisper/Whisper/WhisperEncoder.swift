import Foundation
import MLX
import MLXNN
import MLXFast

// MARK: - WhisperMultiHeadAttention

/// Multi-head attention used by both encoder and decoder in Whisper.
///
/// Whisper uses symmetric scaling: both Q and K are multiplied by headDim^(-0.25),
/// then scale=1.0 is passed to SDPA, which is mathematically equivalent to the
/// standard 1/sqrt(headDim) scaling but matches the original implementation.
class WhisperMultiHeadAttention: Module {

    @ModuleInfo var query: Linear
    @ModuleInfo var key: Linear
    @ModuleInfo var value: Linear
    @ModuleInfo var out: Linear

    let nHead: Int
    let headDim: Int
    let scale: Float

    init(nState: Int, nHead: Int) {
        self.nHead = nHead
        self.headDim = nState / nHead
        // Symmetric scaling: headDim^(-0.25)
        self.scale = pow(Float(nState / nHead), -0.25)

        self._query.wrappedValue = Linear(nState, nState)
        self._key.wrappedValue = Linear(nState, nState, bias: false)
        self._value.wrappedValue = Linear(nState, nState)
        self._out.wrappedValue = Linear(nState, nState)

        super.init()
    }

    /// Run multi-head attention.
    ///
    /// - Parameters:
    ///   - x: query source, shape [batch, seqLen, nState]
    ///   - xa: optional cross-attention source (key/value come from here instead of x)
    ///   - mask: optional attention mask
    ///   - cache: optional KV cache tuple (cachedK, cachedV) from a previous step
    /// - Returns: (output, newCache) where newCache is (K, V) for incremental decoding
    func callAsFunction(
        _ x: MLXArray,
        xa: MLXArray? = nil,
        mask: MLXArray? = nil,
        cache: (MLXArray, MLXArray)? = nil
    ) -> (MLXArray, (MLXArray, MLXArray)) {
        let source = xa ?? x
        let batch = x.dim(0)
        let seqLen = x.dim(1)

        // Project Q, K, V
        var q = query(x)
        var k = key(source)
        var v = value(source)

        // Reshape to [batch, seqLen, nHead, headDim] then transpose to [batch, nHead, seqLen, headDim]
        q = q.reshaped(batch, seqLen, nHead, headDim).transposed(0, 2, 1, 3)
        let sourceLen = source.dim(1)
        k = k.reshaped(batch, sourceLen, nHead, headDim).transposed(0, 2, 1, 3)
        v = v.reshaped(batch, sourceLen, nHead, headDim).transposed(0, 2, 1, 3)

        // Apply KV cache
        if let cache {
            k = concatenated([cache.0, k], axis: 2)
            v = concatenated([cache.1, v], axis: 2)
        }

        let newCache = (k, v)

        // Symmetric scaling: multiply both Q and K by headDim^(-0.25)
        q = q * scale
        k = k * scale

        // Scaled dot-product attention with scale=1.0 (scaling already applied)
        let output = MLXFast.scaledDotProductAttention(
            queries: q, keys: k, values: v, scale: 1.0, mask: mask
        )

        // output shape: [batch, nHead, seqLen, headDim]
        // Transpose back to [batch, seqLen, nHead, headDim] and reshape to [batch, seqLen, nState]
        let merged = output.transposed(0, 2, 1, 3).reshaped(batch, seqLen, nHead * headDim)

        return (out(merged), newCache)
    }
}

// MARK: - WhisperResidualAttentionBlock

/// A single transformer block used in both the encoder and decoder.
///
/// Uses pre-norm residual connections:
///   x = x + selfAttn(layerNorm(x))
///   x = x + crossAttn(layerNorm(x))  // decoder only
///   x = x + mlp(layerNorm(x))
class WhisperResidualAttentionBlock: Module {

    // Self-attention
    @ModuleInfo var attn: WhisperMultiHeadAttention
    @ModuleInfo(key: "attn_ln") var attnLn: LayerNorm

    // Cross-attention (decoder only, nil for encoder)
    @ModuleInfo(key: "cross_attn") var crossAttn: WhisperMultiHeadAttention?
    @ModuleInfo(key: "cross_attn_ln") var crossAttnLn: LayerNorm?

    // MLP
    @ModuleInfo(key: "mlp.0") var mlp0: Linear
    @ModuleInfo(key: "mlp.2") var mlp2: Linear
    @ModuleInfo(key: "mlp_ln") var mlpLn: LayerNorm

    init(nState: Int, nHead: Int, crossAttention: Bool = false) {
        self._attn.wrappedValue = WhisperMultiHeadAttention(nState: nState, nHead: nHead)
        self._attnLn.wrappedValue = LayerNorm(dimensions: nState)

        if crossAttention {
            self._crossAttn.wrappedValue = WhisperMultiHeadAttention(nState: nState, nHead: nHead)
            self._crossAttnLn.wrappedValue = LayerNorm(dimensions: nState)
        } else {
            self._crossAttn.wrappedValue = nil
            self._crossAttnLn.wrappedValue = nil
        }

        self._mlp0.wrappedValue = Linear(nState, nState * 4)
        self._mlp2.wrappedValue = Linear(nState * 4, nState)
        self._mlpLn.wrappedValue = LayerNorm(dimensions: nState)

        super.init()
    }

    /// Run the residual attention block.
    ///
    /// - Parameters:
    ///   - x: input tensor [batch, seqLen, nState]
    ///   - xa: optional cross-attention source (encoder output for decoder blocks)
    ///   - mask: optional causal mask for self-attention
    ///   - selfAttnCache: optional KV cache for self-attention
    ///   - crossAttnCache: optional KV cache for cross-attention
    /// - Returns: (output, selfAttnCache, crossAttnCache?)
    func callAsFunction(
        _ x: MLXArray,
        xa: MLXArray? = nil,
        mask: MLXArray? = nil,
        selfAttnCache: (MLXArray, MLXArray)? = nil,
        crossAttnCache: (MLXArray, MLXArray)? = nil
    ) -> (MLXArray, (MLXArray, MLXArray), (MLXArray, MLXArray)?) {
        // Self-attention with pre-norm residual
        let (selfAttnOut, newSelfAttnCache) = attn(attnLn(x), cache: selfAttnCache)
        var out = x + selfAttnOut

        // Cross-attention with pre-norm residual (decoder only)
        var newCrossAttnCache: (MLXArray, MLXArray)? = nil
        if let crossAttn, let crossAttnLn {
            let (crossAttnOut, cache) = crossAttn(
                crossAttnLn(out), xa: xa, cache: crossAttnCache
            )
            out = out + crossAttnOut
            newCrossAttnCache = cache
        }

        // MLP with pre-norm residual
        let mlpOut = mlp2(gelu(mlp0(mlpLn(out))))
        out = out + mlpOut

        return (out, newSelfAttnCache, newCrossAttnCache)
    }
}

// MARK: - WhisperAudioEncoder

/// The Whisper audio encoder.
///
/// Converts a mel spectrogram [batch, nMels, 3000] into encoder hidden states
/// [batch, 1500, nAudioState] via:
///   1. Two 1D convolutions (with GELU) that halve the time dimension
///   2. Sinusoidal positional embedding addition
///   3. A stack of transformer blocks (self-attention only)
///   4. Final layer normalization
class WhisperAudioEncoder: Module {

    @ModuleInfo var conv1: Conv1d
    @ModuleInfo var conv2: Conv1d
    @ModuleInfo var blocks: [WhisperResidualAttentionBlock]
    @ModuleInfo(key: "ln_post") var lnPost: LayerNorm

    /// Positional embedding, shape [nAudioCtx, nAudioState].
    /// Initialized as zeros and replaced by loaded weights.
    var positionalEmbedding: MLXArray

    init(_ config: WhisperConfig) {
        let nState = config.nAudioState
        let nHead = config.nAudioHead
        let nLayer = config.nAudioLayer

        self._conv1.wrappedValue = Conv1d(
            inputChannels: config.nMels,
            outputChannels: nState,
            kernelSize: 3,
            padding: 1
        )
        self._conv2.wrappedValue = Conv1d(
            inputChannels: nState,
            outputChannels: nState,
            kernelSize: 3,
            stride: 2,
            padding: 1
        )

        self.positionalEmbedding = MLXArray.zeros([config.nAudioCtx, nState])

        self._blocks.wrappedValue = (0 ..< nLayer).map { _ in
            WhisperResidualAttentionBlock(nState: nState, nHead: nHead, crossAttention: false)
        }

        self._lnPost.wrappedValue = LayerNorm(dimensions: nState)

        super.init()
    }

    /// Encode a mel spectrogram into hidden states.
    ///
    /// - Parameter mel: mel spectrogram of shape [batch, nMels, 3000]
    /// - Returns: encoder output of shape [batch, 1500, nAudioState]
    func callAsFunction(_ mel: MLXArray) -> MLXArray {
        // Input: [batch, nMels, 3000]
        // Conv1d expects NLC layout, so transpose to [batch, 3000, nMels]
        var x = mel.transposed(0, 2, 1)

        // Conv frontend: [batch, 3000, nMels] -> [batch, 3000, nState] -> [batch, 1500, nState]
        x = gelu(conv1(x))
        x = gelu(conv2(x))

        // Add positional embedding
        x = x + positionalEmbedding

        // Transformer blocks (self-attention only, no cross-attention)
        for block in blocks {
            let (out, _, _) = block(x)
            x = out
        }

        // Final layer norm
        x = lnPost(x)

        return x
    }
}
