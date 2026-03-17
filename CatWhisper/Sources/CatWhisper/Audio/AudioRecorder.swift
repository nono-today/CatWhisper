import AVFoundation

/// Records audio from the microphone using AVAudioEngine
/// Outputs 16kHz mono Float32 samples suitable for ASR
/// Automatically handles audio device switching mid-recording
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private let buffer = AudioBuffer()
    private var _isRecording = false
    private let stateLock = NSLock()

    private var isRecording: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _isRecording }
        set { stateLock.lock(); defer { stateLock.unlock() }; _isRecording = newValue }
    }

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

    init() {
        // When the audio device changes (e.g. switching to AirPods),
        // AVAudioEngine stops itself and fires this notification.
        // We reconfigure and restart to continue recording seamlessly.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Device Change Handling

    @objc private func handleConfigurationChange(_ notification: Notification) {
        guard isRecording else { return }

        // Engine already stopped itself. Clean up old tap and restart.
        engine.inputNode.removeTap(onBus: 0)

        do {
            try configureAndStart()
        } catch {
            isRecording = false
        }
    }

    // MARK: - Recording

    func startRecording() throws {
        guard !isRecording else { throw RecorderError.alreadyRecording }
        buffer.reset()
        try configureAndStart()
    }

    func stopRecording() -> [Float] {
        guard isRecording else { return [] }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false

        return buffer.consume()
    }

    // MARK: - Engine Configuration

    /// Configure the engine for the current input device and start it.
    /// Called on initial start and after device switches.
    private func configureAndStart() throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Guard against no input device (e.g. all devices disconnected)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.engineStartFailed(
                NSError(domain: "AudioRecorder", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "無法取得音訊輸入裝置"])
            )
        }

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

        // Create converter matching the *current* device's format
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] pcmBuffer, _ in
            guard let self, let converter else { return }

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
}
