import SwiftUI

/// Main popover content shown when clicking the menu bar icon
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status header
            statusSection

            Divider()

            // Fn key hint
            fnKeyHint

            // Last transcription
            if !appState.lastTranscription.isEmpty {
                Divider()
                lastTranscriptionSection
            }

            // History
            if !appState.transcriptionHistory.isEmpty {
                Divider()
                historySection
            }

            Divider()

            // Footer
            footerSection
        }
        .padding(12)
        .frame(width: 320)
    }

    // MARK: - Sections

    private var statusSection: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, isActive: appState.isRecording)
            Text(statusText)
                .font(.headline)
            Spacer()

            if !appState.modelLoaded {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var fnKeyHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("按住 fn 鍵錄音")
                    .font(.callout.bold())
                Text("放開後自動辨識並輸入文字")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var lastTranscriptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("最新辨識結果")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { appState.copyLastTranscription() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("複製到剪貼簿")
            }

            Text(appState.lastTranscription)
                .font(.body)
                .textSelection(.enabled)
                .lineLimit(5)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("歷史紀錄")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(appState.transcriptionHistory.prefix(5)) { entry in
                HStack {
                    Text(entry.text)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var footerSection: some View {
        HStack {
            if !PermissionManager.shared.accessibilityAuthorized {
                Button("授權輔助使用") {
                    PermissionManager.shared.requestAccessibilityAccess()
                }
                .font(.caption)
            }
            Spacer()
            SettingsLink {
                Text("設定")
            }
            Button("結束") {
                NSApplication.shared.terminate(nil)
            }
        }
        .font(.caption)
    }

    // MARK: - Computed Properties

    private var statusIcon: String {
        switch appState.state {
        case .idle: return "mic"
        case .loading: return "arrow.down.circle"
        case .recording: return "mic.fill"
        case .transcribing: return "text.bubble"
        case .error: return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        switch appState.state {
        case .idle: return .secondary
        case .loading: return .blue
        case .recording: return .red
        case .transcribing: return .orange
        case .error: return .red
        }
    }

    private var statusText: String {
        switch appState.state {
        case .idle: return "待命中"
        case .loading: return "載入模型中 \(Int(appState.modelLoadProgress * 100))%"
        case .recording: return "錄音中..."
        case .transcribing: return "辨識中..."
        case .error(let msg): return msg
        }
    }
}
