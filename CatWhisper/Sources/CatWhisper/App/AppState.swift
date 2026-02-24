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
    private let textInjector = TextInjector()
    private let fnKeyMonitor = FnKeyMonitor()
    private let notchOverlay = NotchOverlay()
    private var recordingStartTime: Date?

    var isRecording: Bool { state == .recording }
    var isTranscribing: Bool { state == .transcribing }
    var isLoading: Bool { state == .loading }

    /// Minimum hold duration (seconds) to avoid accidental fn taps
    private static let minimumRecordingDuration: TimeInterval = 0.3

    // MARK: - Setup

    func setupFnKeyMonitor() {
        fnKeyMonitor.onFnDown = { [weak self] in
            self?.startRecording()
        }
        fnKeyMonitor.onFnUp = { [weak self] in
            self?.stopRecordingAndTranscribe()
        }
        fnKeyMonitor.start()
    }

    // MARK: - Model Loading

    func loadModelIfNeeded() async {
        guard !modelLoaded else { return }
        state = .loading
        do {
            try await transcriptionEngine.loadModel(
                modelId: selectedModelId
            ) { [weak self] progress, fileName in
                Task { @MainActor in
                    self?.modelLoadProgress = progress
                    self?.modelLoadFileName = fileName
                }
            }
            modelLoaded = true
            state = .idle
        } catch {
            state = .error("模型載入失敗：\(error.localizedDescription)")
        }
    }

    // MARK: - Recording (hold-to-record)

    func startRecording() {
        guard state == .idle else { return }

        guard PermissionManager.shared.microphoneAuthorized else {
            Task {
                let granted = await PermissionManager.shared.requestMicrophoneAccess()
                if !granted {
                    state = .error("需要麥克風權限才能錄音")
                }
            }
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

    func stopRecordingAndTranscribe() {
        guard state == .recording else { return }

        let samples = audioRecorder.stopRecording()
        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())

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
                let text = try await transcriptionEngine.transcribe(samples: samples)
                lastTranscription = text

                let entry = TranscriptionEntry(text: text, timestamp: Date())
                transcriptionHistory.insert(entry, at: 0)
                if transcriptionHistory.count > 50 {
                    transcriptionHistory = Array(transcriptionHistory.prefix(50))
                }

                // Show result in notch overlay
                notchOverlay.showResult(text)

                // Inject text directly into focused window
                if AccessibilityChecker.isTrusted {
                    textInjector.injectText(text)
                } else {
                    // Fallback: copy to clipboard so user can paste manually
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    AccessibilityChecker.checkAndPrompt()
                }

                state = .idle
            } catch {
                state = .error("辨識失敗：\(error.localizedDescription)")
                notchOverlay.hide()
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
