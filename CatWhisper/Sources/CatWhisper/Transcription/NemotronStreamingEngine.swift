import Foundation
import NemotronStreamingASR

/// Wraps NemotronStreamingASRModel for live dictation: feed mic samples
/// continuously, get back the full running hypothesis (committed segments
/// plus the current partial).
actor NemotronStreamingEngine {

    static let modelId = "aufklarer/Nemotron-3.5-ASR-Streaming-0.6B-CoreML-INT8"

    enum EngineError: LocalizedError {
        case modelNotLoaded

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded: return "即時聽寫模型尚未載入"
            }
        }
    }

    private var model: NemotronStreamingASRModel?
    private var session: StreamingSession?

    private var pending: [Float] = []
    private var committed = ""
    private var currentPartial = ""

    /// ~0.2s of 16kHz audio per push keeps latency low without thrashing CoreML
    private static let pushThreshold = 3200

    var isLoaded: Bool { model != nil }

    // MARK: - Lifecycle

    func loadModel(progressHandler: ((Double, String) -> Void)? = nil) async throws {
        guard model == nil else { return }
        let loaded = try await NemotronStreamingASRModel.fromPretrained(
            modelId: Self.modelId,
            progressHandler: progressHandler
        )
        try loaded.warmUp()
        model = loaded
    }

    func startSession(language: String = "zh-TW") throws {
        guard let model else { throw EngineError.modelNotLoaded }
        session = try model.createSession(language: language)
        pending = []
        committed = ""
        currentPartial = ""
    }

    // MARK: - Streaming

    /// Feed mic samples. Returns the updated full hypothesis when enough
    /// audio accumulated to run inference, nil otherwise.
    func feed(_ samples: [Float]) -> String? {
        guard let session else { return nil }
        pending.append(contentsOf: samples)
        guard pending.count >= Self.pushThreshold else { return nil }

        let chunk = pending
        pending = []
        guard let partials = try? session.pushAudio(chunk) else { return nil }
        apply(partials)
        return hypothesis
    }

    /// Flush remaining audio, finalize the session, and return the final text.
    func finish() -> String {
        defer {
            session = nil
            pending = []
        }
        guard let session else { return hypothesis }
        if !pending.isEmpty, let partials = try? session.pushAudio(pending) {
            apply(partials)
        }
        if let finals = try? session.finalize() {
            apply(finals)
        }
        return hypothesis
    }

    /// One-shot transcription of a complete recording (fallback path when
    /// live injection isn't possible, e.g. no accessibility permission).
    func transcribeBatch(samples: [Float], language: String = "zh-TW") throws -> String {
        try startSession(language: language)
        pending = samples
        return finish()
    }

    // MARK: - Hypothesis assembly

    private var hypothesis: String { committed + currentPartial }

    private func apply(_ partials: [NemotronStreamingASRModel.PartialTranscript]) {
        for partial in partials {
            if partial.isFinal {
                committed += partial.text
                currentPartial = ""
            } else {
                currentPartial = partial.text
            }
        }
    }
}
