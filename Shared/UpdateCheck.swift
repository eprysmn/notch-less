import AppKit

/// Vérifie s'il existe une version plus récente de l'app. La dernière version de chaque app est inscrite
/// dans un marqueur de la page de profil Gumroad (`<div id="notch-versions" data-island="1.1" …>`), que le
/// script de release met à jour : aucun serveur à héberger. Une vérification au lancement puis toutes les
/// 12 heures, silencieuse en cas d'échec ; rien d'autre que cette page n'est lu, et rien n'est envoyé.
final class UpdateCheck: NSObject {
    static let shared = UpdateCheck()

    /// Page de profil qui porte le marqueur.
    static let source = URL(string: "https://eprysmn.gumroad.com/landing/embed")!

    private(set) var available: String?
    private var app: SuiteMenu.App = .island
    private var timer: Timer?
    private var items = NSHashTable<NSMenuItem>.weakObjects()
    /// Appelé une fois par nouvelle version trouvée (l'île montre alors une pilule).
    var onFound: ((String) -> Void)?

    private static func key(_ app: SuiteMenu.App) -> String {
        switch app {
        case .bar: return "bar"
        case .less: return "less"
        case .island: return "island"
        }
    }

    var installed: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

    /// À appeler au lancement. L'édition bêta (identifiant en « .dev ») ne vérifie rien.
    func start(for app: SuiteMenu.App) {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".dev") != true else { return }
        self.app = app
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in self?.check() }
        timer = Timer.scheduledTimer(withTimeInterval: 12 * 3600, repeats: true) { [weak self] _ in self?.check() }
        timer?.tolerance = 600
    }

    /// Une ligne de menu, cachée tant qu'il n'y a rien de nouveau.
    func menuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "", action: #selector(open), keyEquivalent: "")
        item.target = self
        items.add(item)
        refresh(item)
        return item
    }

    private func refresh(_ item: NSMenuItem) {
        item.isHidden = available == nil
        if let v = available { item.title = String(format: L("Mise à jour disponible : %@…"), v) }
        item.image = available == nil ? nil : NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
    }

    @objc private func open() { NSWorkspace.shared.open(app.store) }

    func check(force: Bool = false) {
        var request = URLRequest(url: Self.source, timeoutInterval: 15)
        request.setValue("\(Bundle.main.bundleIdentifier ?? "notch")/\(installed)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self, let data, let html = String(data: data, encoding: .utf8),
                  let latest = Self.latest(in: html, key: Self.key(self.app)),
                  Self.isNewer(latest, than: self.installed) else { return }
            DispatchQueue.main.async {
                self.available = latest
                self.items.allObjects.forEach(self.refresh)
                let defaults = UserDefaults.standard
                if defaults.string(forKey: "update.notified") != latest {
                    defaults.set(latest, forKey: "update.notified")
                    self.onFound?(latest)
                }
            }
        }.resume()
    }

    /// `data-island="1.1"` dans le marqueur de versions.
    static func latest(in html: String, key: String) -> String? {
        guard let marker = html.range(of: "id=\"notch-versions\"") ?? html.range(of: "id='notch-versions'"),
              let tagEnd = html[marker.upperBound...].firstIndex(of: ">"),
              let attr = html[marker.upperBound..<tagEnd].range(of: "data-\(key)=\"") else { return nil }
        let rest = html[attr.upperBound..<tagEnd]
        return rest.firstIndex(of: "\"").map { String(rest[..<$0]) }
    }

    /// Comparaison numérique composante par composante (« 1.10 » > « 1.9 »), « -beta » ignoré.
    static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ v: String) -> [Int] { v.split(separator: "-").first.map { $0.split(separator: ".").map { Int($0) ?? 0 } } ?? [] }
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}
