import AppKit
import Carbon.HIToolbox

/// Injects text into the active window using clipboard + simulated Cmd+V
final class TextInjector {

    /// Inject text into the currently focused text field
    /// Saves and restores the original clipboard content
    func injectText(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Save original clipboard — preserve each NSPasteboardItem separately
        let savedItems: [[(NSPasteboard.PasteboardType, Data)]] = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        } ?? []

        // Set our text on the clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate paste with a small delay to ensure clipboard is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Self.simulatePaste()

            // Restore original clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                pasteboard.clearContents()
                let items: [NSPasteboardItem] = savedItems.map { typesAndData in
                    let item = NSPasteboardItem()
                    for (type, data) in typesAndData {
                        item.setData(data, forType: type)
                    }
                    return item
                }
                if !items.isEmpty {
                    pasteboard.writeObjects(items)
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

        // Use async delay instead of blocking usleep
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
