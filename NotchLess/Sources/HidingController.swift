import AppKit
import ApplicationServices
import Combine
import ServiceManagement

/// Niveau de masquage choisi pour une app.
enum HideLevel: Int, CaseIterable, Identifiable {
    case visible = 0, hidden = 1, alwaysHidden = 2
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .visible: return L("Visible")
        case .hidden: return L("Masquée")
        case .alwaysHidden: return L("Toujours masquée")
        }
    }
}

/// Garde les choix de l'utilisateur et décide de ce que MenuBarAgent doit afficher.
///   replié     → les apps « Masquée » et « Toujours masquée » disparaissent
///   déplié     → seules les « Toujours masquée » restent cachées
///   tout voir  → aucune restriction
final class HidingController: ObservableObject {
    enum State { case collapsed, expanded, all }

    static let shared = HidingController()

    /// Agents Apple dont les icônes passent par leur identifiant d'app : jamais masqués.
    private static let alwaysAllowed: Set<String> = [
        "com.apple.controlcenter", "com.apple.MenuBarAgent", "com.apple.systemuiserver",
        "com.apple.TextInputMenuAgent", "com.apple.Siri", "com.apple.Spotlight",
        "com.apple.wifi.WiFiAgent", "com.apple.ScreenTimeAgent", "com.apple.AirPlayUIAgent",
        "com.apple.UserNotificationCenter", "com.apple.notificationcenterui", "com.apple.loginwindow",
    ]

    private let bridge = MenuBarAgentBridge()
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private var autoCollapse: DispatchWorkItem?
    private var pendingReconcile: DispatchWorkItem?

    @Published private(set) var state: State = .collapsed
    @Published private(set) var levels: [String: HideLevel]
    @Published var autoCollapseSeconds: Int { didSet { defaults.set(autoCollapseSeconds, forKey: "autoCollapseSeconds") } }
    /// Liste complète : agents et processus système compris.
    @Published var showSystemProcesses: Bool { didSet { defaults.set(showSystemProcesses, forKey: "showSystemProcesses") } }

    var isAvailable: Bool { bridge.isAvailable }

    private init() {
        defaults.register(defaults: ["autoCollapseSeconds": 10])
        autoCollapseSeconds = defaults.integer(forKey: "autoCollapseSeconds")
        showSystemProcesses = defaults.bool(forKey: "showSystemProcesses")
        let saved = defaults.dictionary(forKey: "levels") as? [String: Int] ?? [:]
        levels = saved.compactMapValues(HideLevel.init(rawValue:))

        // Une app lancée pendant que la barre est repliée doit entrer dans la liste autorisée.
        let wnc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            wnc.publisher(for: name)
                .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in self?.reconcile() }
                .store(in: &cancellables)
        }
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in self?.reconcile() }
            .store(in: &cancellables)

        reconcile()
    }

    func level(of bundleID: String) -> HideLevel { levels[bundleID] ?? .visible }

    func setLevel(_ level: HideLevel, for bundleID: String) {
        levels[bundleID] = level == .visible ? nil : level
        defaults.set(levels.mapValues(\.rawValue), forKey: "levels")
        reconcile()
    }

    /// Clic : déplier/replier. Double-clic ou ⌥-clic : tout afficher.
    func handleClick(doubleClick: Bool, option: Bool) {
        if doubleClick || option {
            set(.all)
        } else {
            set(state == .collapsed ? .expanded : .collapsed)
        }
    }

    func set(_ newState: State) {
        state = newState
        reconcile()
        autoCollapse?.cancel()
        if newState != .collapsed && autoCollapseSeconds > 0 {
            let work = DispatchWorkItem { [weak self] in self?.set(.collapsed) }
            autoCollapse = work
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(autoCollapseSeconds), execute: work)
        }
    }

    func releaseAll() { bridge.release() }

    private func reconcile() {
        let threshold: HideLevel?
        switch state {
        case .collapsed: threshold = .hidden
        case .expanded: threshold = .alwaysHidden
        case .all: threshold = nil
        }
        let hidden = Set(levels.filter { threshold != nil && $0.value.rawValue >= threshold!.rawValue }.keys)
        guard !hidden.isEmpty else {
            bridge.release()
            return
        }
        let own = Bundle.main.bundleIdentifier ?? "fr.gfryptr.notchless"
        let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        let allowed = Set(running).union(Self.alwaysAllowed).union([own]).subtracting(hidden)
        bridge.restrict(allowing: allowed.sorted())
    }

    // MARK: - Liste des apps pour les réglages

    struct AppRow: Identifiable {
        let id: String
        let name: String
        let icon: NSImage?
        let isMenuBarApp: Bool
        let isRunning: Bool
    }

    /// Apps en cours (celles de la barre des menus d'abord) et apps déjà masquées mais fermées.
    func appRows() -> [AppRow] {
        let own = Bundle.main.bundleIdentifier
        var rows: [String: AppRow] = [:]
        for app in NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier, id != own, !Self.alwaysAllowed.contains(id),
                  app.activationPolicy != .prohibited || levels[id] != nil,
                  showSystemProcesses || levels[id] != nil || Self.isUserApp(app) else { continue }
            rows[id] = AppRow(id: id, name: app.localizedName ?? id, icon: app.icon,
                              isMenuBarApp: app.activationPolicy == .accessory, isRunning: true)
        }
        for id in levels.keys where rows[id] == nil {
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            let name = url.map { FileManager.default.displayName(atPath: $0.path) } ?? id
            rows[id] = AppRow(id: id, name: name, icon: url.map { NSWorkspace.shared.icon(forFile: $0.path) },
                              isMenuBarApp: true, isRunning: false)
        }
        return rows.values.sorted {
            if $0.isMenuBarApp != $1.isMenuBarApp { return $0.isMenuBarApp }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Une app installée par l'utilisateur (Applications), pas un agent du système
    /// (Core Location, gestionnaire de fenêtres…) ni un processus d'aide sans icône.
    private static func isUserApp(_ app: NSRunningApplication) -> Bool {
        guard let path = app.bundleURL?.path, path.hasSuffix(".app") else { return false }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let inApplications = path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/")
        // Les apps imbriquées dans une autre (assistants, agents de mise à jour) sont écartées.
        let nested = path.dropLast(4).contains(".app/")
        return inApplications && !nested
    }

    /// Demande l'autorisation Accessibilité (pour réorganiser les icônes).
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Ouverture au démarrage

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Notch Less : ouverture au démarrage impossible: \(error)")
            }
        }
    }
}
