import AppKit
import Carbon.HIToolbox

/// Types streaming hypotheses directly into the focused window.
/// Tracks what has been injected so far; each update deletes the diverging
/// suffix with backspace key events and types the new text via CGEvent
/// unicode events — the clipboard is never touched.
@MainActor
final class LiveTextInjector {

    private var injectedText = ""

    var hasInjectedText: Bool { !injectedText.isEmpty }

    /// Forget injected state (start of a new dictation).
    func reset() {
        injectedText = ""
    }

    /// Bring the focused window's text in line with the new hypothesis.
    func update(hypothesis: String) {
        let delta = TextDelta.compute(injected: injectedText, hypothesis: hypothesis)
        guard delta.backspaces > 0 || !delta.insert.isEmpty else { return }
        sendBackspaces(delta.backspaces)
        typeText(delta.insert)
        injectedText = hypothesis
    }

    /// Apply the final text and clear state.
    func finish(finalText: String) {
        update(hypothesis: finalText)
        injectedText = ""
    }

    // MARK: - Key event synthesis

    private func sendBackspaces(_ count: Int) {
        guard count > 0 else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let key = CGKeyCode(kVK_Delete)
        for _ in 0..<count {
            for keyDown in [true, false] {
                guard let event = CGEvent(
                    keyboardEventSource: source, virtualKey: key, keyDown: keyDown
                ) else { continue }
                // Clear flags: the user is physically holding fn, and
                // fn+delete would become forward-delete if it leaked in.
                event.flags = []
                event.post(tap: .cghidEventTap)
            }
        }
    }

    private func typeText(_ text: String) {
        guard !text.isEmpty else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let units = Array(text.utf16)

        // keyboardSetUnicodeString delivers at most ~20 UTF-16 units per event
        var index = 0
        while index < units.count {
            var end = min(index + 20, units.count)
            // Never split a surrogate pair across events
            if end < units.count, (0xD800...0xDBFF).contains(units[end - 1]) {
                end += 1
            }
            let chunk = Array(units[index..<end])
            for keyDown in [true, false] {
                guard let event = CGEvent(
                    keyboardEventSource: source, virtualKey: 0, keyDown: keyDown
                ) else { continue }
                event.flags = []
                event.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                event.post(tap: .cghidEventTap)
            }
            index = end
        }
    }
}
