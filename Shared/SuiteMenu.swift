import AppKit

/// « La suite Notch » : un sous-menu commun aux trois apps, qui présente les deux autres.
/// Une app installée s'ouvre ; sinon, sa page de téléchargement (Gumroad).
enum SuiteMenu {
    enum App: CaseIterable {
        case bar, less, island

        var bundleID: String {
            switch self {
            case .bar: return "fr.gfryptr.notchbar"
            case .less: return "fr.gfryptr.notchless"
            case .island: return "fr.gfryptr.notchisland"
            }
        }
        var name: String {
            switch self {
            case .bar: return "Notch Bar"
            case .less: return "Notch Less"
            case .island: return "Notch Island"
            }
        }
        var pitch: String {
            switch self {
            case .bar: return L("L'encoche disparaît, l'écran s'arrondit")
            case .less: return L("Une barre des menus qui respire")
            case .island: return L("La Dynamic Island, sur ton Mac")
            }
        }
        var store: URL {
            switch self {
            case .bar: return URL(string: "https://eprysmn.gumroad.com/l/notchbar")!
            case .less: return URL(string: "https://eprysmn.gumroad.com/l/notchless")!
            case .island: return URL(string: "https://eprysmn.gumroad.com/l/notchisland")!
            }
        }
        var icon: NSImage {
            switch self {
            case .bar: return SuiteIcons.notchBar()
            case .less: return SuiteIcons.notchLess(.collapsed)
            case .island: return SuiteIcons.notchIsland()
            }
        }
        /// La mise à niveau payante de Notch Island.
        static let plusStore = URL(string: "https://eprysmn.gumroad.com/l/notchislandplus")!
        var installedURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }
    }

    /// Le sous-menu, sans l'app courante.
    static func item(for current: App) -> NSMenuItem {
        let item = NSMenuItem(title: L("La suite Notch"), action: nil, keyEquivalent: "")
        let menu = NSMenu()
        for app in App.allCases where app != current {
            let installed = app.installedURL != nil
            let entry = SuiteMenuItem(title: app.name) {
                if let url = app.installedURL {
                    NSWorkspace.shared.openApplication(at: url, configuration: .init())
                } else {
                    NSWorkspace.shared.open(app.store)
                }
            }
            entry.image = app.icon
            entry.toolTip = app.pitch
            // Sous-titre : ce que fait l'app, ou l'invitation à l'essayer.
            let sub = installed ? app.pitch : app.pitch + " · " + L("à essayer gratuitement")
            entry.attributedTitle = NSAttributedString(string: app.name + "\n", attributes: [.font: NSFont.menuFont(ofSize: 0)])
                .appending(NSAttributedString(string: sub, attributes: [.font: NSFont.menuFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]))
            menu.addItem(entry)
        }
        if current != .island {
            menu.addItem(.separator())
            menu.addItem(SuiteMenuItem(title: L("Notch Island Plus : tous les modules…")) { NSWorkspace.shared.open(App.plusStore) })
        }
        item.submenu = menu
        return item
    }
}

/// Élément de menu qui exécute une fermeture.
final class SuiteMenuItem: NSMenuItem {
    private let handler: () -> Void
    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func run() { handler() }
}

private extension NSAttributedString {
    func appending(_ other: NSAttributedString) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: self)
        m.append(other)
        return m
    }
}
