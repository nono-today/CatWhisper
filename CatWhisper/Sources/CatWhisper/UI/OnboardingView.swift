import SwiftUI

/// First-launch permission guide
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("歡迎使用 CatWhisper")
                .font(.largeTitle.bold())

            Text("按下快捷鍵，說話，文字自動輸入")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            // Steps
            Group {
                switch currentStep {
                case 0:
                    stepView(
                        icon: "mic.circle.fill",
                        title: "麥克風權限",
                        description: "CatWhisper 需要麥克風來錄製您的語音",
                        actionTitle: "授權麥克風",
                        action: {
                            Task {
                                _ = await PermissionManager.shared.requestMicrophoneAccess()
                                currentStep = 1
                            }
                        },
                        granted: PermissionManager.shared.microphoneAuthorized
                    )
                case 1:
                    stepView(
                        icon: "hand.raised.circle.fill",
                        title: "輔助使用權限",
                        description: "需要此權限才能自動將辨識結果輸入到其他應用程式。\n若不授權，可改為手動複製貼上。",
                        actionTitle: "開啟系統設定",
                        action: {
                            AccessibilityChecker.checkAndPrompt()
                            currentStep = 2
                        },
                        granted: AccessibilityChecker.isTrusted
                    )
                default:
                    stepView(
                        icon: "checkmark.circle.fill",
                        title: "準備就緒！",
                        description: "按下 ⌥ Space 開始錄音\n再按一次停止錄音，文字會自動輸入",
                        actionTitle: "開始使用",
                        action: { dismiss() },
                        granted: false
                    )
                }
            }

            Spacer()

            // Step indicator
            HStack(spacing: 8) {
                ForEach(0..<3) { step in
                    Circle()
                        .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Skip button
            if currentStep < 2 {
                Button("跳過") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
        }
        .padding(32)
    }

    private func stepView(
        icon: String,
        title: String,
        description: String,
        actionTitle: String,
        action: @escaping () -> Void,
        granted: Bool
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(granted ? .green : .accentColor)

            Text(title)
                .font(.title2.bold())

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if granted {
                Label("已授權", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            currentStep += 1
                        }
                    }
            } else {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }
}
