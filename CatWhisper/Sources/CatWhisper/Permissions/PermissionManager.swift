import AVFoundation
import Combine

/// Manages app permissions (microphone, accessibility)
/// Polls accessibility status every 2 seconds since macOS has no callback for it
@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var microphoneAuthorized = false
    @Published var accessibilityAuthorized = false

    private var pollTimer: Timer?

    private init() {
        checkPermissions()
        startPolling()
    }

    func checkPermissions() {
        microphoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityAuthorized = AccessibilityChecker.isTrusted
    }

    func requestMicrophoneAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneAuthorized = granted
        return granted
    }

    func requestAccessibilityAccess() {
        AccessibilityChecker.openAccessibilitySettings()
    }

    /// Poll accessibility status — macOS provides no notification for this change,
    /// so we check periodically to detect when the user grants permission.
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.accessibilityAuthorized = AccessibilityChecker.isTrusted
            }
        }
    }
}
