import AVFoundation

/// Manages app permissions (microphone, accessibility)
@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var microphoneAuthorized = false
    @Published var accessibilityAuthorized = false

    private init() {
        checkPermissions()
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
        AccessibilityChecker.checkAndPrompt()
        // Re-check after a delay (user needs to toggle in System Settings)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkPermissions()
        }
    }
}
