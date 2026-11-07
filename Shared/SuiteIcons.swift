import AppKit

/// Formes de la suite, partagées par les icônes de barre des menus et les icônes d'app.
/// Chaque forme se dessine dans un carré `r` mis à l'échelle par l'appelant.
///
/// Une même grille relie les trois logos :
///  - largeur commune W : la pilule, le disque, l'écran ;
///  - hauteur commune H : la pilule, le point du disque, l'ouverture de l'écran sous la bande ;
///  - rayon commun H / 2 : les bouts de la pilule, les coins de l'écran.
enum SuiteShapes {
    static func width(_ u: CGFloat) -> CGFloat { u * 0.96 }
    static func height(_ u: CGFloat) -> CGFloat { u * 0.4 }

    /// Notch Island : une pilule W × H.
    static func island(in r: NSRect) -> NSBezierPath {
        let w = width(r.width), h = height(r.width)
        let pill = NSRect(x: r.midX - w / 2, y: r.midY - h / 2, width: w, height: h)
        return NSBezierPath(roundedRect: pill, xRadius: h / 2, yRadius: h / 2)
    }

    /// Notch Bar : écran de largeur W, bande pleine en haut, ouverture de hauteur H dessous,
    /// et les deux congés concaves sous la bande (« arrondir le bas de la barre »).
    static func screen(in r: NSRect, line: CGFloat) -> (outline: NSBezierPath, fill: NSBezierPath) {
        let u = r.width
        let w = width(u), h = height(u)
        let band = u * 0.24
        let screen = NSRect(x: r.midX - w / 2, y: r.midY - (band + h + line) / 2, width: w, height: band + h + line)
        let radius = h / 2
        let outline = NSBezierPath(roundedRect: screen.insetBy(dx: line / 2, dy: line / 2),
                                   xRadius: radius - line / 2, yRadius: radius - line / 2)
        outline.lineWidth = line

        let bottom = screen.maxY - band
        let fill = NSBezierPath()
        fill.move(to: NSPoint(x: screen.minX, y: bottom))
        fill.line(to: NSPoint(x: screen.minX, y: screen.maxY - radius))
        fill.appendArc(withCenter: NSPoint(x: screen.minX + radius, y: screen.maxY - radius), radius: radius,
                       startAngle: 180, endAngle: 90, clockwise: true)
        fill.line(to: NSPoint(x: screen.maxX - radius, y: screen.maxY))
        fill.appendArc(withCenter: NSPoint(x: screen.maxX - radius, y: screen.maxY - radius), radius: radius,
                       startAngle: 90, endAngle: 0, clockwise: true)
        fill.line(to: NSPoint(x: screen.maxX, y: bottom))
        fill.close()

        // Congés de même rayon que les coins intérieurs : l'ouverture a quatre coins identiques.
        let f = radius - line
        let innerLeft = screen.minX + line, innerRight = screen.maxX - line
        for left in [true, false] {
            let x = left ? innerLeft : innerRight
            let corner = NSBezierPath()
            corner.move(to: NSPoint(x: x, y: bottom))
            corner.line(to: NSPoint(x: x, y: bottom - f))
            corner.appendArc(withCenter: NSPoint(x: left ? x + f : x - f, y: bottom - f), radius: f,
                             startAngle: left ? 180 : 0, endAngle: 90, clockwise: left)
            corner.close()
            fill.append(corner)
        }
        return (outline, fill)
    }

    /// Notch Less : un disque de diamètre W, percé au centre d'un point de diamètre H une fois déplié.
    static func disc(in r: NSRect) -> (disc: NSRect, dot: NSRect) {
        let w = width(r.width), h = height(r.width)
        return (NSRect(x: r.midX - w / 2, y: r.midY - w / 2, width: w, height: w),
                NSRect(x: r.midX - h / 2, y: r.midY - h / 2, width: h, height: h))
    }
}

/// Icônes de barre des menus : même grille 18 pt, mêmes rondeurs. Images « template ».
enum SuiteIcons {
    private static let size = NSSize(width: 18, height: 18)
    private static let box = NSRect(x: 1, y: 1, width: 16, height: 16)
    private static let line: CGFloat = 1.6

    private static func make(_ draw: @escaping () -> Void) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.set()
            draw()
            return true
        }
        image.isTemplate = true
        return image
    }

    static func notchIsland() -> NSImage {
        make { SuiteShapes.island(in: box).fill() }
    }

    static func notchBar() -> NSImage {
        make {
            let shapes = SuiteShapes.screen(in: box, line: line)
            shapes.outline.stroke()
            shapes.fill.fill()
        }
    }

    enum HiderState { case collapsed, expanded, all }

    /// Rangée : disque plein. Dépliée (ou tout visible) : un point se creuse au centre.
    static func notchLess(_ state: HiderState) -> NSImage {
        make {
            let shapes = SuiteShapes.disc(in: box)
            let path = NSBezierPath(ovalIn: shapes.disc)
            if state != .collapsed {
                path.append(NSBezierPath(ovalIn: shapes.dot))
                path.windingRule = .evenOdd
            }
            path.fill()
        }
    }
}
