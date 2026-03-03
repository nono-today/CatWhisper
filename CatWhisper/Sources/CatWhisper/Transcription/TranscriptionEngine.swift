import Foundation
import Qwen3ASR

/// Actor wrapping Qwen3ASRModel for thread-safe model loading and transcription
/// Always outputs Traditional Chinese (簡體→繁體 conversion applied)
actor TranscriptionEngine {

    private var model: Qwen3ASRModel?

    enum EngineError: LocalizedError {
        case modelNotLoaded
        case transcriptionFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "語音辨識模型尚未載入"
            case .transcriptionFailed(let reason):
                return "語音辨識失敗：\(reason)"
            }
        }
    }

    /// Load the ASR model, downloading on first use
    func loadModel(
        modelId: String = "mlx-community/Qwen3-ASR-0.6B-4bit",
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws {
        model = try await Qwen3ASRModel.fromPretrained(
            modelId: modelId,
            progressHandler: progressHandler
        )
    }

    /// Whether the model is loaded and ready
    var isReady: Bool {
        model != nil
    }

    /// Transcribe audio samples to text (output is always Traditional Chinese)
    func transcribe(
        samples: [Float],
        sampleRate: Int = 16_000
    ) throws -> String {
        guard let model else {
            throw EngineError.modelNotLoaded
        }

        let text = model.transcribe(
            audio: samples,
            sampleRate: sampleRate
        )

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ""  // No speech detected — let caller handle silently
        }

        return toTraditionalChinese(trimmed)
    }

    /// Convert Simplified Chinese → Traditional Chinese
    /// Non-Chinese text passes through unchanged
    private func toTraditionalChinese(_ text: String) -> String {
        let mutable = NSMutableString(string: text)
        CFStringTransform(mutable, nil, "Simplified-Traditional" as CFString, false)
        return mutable as String
    }
}
