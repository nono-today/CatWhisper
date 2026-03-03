import AppKit

/// Checks and requests Accessibility (Assistive Access) permission
/// Required for CGEvent-based key simulation (Cmd+V paste)
enum AccessibilityChecker {

    /// Whether the app is trusted for accessibility (live check, not cached)
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Check if trusted, optionally prompting the system dialog
    @discardableResult
    static func checkAndPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings directly to the Accessibility pane
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
