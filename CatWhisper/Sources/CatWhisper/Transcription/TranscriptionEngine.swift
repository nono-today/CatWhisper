import Foundation
import Qwen3ASR
import Qwen3Common

/// Actor wrapping Qwen3ASRModel for thread-safe model loading and transcription
/// Always outputs Traditional Chinese (簡體→繁體 conversion applied)
actor TranscriptionEngine {

    private var qwenModel: Qwen3ASRModel?
    private var whisperModel: WhisperModel?

    enum ModelFamily {
        case qwen3
        case whisper

        static func detect(from modelId: String) -> ModelFamily {
            if modelId.lowercased().contains("whisper") { return .whisper }
            return .qwen3
        }
    }

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
        // Unload previous models to free memory before loading new one
        qwenModel = nil
        whisperModel = nil

        switch ModelFamily.detect(from: modelId) {
        case .qwen3:
            qwenModel = try await Qwen3ASRModel.fromPretrained(
                modelId: modelId,
                progressHandler: progressHandler
            )
        case .whisper:
            whisperModel = try await WhisperModel.fromPretrained(
                modelId: modelId,
                progressHandler: progressHandler
            )
        }
    }

    /// Whether the model is loaded and ready
    var isReady: Bool {
        qwenModel != nil || whisperModel != nil
    }

    /// Transcribe audio samples to text (output is always Traditional Chinese)
    func transcribe(
        samples: [Float],
        sampleRate: Int = 16_000
    ) throws -> String {
        let text: String

        if let qwenModel {
            text = qwenModel.transcribe(
                audio: samples,
                sampleRate: sampleRate
            )
        } else if let whisperModel {
            text = whisperModel.transcribe(
                audio: samples,
                sampleRate: sampleRate
            )
        } else {
            throw EngineError.modelNotLoaded
        }

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
