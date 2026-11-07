import AppKit
import ApplicationServices

/// Ordre des icônes de la barre des menus, lu via l'Accessibilité (AXExtrasMenuBar de chaque app)
/// et modifié en reproduisant le ⌘-glisser que l'on ferait à la main.
final class MenuBarOrder: ObservableObject {
    struct Item: Identifiable, Equatable {
        let id: String
        let name: String
        let bundleID: String
        let icon: NSImage?
        let frame: CGRect // coordonnées écran, origine en haut à gauche
    }

    static let shared = MenuBarOrder()

    @Published private(set) var items: [Item] = []
    @Published private(set) var busy = false

    var trusted: Bool { AXIsProcessTrusted() }

    /// Déplie toute la barre (sinon les icônes masquées n'ont pas de position), puis lit l'ordre.
    func refresh() {
        guard trusted else { return }
        HidingController.shared.set(.all)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.scan() }
    }

    private func scan() {
        var found: [Item] = []
        for app in NSWorkspace.shared.runningApplications {
            guard let bundle = app.bundleIdentifier else { continue }
            let element = AXUIElementCreateApplication(app.processIdentifier)
            var bar: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, "AXExtrasMenuBar" as CFString, &bar) == .success,
                  let barElement = bar else { continue }
            var children: CFTypeRef?
            guard AXUIElementCopyAttributeValue(barElement as! AXUIElement, kAXChildrenAttribute as CFString, &children) == .success,
                  let list = children as? [AXUIElement] else { continue }
            for (index, child) in list.enumerated() {
                guard let frame = Self.frame(of: child), frame.width > 0 else { continue }
                found.append(Item(id: "\(bundle)#\(index)", name: Self.title(of: child) ?? app.localizedName ?? bundle,
                                  bundleID: bundle, icon: app.icon, frame: frame))
            }
        }
        items = found.sorted { $0.frame.minX < $1.frame.minX }
    }

    /// Déplace une icône d'un cran vers la gauche (-1) ou la droite (+1).
    func move(_ item: Item, by offset: Int) {
        guard !busy, let index = items.firstIndex(of: item) else { return }
        let targetIndex = index + offset
        guard items.indices.contains(targetIndex) else { return }
        let target = items[targetIndex]
        busy = true
        // On dépose juste au-delà du voisin, du côté où l'on va.
        let destination = CGPoint(x: offset < 0 ? target.frame.minX + 2 : target.frame.maxX - 2, y: target.frame.midY)
        commandDrag(from: CGPoint(x: item.frame.midX, y: item.frame.midY), to: destination) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.scan()
                self.busy = false
            }
        }
    }

    /// ⌘-glisser simulé, en plusieurs étapes pour que la barre des menus suive le mouvement.
    private func commandDrag(from start: CGPoint, to end: CGPoint, done: @escaping () -> Void) {
        let original = CGEvent(source: nil)?.location ?? start
        let source = CGEventSource(stateID: .hidSystemState)
        func post(_ type: CGEventType, _ point: CGPoint) {
            let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
        post(.leftMouseDown, start)
        let steps = 12
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let point = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + Double(i) * 0.02) { post(.leftMouseDragged, point) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + Double(steps) * 0.02 + 0.15) {
            post(.leftMouseUp, end)
            CGWarpMouseCursorPosition(original)
            done()
        }
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success else { return nil }
        var p = CGPoint.zero, s = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &p)
        AXValueGetValue(size as! AXValue, .cgSize, &s)
        return CGRect(origin: p, size: s)
    }

    private static func title(of element: AXUIElement) -> String? {
        for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute] {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
               let text = value as? String, !text.isEmpty { return text }
        }
        return nil
    }
}
