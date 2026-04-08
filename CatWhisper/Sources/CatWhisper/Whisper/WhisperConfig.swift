import Foundation

/// Whisper model configuration, parsed from config.json
struct WhisperConfig: Codable {
    let nMels: Int
    let nAudioCtx: Int
    let nAudioState: Int
    let nAudioHead: Int
    let nAudioLayer: Int
    let nVocab: Int
    let nTextCtx: Int
    let nTextState: Int
    let nTextHead: Int
    let nTextLayer: Int

    enum CodingKeys: String, CodingKey {
        case nMels = "n_mels"
        case nAudioCtx = "n_audio_ctx"
        case nAudioState = "n_audio_state"
        case nAudioHead = "n_audio_head"
        case nAudioLayer = "n_audio_layer"
        case nVocab = "n_vocab"
        case nTextCtx = "n_text_ctx"
        case nTextState = "n_text_state"
        case nTextHead = "n_text_head"
        case nTextLayer = "n_text_layer"
    }

    var nAudioHeadDim: Int { nAudioState / nAudioHead }
    var nTextHeadDim: Int { nTextState / nTextHead }
    var isMultilingual: Bool { nVocab >= 51865 }

    static func load(from directory: URL) throws -> WhisperConfig {
        let configURL = directory.appendingPathComponent("config.json")
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(WhisperConfig.self, from: data)
    }
}
