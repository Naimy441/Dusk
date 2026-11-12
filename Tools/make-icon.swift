// Renders Dusk's app icon into an .iconset folder.
// Usage: swift Tools/make-icon.swift <output.iconset>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func render(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    let s = CGFloat(px) / 1024.0
    cg.scaleBy(x: s, y: s)

    // Squircle background (Big Sur grid: 824pt body, 100pt margin).
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bg = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor.black.setFill()
    bg.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    bg.addClip()
    NSGradient(colors: [
        NSColor(red: 0.30, green: 0.27, blue: 0.62, alpha: 1),
        NSColor(red: 0.13, green: 0.12, blue: 0.36, alpha: 1),
        NSColor(red: 0.04, green: 0.05, blue: 0.15, alpha: 1),
    ], atLocations: [0, 0.5, 1], colorSpace: .deviceRGB)!.draw(in: body, angle: -90)

    // Horizon glow.
    NSGradient(colors: [
        NSColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 0.35),
        NSColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 0.0),
    ])!.draw(in: NSRect(x: 100, y: 100, width: 824, height: 300), angle: 90)

    // Stars.
    let stars: [(CGFloat, CGFloat, CGFloat)] = [
        (250, 760, 10), (330, 640, 6), (720, 790, 7), (790, 640, 11), (210, 520, 5), (600, 860, 5), (820, 470, 6),
    ]
    NSColor.white.withAlphaComponent(0.85).setFill()
    for (x, y, r) in stars {
        NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
    }

    // Crescent moon: a gold disc with an offset disc punched out.
    let moon = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
        let disc = NSRect(x: 300, y: 300, width: 420, height: 420)
        NSGradient(colors: [
            NSColor(red: 1.0, green: 0.90, blue: 0.62, alpha: 1),
            NSColor(red: 1.0, green: 0.70, blue: 0.30, alpha: 1),
        ])!.draw(in: NSBezierPath(ovalIn: disc), angle: -60)
        NSGraphicsContext.current?.compositingOperation = .clear
        NSBezierPath(ovalIn: disc.offsetBy(dx: 140, dy: 95)).fill()
        return true
    }
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = NSColor(red: 1.0, green: 0.75, blue: 0.4, alpha: 0.55)
    glow.shadowBlurRadius = 60
    glow.shadowOffset = .zero
    glow.set()
    moon.draw(in: NSRect(x: -10, y: -10, width: 1024, height: 1024))
    NSGraphicsContext.restoreGraphicsState()

    // Subtle top highlight.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.12), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSRect(x: 100, y: 600, width: 824, height: 324), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let data = render(px).representation(using: .png, properties: [:])!
        try! data.write(to: URL(fileURLWithPath: out).appendingPathComponent(name))
    }
}
print("Wrote \(out)")
