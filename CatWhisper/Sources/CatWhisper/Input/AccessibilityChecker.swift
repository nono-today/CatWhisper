import AppKit

/// Checks and requests Accessibility (Assistive Access) permission
/// Required for CGEvent-based key simulation (Cmd+V paste)
enum AccessibilityChecker {

    /// Whether the app is trusted for accessibility
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Check if trusted, optionally prompting the system dialog
    @discardableResult
    static func checkAndPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
