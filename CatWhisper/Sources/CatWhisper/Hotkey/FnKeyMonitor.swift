import Cocoa

/// Monitors the fn (Globe) key for hold-to-record
/// Press fn → start recording, release fn → stop recording
final class FnKeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isFnHeld = false

    /// fn/Globe key code on Apple keyboards
    private static let fnKeyCode: UInt16 = 63

    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    func start() {
        // Global monitor: catches fn key when other apps are focused
        // Note: requires Accessibility permission for key events
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        // Local monitor: catches fn key when our app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        // Only respond to the fn/Globe key itself
        guard event.keyCode == Self.fnKeyCode else { return }

        let fnPressed = event.modifierFlags.contains(.function)

        if fnPressed && !isFnHeld {
            isFnHeld = true
            onFnDown?()
        } else if !fnPressed && isFnHeld {
            isFnHeld = false
            onFnUp?()
        }
    }

    deinit { stop() }
}
