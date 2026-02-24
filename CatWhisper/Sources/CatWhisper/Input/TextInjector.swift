import AppKit
import Carbon.HIToolbox

/// Injects text into the active window using clipboard + simulated Cmd+V
final class TextInjector {

    /// Inject text into the currently focused text field
    /// Saves and restores the original clipboard content
    func injectText(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Save original clipboard
        let originalItems: [(NSPasteboard.PasteboardType, Data)] = pasteboard.pasteboardItems?.flatMap { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        } ?? []

        // Set our text on the clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Dispatch paste simulation with a small delay to ensure clipboard is ready
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.08) {
            Self.simulatePaste()

            // Restore original clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                for (type, data) in originalItems {
                    pasteboard.setData(data, forType: type)
                }
            }
        }
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode = UInt16(kVK_ANSI_V)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        usleep(30_000) // 30ms gap between key down and up
        keyUp.post(tap: .cghidEventTap)
    }
}
