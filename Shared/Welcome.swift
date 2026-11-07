import AppKit
import SwiftUI
import ServiceManagement

/// Écran d'accueil commun aux trois apps, à la manière des écrans « Bienvenue » d'Apple :
/// icône, titre, trois points clés, autorisations expliquées, ouverture au démarrage, Continuer.
struct WelcomeFeature: Identifiable {
    let symbol: String
    let title: String
    let text: String
    var id: String { title }
}

struct WelcomePermission: Identifiable {
    let symbol: String
    let title: String
    let text: String
    /// nil : accordée à la première utilisation, rien à faire maintenant.
    let isGranted: (() -> Bool)?
    let request: (() -> Void)?
    var id: String { title }
}

final class WelcomeState: ObservableObject {
    @Published var launchAtLogin = true
    @Published var tick = 0
    private var timer: Timer?

    /// Rafraîchit l'état des autorisations pendant que la fenêtre est ouverte.
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick += 1 }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

struct WelcomeView: View {
    let appName: String
    let features: [WelcomeFeature]
    let permissions: [WelcomePermission]
    let onContinue: (Bool) -> Void
    @ObservedObject var state: WelcomeState

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
                Text("Bienvenue dans \(appName)").font(.system(size: 26, weight: .bold))
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(features) { f in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: f.symbol).font(.system(size: 22)).foregroundStyle(Color.accentColor)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L(f.title)).font(.headline)
                            Text(L(f.text)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !permissions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Autorisations").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(permissions) { p in permissionRow(p) }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
            }

            Toggle("Ouvrir au démarrage de la session", isOn: $state.launchAtLogin)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { onContinue(state.launchAtLogin) } label: {
                Text("Continuer").frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 460)
        .onAppear { state.start() }
        .onDisappear { state.stop() }
    }

    private func permissionRow(_ p: WelcomePermission) -> some View {
        let granted = p.isGranted?() ?? false
        _ = state.tick
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: p.symbol).font(.system(size: 16)).frame(width: 22).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(L(p.title)).font(.callout.weight(.medium))
                Text(L(p.text)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if p.isGranted == nil {
                Text("Au besoin").font(.caption).foregroundStyle(.secondary)
            } else if granted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if let request = p.request {
                Button("Autoriser", action: request).controlSize(.small)
            }
        }
    }
}

enum Welcome {
    private static var window: NSWindow?
    private static let state = WelcomeState()

    /// Affiche l'accueil au premier lancement ; `then` est appelé après « Continuer ».
    static func showIfNeeded(appName: String, features: [WelcomeFeature], permissions: [WelcomePermission] = [],
                             then: (() -> Void)? = nil) {
        let key = "welcomeShown"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let view = WelcomeView(appName: appName, features: features, permissions: permissions, onContinue: { launch in
            UserDefaults.standard.set(true, forKey: key)
            if launch { try? SMAppService.mainApp.register() }
            window?.close()
            window = nil
            then?()
        }, state: state)
        let w = NSWindow(contentViewController: NSHostingController(rootView: view))
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isReleasedWhenClosed = false
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}
