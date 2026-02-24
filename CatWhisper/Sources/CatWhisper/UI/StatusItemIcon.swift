import SwiftUI
import AppKit

/// Menu bar icon — Nyan Cat style, expression changes per state
struct StatusItemIcon: View {
    let state: AppState.State
    var body: some View {
        Image(nsImage: NyanCat.make(for: state))
    }
}

// MARK: - Nyan Cat (22×18 pt, vector shapes, non-template)

private enum NyanCat {

    // Palette
    static let tan   = NSColor(calibratedRed: 0.82, green: 0.63, blue: 0.42, alpha: 1)
    static let frost = NSColor(calibratedRed: 1.0,  green: 0.60, blue: 0.73, alpha: 1)
    static let cat   = NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.55, alpha: 1)
    static let cheek = NSColor(calibratedRed: 1.0,  green: 0.47, blue: 0.60, alpha: 1)
    static let dark  = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.12, alpha: 1)
    static let hpGrn = NSColor(calibratedRed: 0.2,  green: 0.9,  blue: 0.3,  alpha: 1)

    static let bow: [(CGFloat, CGFloat, CGFloat)] = [
        (1.0, 0.0, 0.0),  // red
        (1.0, 0.6, 0.0),  // orange
        (1.0, 0.9, 0.0),  // yellow
        (0.2, 0.8, 0.0),  // green
        (0.0, 0.6, 1.0),  // blue
        (0.6, 0.2, 1.0),  // purple
    ]

    static func make(for state: AppState.State) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size, flipped: true) { _ in

            // ── Rainbow trail ──
            let sh: CGFloat = 1.5
            let ry: CGFloat = 4.5
            for (i, c) in bow.enumerated() {
                NSColor(calibratedRed: c.0, green: c.1, blue: c.2, alpha: 1).setFill()
                NSRect(x: 0, y: ry + CGFloat(i) * sh, width: 7, height: sh).fill()
            }

            // ── Pop-tart body (wider than tall) ──
            tan.setFill()
            NSBezierPath(roundedRect: NSRect(x: 4, y: 3.5, width: 11, height: 10),
                         xRadius: 1.5, yRadius: 1.5).fill()
            frost.setFill()
            NSBezierPath(roundedRect: NSRect(x: 5, y: 4.5, width: 9, height: 8),
                         xRadius: 1, yRadius: 1).fill()

            // Sprinkles
            for (x, y, r, g, b) in [
                (6.5, 5.5, 1.0, 0.2, 0.3),
                (9.0, 5.0, 0.2, 0.5, 1.0),
                (7.0, 8.5, 0.2, 0.8, 0.3),
                (10.0, 7.0, 1.0, 0.2, 0.3),
                (8.0, 11.0, 0.2, 0.5, 1.0),
                (11.0, 9.5, 0.2, 0.8, 0.3),
            ] as [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] {
                NSColor(calibratedRed: r, green: g, blue: b, alpha: 1).setFill()
                NSRect(x: x, y: y, width: 1, height: 1).fill()
            }

            // ── Cat head (bigger, right side) ──
            cat.setFill()
            NSBezierPath(roundedRect: NSRect(x: 13.5, y: 4, width: 7, height: 7.5),
                         xRadius: 2, yRadius: 2).fill()

            // Ears
            for pts in [
                [p(14, 4.5), p(15.2, 1), p(16.5, 4)],
                [p(18, 4),   p(19.2, 1), p(20.5, 4.5)],
            ] { tri(pts).fill() }

            // Eyes
            drawEyes(for: state)

            // Cheeks
            cheek.setFill()
            NSBezierPath(ovalIn: NSRect(x: 14, y: 9, width: 1.5, height: 1)).fill()
            NSBezierPath(ovalIn: NSRect(x: 19, y: 9, width: 1.5, height: 1)).fill()

            // ── Cat legs ──
            cat.setFill()
            for x in [6.0, 9.0, 14.5, 17.5] as [CGFloat] {
                NSRect(x: x, y: 13.5, width: 1.5, height: 2.5).fill()
            }

            // ── Tail ──
            NSRect(x: 2.5, y: 7, width: 2.5, height: 1.5).fill()

            // ── Headphones (recording) ──
            if state == .recording { drawHP() }

            return true
        }
        image.isTemplate = false
        return image
    }

    // ── Eyes per state ──

    private static func drawEyes(for state: AppState.State) {
        switch state {
        case .idle, .recording:
            dark.setFill()
            NSBezierPath(ovalIn: NSRect(x: 15, y: 6.5, width: 1.5, height: 1.5)).fill()
            NSBezierPath(ovalIn: NSRect(x: 18.5, y: 6.5, width: 1.5, height: 1.5)).fill()
        case .transcribing:
            dark.setStroke()
            for (a, b) in [(14.8, 16.8), (18.2, 20.2)] {
                let l = NSBezierPath(); l.move(to: p(a, 7.3)); l.line(to: p(b, 7.3))
                l.lineWidth = 0.8; l.stroke()
            }
        case .loading:
            dark.setStroke()
            for (a, b) in [(14.8, 16.8), (18.2, 20.2)] {
                let c = NSBezierPath()
                c.move(to: p(a, 7))
                c.curve(to: p(b, 7), controlPoint1: p(a + 0.5, 8.5), controlPoint2: p(b - 0.5, 8.5))
                c.lineWidth = 0.7; c.stroke()
            }
        case .error:
            dark.setStroke()
            for cx in [15.8, 19.3] as [CGFloat] {
                for (dx, dy) in [(-0.7, -0.7), (0.7, -0.7)] as [(CGFloat, CGFloat)] {
                    let x = NSBezierPath()
                    x.move(to: p(cx + dx, 6.8 + dy))
                    x.line(to: p(cx - dx, 6.8 - dy + 1.4))
                    x.lineWidth = 0.7; x.stroke()
                }
            }
        }
    }

    // ── Headphones ──

    private static func drawHP() {
        hpGrn.setStroke()
        let b = NSBezierPath()
        b.move(to: p(13.5, 5.5))
        b.curve(to: p(21, 5.5), controlPoint1: p(14.5, -0.5), controlPoint2: p(20, -0.5))
        b.lineWidth = 0.9; b.stroke()

        hpGrn.setFill()
        NSBezierPath(roundedRect: NSRect(x: 13, y: 5, width: 1.8, height: 3.5), xRadius: 0.6, yRadius: 0.6).fill()
        NSBezierPath(roundedRect: NSRect(x: 20, y: 5, width: 1.8, height: 3.5), xRadius: 0.6, yRadius: 0.6).fill()
    }

    // ── Helpers ──

    private static func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }

    private static func tri(_ pts: [NSPoint]) -> NSBezierPath {
        let t = NSBezierPath()
        t.move(to: pts[0]); t.line(to: pts[1]); t.line(to: pts[2]); t.close()
        return t
    }
}
