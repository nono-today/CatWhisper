#!/usr/bin/env swift
import AppKit

// ── Config ──
let S: CGFloat = 1024
let scale: CGFloat = 45
let ox: CGFloat = 17   // center offset x
let oy: CGFloat = 107  // center offset y

func mp(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    NSPoint(x: x * scale + ox, y: y * scale + oy)
}
func mr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x * scale + ox, y: y * scale + oy, width: w * scale, height: h * scale)
}

// ── Colors ──
let tan    = NSColor(calibratedRed: 0.82, green: 0.63, blue: 0.42, alpha: 1)
let frost  = NSColor(calibratedRed: 1.0,  green: 0.60, blue: 0.73, alpha: 1)
let cat    = NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.55, alpha: 1)
let cheek  = NSColor(calibratedRed: 1.0,  green: 0.47, blue: 0.60, alpha: 1)
let dark   = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.12, alpha: 1)

let rainbow: [(CGFloat, CGFloat, CGFloat)] = [
    (1.0, 0.0, 0.0), (1.0, 0.6, 0.0), (1.0, 0.9, 0.0),
    (0.2, 0.8, 0.0), (0.0, 0.6, 1.0), (0.6, 0.2, 1.0),
]

// ── Create bitmap ──
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(S), pixelsHigh: Int(S),
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("bitmap") }

guard let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("ctx") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx
let g = nsCtx.cgContext
g.translateBy(x: 0, y: S)
g.scaleBy(x: 1, y: -1)

// ── 1. Background: space gradient ──
let bgGrad = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        CGColor(red: 0.04, green: 0.01, blue: 0.14, alpha: 1),
        CGColor(red: 0.01, green: 0.04, blue: 0.22, alpha: 1),
    ] as CFArray,
    locations: [0, 1]
)!
g.drawLinearGradient(bgGrad, start: .zero, end: CGPoint(x: S, y: S), options: [])

// Stars (fixed positions for reproducibility)
let starPositions: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (80, 120, 4, 0.8), (200, 60, 3, 0.6), (350, 180, 5, 0.9),
    (500, 50, 3, 0.5), (700, 130, 4, 0.7), (900, 80, 3, 0.6),
    (50, 400, 3, 0.5), (150, 700, 4, 0.7), (60, 900, 3, 0.6),
    (300, 850, 5, 0.8), (500, 950, 3, 0.5), (750, 900, 4, 0.7),
    (950, 600, 3, 0.6), (880, 350, 5, 0.8), (950, 950, 4, 0.7),
    (400, 400, 2, 0.4), (600, 300, 2, 0.4), (800, 500, 2, 0.3),
    (100, 550, 2, 0.4), (700, 750, 2, 0.3), (450, 650, 2, 0.4),
]
for (sx, sy, sr, sa) in starPositions {
    g.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: sa))
    g.fillEllipse(in: CGRect(x: sx - sr, y: sy - sr, width: sr * 2, height: sr * 2))
}

// ── 2. Frosted glass backdrop (Apple translucent style) ──
let glassRect = CGRect(x: S * 0.08, y: S * 0.08, width: S * 0.84, height: S * 0.84)
let glassPath = CGPath(roundedRect: glassRect, cornerWidth: S * 0.18, cornerHeight: S * 0.18, transform: nil)
g.saveGState()
g.addPath(glassPath)
g.clip()
// Frosted fill
g.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
g.fill(glassRect)
// Top highlight (glass shine)
let shineGrad = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.12),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray,
    locations: [0, 1]
)!
g.drawLinearGradient(shineGrad,
    start: CGPoint(x: S / 2, y: glassRect.minY),
    end: CGPoint(x: S / 2, y: glassRect.minY + glassRect.height * 0.5),
    options: [])
// Border
g.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
g.setLineWidth(2)
g.addPath(glassPath)
g.strokePath()
g.restoreGState()

// ── Helper: NSBezierPath drawing ──
NSColor.black.set() // reset

// ── 3. Rainbow trail ──
let sh: CGFloat = 1.5
let ry: CGFloat = 4.5
for (i, c) in rainbow.enumerated() {
    NSColor(calibratedRed: c.0, green: c.1, blue: c.2, alpha: 1).setFill()

    // Main stripe
    mr(0, ry + CGFloat(i) * sh, 7, sh).fill()

    // Glow behind stripe
    let glowColor = NSColor(calibratedRed: c.0, green: c.1, blue: c.2, alpha: 0.25)
    glowColor.setFill()
    mr(-0.3, ry + CGFloat(i) * sh - 0.2, 7.6, sh + 0.4).fill()
}

// ── 4. Pop-tart body ──
tan.setFill()
NSBezierPath(roundedRect: mr(4, 3.5, 11, 10), xRadius: 1.5 * scale, yRadius: 1.5 * scale).fill()

// Frosting
frost.setFill()
NSBezierPath(roundedRect: mr(5, 4.5, 9, 8), xRadius: 1 * scale, yRadius: 1 * scale).fill()

// Sprinkles (larger for icon)
for (x, y, r, g2, b) in [
    (6.5, 5.5, 1.0, 0.2, 0.3), (9.0, 5.0, 0.2, 0.5, 1.0),
    (7.0, 8.5, 0.2, 0.8, 0.3), (10.0, 7.0, 1.0, 0.2, 0.3),
    (8.0, 11.0, 0.2, 0.5, 1.0), (11.0, 9.5, 0.2, 0.8, 0.3),
    (6.0, 10.5, 1.0, 0.3, 0.5), (9.5, 9.0, 0.3, 0.7, 0.2),
] as [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] {
    NSColor(calibratedRed: r, green: g2, blue: b, alpha: 1).setFill()
    mr(x, y, 0.5, 0.5).fill()
}

// ── 5. Cat head ──
cat.setFill()
NSBezierPath(roundedRect: mr(13.5, 4, 7, 7.5), xRadius: 2 * scale, yRadius: 2 * scale).fill()

// Ears
for pts in [
    [mp(14, 4.5), mp(15.2, 1), mp(16.5, 4)],
    [mp(18, 4),   mp(19.2, 1), mp(20.5, 4.5)],
] {
    let ear = NSBezierPath()
    ear.move(to: pts[0]); ear.line(to: pts[1]); ear.line(to: pts[2])
    ear.close(); ear.fill()
}

// Inner ears (pink)
let innerEarPink = NSColor(calibratedRed: 0.85, green: 0.55, blue: 0.6, alpha: 1)
innerEarPink.setFill()
for pts in [
    [mp(14.5, 4.3), mp(15.2, 1.8), mp(16, 4)],
    [mp(18.5, 4),   mp(19.2, 1.8), mp(20, 4.3)],
] {
    let ear = NSBezierPath()
    ear.move(to: pts[0]); ear.line(to: pts[1]); ear.line(to: pts[2])
    ear.close(); ear.fill()
}

// Eyes
dark.setFill()
NSBezierPath(ovalIn: mr(15, 6.5, 1.5, 1.5)).fill()
NSBezierPath(ovalIn: mr(18.5, 6.5, 1.5, 1.5)).fill()

// Eye highlights
NSColor.white.setFill()
NSBezierPath(ovalIn: mr(15.2, 6.6, 0.5, 0.5)).fill()
NSBezierPath(ovalIn: mr(18.7, 6.6, 0.5, 0.5)).fill()

// Cheeks
cheek.setFill()
NSBezierPath(ovalIn: mr(14, 9, 1.5, 1)).fill()
NSBezierPath(ovalIn: mr(19, 9, 1.5, 1)).fill()

// Mouth
dark.setStroke()
let mouth = NSBezierPath()
mouth.move(to: mp(16.5, 10))
mouth.curve(to: mp(17.5, 10.8), controlPoint1: mp(16.8, 11), controlPoint2: mp(17.2, 11))
mouth.curve(to: mp(18.5, 10), controlPoint1: mp(17.8, 11), controlPoint2: mp(18.2, 11))
mouth.lineWidth = scale * 0.12
mouth.stroke()

// ── 6. Legs ──
cat.setFill()
for x in [6.0, 9.0, 14.5, 17.5] as [CGFloat] {
    mr(x, 13.5, 1.5, 2.5).fill()
}

// ── 7. Tail ──
mr(2.5, 7, 2.5, 1.5).fill()

// ── Done ──
NSGraphicsContext.restoreGraphicsState()

let outPath = "/Users/zhiii0x/Documents/zhi-whisper/AppIcon.png"
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! data.write(to: URL(fileURLWithPath: outPath))
print("Icon saved: \(outPath)")
