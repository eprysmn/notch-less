import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = HidingController.shared
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UpdateCheck.shared.start(for: .less)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        menu.delegate = self

        controller.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.updateIcon(state) }
            .store(in: &cancellables)

        // Premier lancement : rien n'est encore masqué, on montre où choisir.
        let firstSetup = { [weak self] in
            if HidingController.shared.levels.isEmpty { self?.openSettings() }
        }
        if UserDefaults.standard.bool(forKey: "welcomeShown") { firstSetup() }
        Welcome.showIfNeeded(appName: "Notch Less", features: [
            WelcomeFeature(symbol: "circle.fill", title: "Une barre des menus rangée",
                           text: "Choisis les icônes à masquer. Un clic sur le disque les montre, un double-clic montre tout."),
            WelcomeFeature(symbol: "eye.slash", title: "Masquées ou toujours masquées",
                           text: "Les icônes « toujours masquées » ne réapparaissent qu'au double-clic."),
            WelcomeFeature(symbol: "arrow.left.arrow.right", title: "Réorganiser",
                           text: "Change l'ordre des icônes depuis les réglages, sans ⌘-glisser dans la barre."),
        ], permissions: [
            WelcomePermission(symbol: "hand.raised", title: "Accessibilité",
                              text: "Uniquement pour réorganiser les icônes de la barre des menus.",
                              isGranted: { AXIsProcessTrusted() },
                              request: { HidingController.requestAccessibility() }),
        ], then: firstSetup)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.releaseAll()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    private func updateIcon(_ state: HidingController.State) {
        statusItem.button?.image = SuiteIcons.notchLess(state == .collapsed ? .collapsed : state == .expanded ? .expanded : .all)
    }

    /// Clic : montrer/cacher. Double-clic ou ⌥-clic : tout montrer. Clic droit ou ⌃-clic : menu.
    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            controller.handleClick(doubleClick: (event?.clickCount ?? 1) >= 2,
                                   option: event?.modifierFlags.contains(.option) == true)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if !controller.isAvailable {
            let item = NSMenuItem(title: L("Masquage indisponible sur cette version de macOS"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(.separator())
        }
        let count = controller.levels.count
        let summary = NSMenuItem(title: count == 0 ? L("Aucune app masquée")
                                    : count == 1 ? L("1 app masquée") : String(format: L("%d apps masquées"), count),
                                 action: nil, keyEquivalent: "")
        summary.isEnabled = false
        menu.addItem(summary)
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Choisir les apps à masquer…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(UpdateCheck.shared.menuItem())
        menu.addItem(SuiteMenu.item(for: .less))
        menu.addItem(withTitle: L("Quitter Notch Less"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = L("Notch Less")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
