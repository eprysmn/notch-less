// Icônes d'app de la suite : icon-tool <island|island-beta|screen|dot> <dossier de sortie>
// « island-beta » : la version bêta, façon plan d'architecte des apps de développement d'Apple
// (fond bleu, grille de points, tracés de construction en pointillés).
// Fond noir uni pour les trois apps, et la même forme que leur icône de barre des menus (SuiteShapes).
import AppKit

let variant = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "island"
let out = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "."
let iconset = URL(fileURLWithPath: out).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Fond noir uni, forme blanche : la même que dans la barre des menus.
    let inset = s * 0.1
    let bg = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let squircle = NSBezierPath(roundedRect: bg, xRadius: bg.width * 0.225, yRadius: bg.width * 0.225)
    let beta = variant == "island-beta"
    if beta {
        NSGradient(colors: [NSColor(srgbRed: 0.16, green: 0.52, blue: 1, alpha: 1), NSColor(srgbRed: 0.02, green: 0.30, blue: 0.80, alpha: 1)])!
            .draw(in: squircle, angle: -90)
        // Grille de points, comme un papier millimétré.
        NSGraphicsContext.saveGraphicsState()
        squircle.addClip()
        NSColor.white.withAlphaComponent(0.22).setFill()
        let step = bg.width / 16, dot = max(1, s * 0.006)
        var y = bg.minY + step / 2
        while y < bg.maxY { var x = bg.minX + step / 2
            while x < bg.maxX { NSBezierPath(ovalIn: NSRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2)).fill(); x += step }
            y += step }
        NSGraphicsContext.restoreGraphicsState()
    } else {
        NSColor(calibratedWhite: 0.07, alpha: 1).setFill()
        squircle.fill()
    }

    // La forme occupe 58 % du carré.
    let side = bg.width * 0.58
    let box = NSRect(x: bg.midX - side / 2, y: bg.midY - side / 2, width: side, height: side)
    if beta {
        // Tracés de construction : axes et cercles des extrémités de la pilule, en pointillés.
        let pill = SuiteShapes.island(in: box).bounds
        let line = max(1, s * 0.008)
        let dash: [CGFloat] = [s * 0.018, s * 0.014]
        NSColor.white.withAlphaComponent(0.55).setStroke()
        let guides = NSBezierPath()
        guides.move(to: NSPoint(x: bg.minX + bg.width * 0.08, y: pill.midY)); guides.line(to: NSPoint(x: bg.maxX - bg.width * 0.08, y: pill.midY))
        guides.move(to: NSPoint(x: pill.midX, y: bg.minY + bg.width * 0.12)); guides.line(to: NSPoint(x: pill.midX, y: bg.maxY - bg.width * 0.12))
        let rad = pill.height / 2
        guides.appendOval(in: NSRect(x: pill.minX, y: pill.minY, width: rad * 2, height: rad * 2))
        guides.appendOval(in: NSRect(x: pill.maxX - rad * 2, y: pill.minY, width: rad * 2, height: rad * 2))
        guides.appendRect(pill.insetBy(dx: -s * 0.03, dy: -s * 0.03))
        guides.lineWidth = line
        guides.setLineDash(dash, count: dash.count, phase: 0)
        guides.stroke()
    }
    NSColor.white.set()
    switch variant {
    case "screen":
        let shapes = SuiteShapes.screen(in: box, line: side * 0.09)
        shapes.outline.stroke()
        shapes.fill.fill()
    case "dot":
        let shapes = SuiteShapes.disc(in: box)
        NSBezierPath(ovalIn: shapes.disc).fill()
        NSColor(calibratedWhite: 0.07, alpha: 1).setFill()
        NSBezierPath(ovalIn: shapes.dot).fill()
    default:
        SuiteShapes.island(in: box).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
