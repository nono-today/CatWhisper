import SwiftUI
import ServiceManagement

/// Settings window for CatWhisper
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @AppStorage("selectedModelId") private var selectedModelId = "mlx-community/Qwen3-ASR-0.6B-4bit"
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("一般", systemImage: "gear")
                }

            modelTab
                .tabItem {
                    Label("模型", systemImage: "cpu")
                }

            aboutTab
                .tabItem {
                    Label("關於", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 350)
    }

    // MARK: - Tabs

    private var generalTab: some View {
        Form {
            Section("操作方式") {
                HStack {
                    Image(systemName: "globe")
                    Text("按住 fn 鍵錄音，放開自動辨識")
                }
                .foregroundStyle(.secondary)
            }

            Section("啟動") {
                Toggle("登入時自動啟動", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section("權限") {
                HStack {
                    Text("麥克風")
                    Spacer()
                    Image(systemName: PermissionManager.shared.microphoneAuthorized
                          ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(PermissionManager.shared.microphoneAuthorized ? .green : .red)
                }
                HStack {
                    Text("輔助使用")
                    Spacer()
                    if PermissionManager.shared.accessibilityAuthorized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("開啟系統設定") {
                            PermissionManager.shared.requestAccessibilityAccess()
                        }
                    }
                }
                if !PermissionManager.shared.accessibilityAuthorized {
                    Text("若已授權仍無法使用：請先移除舊的 CatWhisper，再重新加入")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var modelTab: some View {
        Form {
            Section("ASR 模型") {
                Picker("模型", selection: $selectedModelId) {
                    Section("Qwen3-ASR — 0.6B（30 語言）") {
                        Text("0.6B 4-bit（~400MB，最快）")
                            .tag("mlx-community/Qwen3-ASR-0.6B-4bit")
                        Text("0.6B 8-bit（~1GB，較準確）")
                            .tag("mlx-community/Qwen3-ASR-0.6B-8bit")
                    }
                    Section("Qwen3-ASR — 1.7B（52 語言）") {
                        Text("1.7B 4-bit（~1.6GB，平衡）")
                            .tag("mlx-community/Qwen3-ASR-1.7B-4bit")
                        Text("1.7B 8-bit（~2.5GB，最準確）")
                            .tag("mlx-community/Qwen3-ASR-1.7B-8bit")
                    }
                    Section("Whisper — large-v3-turbo（99 語言）") {
                        Text("large-v3-turbo（~1.6GB）")
                            .tag("mlx-community/whisper-large-v3-turbo")
                    }
                }
                .onChange(of: selectedModelId) { _, _ in
                    Task { await appState.reloadModel() }
                }

                if appState.isLoading {
                    ProgressView(value: appState.modelLoadProgress) {
                        Text("下載中：\(appState.modelLoadFileName)")
                            .font(.caption)
                    }
                }
            }

            Section("輸出") {
                HStack {
                    Text("中文輸出")
                    Spacer()
                    Text("繁體中文")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.badge.xmark")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("CatWhisper")
                .font(.title)

            Text("macOS 語音轉文字")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("v1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("使用 Qwen3-ASR 模型，全程離線辨識")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail — not critical
        }
    }
}
