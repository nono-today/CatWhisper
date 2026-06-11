import SwiftUI

/// Application state machine for CatWhisper
/// Hold fn → recording, release fn → transcribe → inject text
@MainActor
final class AppState: ObservableObject {

    enum State: Equatable {
        case idle
        case loading        // Model is downloading/loading
        case recording
        case transcribing
        case error(String)
    }

    @Published var state: State = .idle
    @Published var lastTranscription: String = ""
    @Published var transcriptionHistory: [TranscriptionEntry] = []
    @Published var modelLoaded: Bool = false
    @Published var modelLoadProgress: Double = 0
    @Published var modelLoadFileName: String = ""

    @AppStorage("selectedModelId") var selectedModelId = "mlx-community/Qwen3-ASR-0.6B-4bit"

    struct TranscriptionEntry: Identifiable {
        let id = UUID()
        let text: String
        let timestamp: Date
    }

    private let audioRecorder = AudioRecorder()
    private let transcriptionEngine = TranscriptionEngine()
    private let streamingEngine = NemotronStreamingEngine()
    private let textInjector = TextInjector()
    private let liveTextInjector = LiveTextInjector()
    private let fnKeyMonitor = FnKeyMonitor()
    private let notchOverlay = NotchOverlay()
    private var recordingStartTime: Date?
    private var fnMonitorReady = false
    private var accessibilityPromptShown = false
    private var fnHeld = false
    private var liveSessionActive = false

    /// Streaming (live dictation) models bypass the batch transcription path
    private var isStreamingModelSelected: Bool {
        selectedModelId.lowercased().contains("nemotron")
    }

    var isRecording: Bool { state == .recording }
    var isTranscribing: Bool { state == .transcribing }
    var isLoading: Bool { state == .loading }

    /// Minimum hold duration (seconds) to avoid accidental fn taps
    private static let minimumRecordingDuration: TimeInterval = 0.3

    // MARK: - Bootstrap (called once at app launch)

    func bootstrap() {
        setupFnKeyMonitor()
        Task { await loadModelIfNeeded() }
    }

    private func setupFnKeyMonitor() {
        guard !fnMonitorReady else { return }
        fnKeyMonitor.onFnDown = { [weak self] in
            self?.fnHeld = true
            self?.startRecording()
        }
        fnKeyMonitor.onFnUp = { [weak self] in
            self?.fnHeld = false
            self?.stopRecordingAndTranscribe()
        }
        fnKeyMonitor.start()
        fnMonitorReady = true
    }

    // MARK: - Model Loading

    func loadModelIfNeeded() async {
        guard !modelLoaded else { return }
        await loadModel()
    }

    /// Force reload the model (e.g. after changing model in settings)
    func reloadModel() async {
        modelLoaded = false
        await loadModel()
    }

    /// Guards against concurrent loads — e.g. bootstrap load still running
    /// while the user presses fn, which would kick off a duplicate download.
    private var isLoadingModel = false

    private func loadModel() async {
        guard !isLoadingModel else { return }
        isLoadingModel = true
        defer { isLoadingModel = false }

        state = .loading
        modelLoadProgress = 0
        modelLoadFileName = ""
        do {
            let progress: (Double, String) -> Void = { [weak self] progress, fileName in
                Task { @MainActor in
                    self?.modelLoadProgress = progress
                    self?.modelLoadFileName = fileName
                }
            }
            if isStreamingModelSelected {
                try await streamingEngine.loadModel(progressHandler: progress)
            } else {
                try await transcriptionEngine.loadModel(
                    modelId: selectedModelId, progressHandler: progress
                )
            }
            modelLoaded = true
            state = .idle
        } catch {
            state = .error("模型載入失敗：\(error.localizedDescription)")
        }
    }

    // MARK: - Recording (hold-to-record)

    func startRecording() {
        switch state {
        case .idle, .error: break   // allow recording
        default: return             // busy (loading/recording/transcribing)
        }

        guard modelLoaded else {
            state = .error("模型尚未載入，請稍候")
            Task { await loadModelIfNeeded() }
            return
        }

        guard PermissionManager.shared.microphoneAuthorized else {
            Task {
                let granted = await PermissionManager.shared.requestMicrophoneAccess()
                if !granted {
                    state = .error("需要麥克風權限才能錄音")
                }
            }
            return
        }

        // Live dictation: stream partials straight into the focused window.
        // Without accessibility permission, fall through to the batch path
        // (recording still works; result lands on the clipboard).
        if isStreamingModelSelected, PermissionManager.shared.accessibilityAuthorized {
            startLiveDictation()
            return
        }

        do {
            try audioRecorder.startRecording()
            recordingStartTime = Date()
            state = .recording
            notchOverlay.showRecording()
        } catch {
            state = .error("錄音啟動失敗：\(error.localizedDescription)")
        }
    }

    private func startLiveDictation() {
        Task {
            do {
                try await streamingEngine.startSession()
                // fn may already be released by the time the session is ready
                guard fnHeld, state == .idle || isErrorState else {
                    _ = await streamingEngine.finish()
                    return
                }
                liveTextInjector.reset()
                audioRecorder.onSamples = { [weak self] samples in
                    guard let self else { return }
                    Task {
                        guard let hypothesis = await self.streamingEngine.feed(samples) else { return }
                        let converted = ChineseConverter.toTraditional(hypothesis)
                        await MainActor.run {
                            guard self.state == .recording else { return }
                            self.liveTextInjector.update(hypothesis: converted)
                        }
                    }
                }
                try audioRecorder.startRecording()
                liveSessionActive = true
                recordingStartTime = Date()
                state = .recording
                notchOverlay.showRecording()
            } catch {
                audioRecorder.onSamples = nil
                state = .error("即時聽寫啟動失敗：\(error.localizedDescription)")
            }
        }
    }

    private var isErrorState: Bool {
        if case .error = state { return true }
        return false
    }

    func stopRecordingAndTranscribe() {
        guard state == .recording else { return }

        let samples = audioRecorder.stopRecording()
        audioRecorder.onSamples = nil
        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())

        // Live dictation: text is already in the window — finalize and record
        // history. No minimum-duration discard (partials may be injected).
        if liveSessionActive {
            liveSessionActive = false
            state = .transcribing
            Task {
                let raw = await streamingEngine.finish()
                let text = ChineseConverter.toTraditional(raw)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                liveTextInjector.finish(finalText: text)
                if !text.isEmpty {
                    lastTranscription = text
                    transcriptionHistory.insert(
                        TranscriptionEntry(text: text, timestamp: Date()), at: 0)
                    if transcriptionHistory.count > 50 {
                        transcriptionHistory = Array(transcriptionHistory.prefix(50))
                    }
                }
                state = .idle
                notchOverlay.hide()
            }
            return
        }

        // Discard very short recordings (accidental fn taps)
        guard duration >= Self.minimumRecordingDuration, !samples.isEmpty else {
            state = .idle
            notchOverlay.hide()
            return
        }

        state = .transcribing
        notchOverlay.showTranscribing()

        Task {
            do {
                let text: String
                if isStreamingModelSelected {
                    // Batch fallback for the streaming model (no accessibility)
                    text = ChineseConverter.toTraditional(
                        try await streamingEngine.transcribeBatch(samples: samples)
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    text = try await transcriptionEngine.transcribe(samples: samples)
                }

                // Empty result = no speech detected → silently return to idle
                guard !text.isEmpty else {
                    state = .idle
                    notchOverlay.hide()
                    return
                }

                lastTranscription = text

                let entry = TranscriptionEntry(text: text, timestamp: Date())
                transcriptionHistory.insert(entry, at: 0)
                if transcriptionHistory.count > 50 {
                    transcriptionHistory = Array(transcriptionHistory.prefix(50))
                }

                // Show result in notch overlay
                notchOverlay.showResult(text)

                // Inject text directly into focused window, or fallback to clipboard
                if PermissionManager.shared.accessibilityAuthorized {
                    textInjector.injectText(text)
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    // Guide the user to grant access (once per launch) — also
                    // registers this build's signature in the Accessibility list
                    if !accessibilityPromptShown {
                        accessibilityPromptShown = true
                        AccessibilityChecker.checkAndPrompt()
                    }
                }

                state = .idle
            } catch {
                // Real errors (model not loaded, etc.) — show briefly then auto-clear
                state = .error("辨識失敗：\(error.localizedDescription)")
                notchOverlay.hide()
                // Auto-clear error after 3 seconds so user can retry
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    if case .error = state { state = .idle }
                }
            }
        }
    }

    // MARK: - Utility

    func clearError() {
        if case .error = state {
            state = .idle
        }
    }

    func copyLastTranscription() {
        guard !lastTranscription.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastTranscription, forType: .string)
    }
}
