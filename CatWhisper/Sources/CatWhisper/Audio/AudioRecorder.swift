import AVFoundation

/// Records audio from the microphone using AVAudioEngine
/// Outputs 16kHz mono Float32 samples suitable for ASR
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private let buffer = AudioBuffer()
    private var isRecording = false

    private static let targetSampleRate: Double = 16_000

    enum RecorderError: LocalizedError {
        case alreadyRecording
        case engineStartFailed(Error)

        var errorDescription: String? {
            switch self {
            case .alreadyRecording:
                return "已在錄音中"
            case .engineStartFailed(let error):
                return "音訊引擎啟動失敗：\(error.localizedDescription)"
            }
        }
    }

    /// Start recording from the default input device
    func startRecording() throws {
        guard !isRecording else { throw RecorderError.alreadyRecording }

        buffer.reset()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create target format: 16kHz mono Float32
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw RecorderError.engineStartFailed(
                NSError(domain: "AudioRecorder", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "無法建立目標音訊格式"])
            )
        }

        // Install tap with converter for resampling
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] pcmBuffer, _ in
            guard let self, let converter else { return }

            // Calculate output frame count based on sample rate ratio
            let ratio = Self.targetSampleRate / inputFormat.sampleRate
            let outputFrameCount = AVAudioFrameCount(Double(pcmBuffer.frameLength) * ratio)

            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: outputFrameCount
            ) else { return }

            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return pcmBuffer
            }

            guard status != .error, error == nil else { return }

            // Extract Float32 samples
            if let channelData = outputBuffer.floatChannelData {
                let samples = Array(UnsafeBufferPointer(
                    start: channelData[0],
                    count: Int(outputBuffer.frameLength)
                ))
                self.buffer.append(samples)
            }
        }

        do {
            try engine.start()
            isRecording = true
        } catch {
            inputNode.removeTap(onBus: 0)
            throw RecorderError.engineStartFailed(error)
        }
    }

    /// Stop recording and return all accumulated samples
    func stopRecording() -> [Float] {
        guard isRecording else { return [] }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false

        return buffer.consume()
    }
}
