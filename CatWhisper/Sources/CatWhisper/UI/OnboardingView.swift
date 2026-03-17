import SwiftUI

/// First-launch permission guide — dark, rounded style matching notch pill
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var appeared = false

    private let steps: [(icon: String, title: String, desc: String)] = [
        ("mic.fill", "麥克風", "需要麥克風來錄製語音"),
        ("hand.raised.fill", "輔助使用", "讓辨識結果自動輸入到其他 App"),
        ("checkmark", "準備就緒", "按住 fn 說話，放開自動輸入"),
    ]

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App identity
                header
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Spacer().frame(height: 40)

                // Step card
                stepCard
                    .id(currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                Spacer().frame(height: 32)

                // Dots
                stepDots

                Spacer().frame(height: 20)

                // Skip
                if currentStep < 2 {
                    Button("跳過設定") { dismiss() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                } else {
                    Color.clear.frame(height: 16)
                }

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .frame(width: 460, height: 420)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: currentStep)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            // Cat ear icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 72, height: 72)
                Text("🐱")
                    .font(.system(size: 36))
            }

            Text("CatWhisper")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("按下快捷鍵，說話，文字自動輸入")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Step Card

    private var stepCard: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(stepIconColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: steps[currentStep].icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(stepIconColor)
            }

            VStack(spacing: 6) {
                Text(steps[currentStep].title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(steps[currentStep].desc)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Action
            stepAction
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var stepAction: some View {
        switch currentStep {
        case 0:
            if PermissionManager.shared.microphoneAuthorized {
                grantedBadge
                    .onAppear { advanceAfterDelay() }
            } else {
                actionButton("授權麥克風") {
                    Task {
                        _ = await PermissionManager.shared.requestMicrophoneAccess()
                        currentStep = 1
                    }
                }
            }
        case 1:
            if AccessibilityChecker.isTrusted {
                grantedBadge
                    .onAppear { advanceAfterDelay() }
            } else {
                VStack(spacing: 10) {
                    actionButton("開啟系統設定") {
                        AccessibilityChecker.checkAndPrompt()
                        currentStep = 2
                    }
                    Text("若不授權，可改為手動複製貼上")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        default:
            actionButton("開始使用") { dismiss() }
        }
    }

    // MARK: - Components

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(.white)
                )
        }
        .buttonStyle(.plain)
    }

    private var grantedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
            Text("已授權")
                .font(.system(size: 13, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.green)
        .padding(.vertical, 4)
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i == currentStep ? .white : .white.opacity(0.2))
                    .frame(width: i == currentStep ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.35), value: currentStep)
            }
        }
    }

    private var stepIconColor: Color {
        switch currentStep {
        case 0: return .red
        case 1: return .orange
        default: return .green
        }
    }

    private func advanceAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if currentStep < 2 { currentStep += 1 }
        }
    }
}
