import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller = HidingController.shared
    @ObservedObject private var refresh = RefreshTicker()
    @ObservedObject var order = MenuBarOrder.shared

    var body: some View {
        let rows = controller.appRows()
        Form {
            if !controller.isAvailable {
                Text("Le masquage n'est pas disponible sur cette version de macOS.")
                    .foregroundStyle(.red)
            }
            Section {
                ForEach(rows.filter(\.isMenuBarApp)) { row($0) }
            } header: {
                Text("Apps de la barre des menus")
            } footer: {
                Text("« Masquée » : cachée, un clic sur l'icône Notch Less (le disque) la montre. « Toujours masquée » : il faut un double-clic (ou ⌥-clic).")
            }
            Section("Autres apps ouvertes") {
                ForEach(rows.filter { !$0.isMenuBarApp }) { row($0) }
            }
            Section {
                if !order.trusted {
                    HStack {
                        Text("Autorise l'Accessibilité pour réorganiser les icônes.")
                        Spacer()
                        Button("Autoriser") { HidingController.requestAccessibility() }
                    }
                } else if order.items.isEmpty {
                    Button("Afficher l'ordre actuel") { order.refresh() }
                } else {
                    ForEach(Array(order.items.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 10) {
                            if let icon = item.icon { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                            Text(item.name).lineLimit(1)
                            Spacer()
                            Button { order.move(item, by: -1) } label: { Image(systemName: "chevron.left") }
                                .disabled(index == 0 || order.busy)
                                .help("Vers la gauche")
                            Button { order.move(item, by: 1) } label: { Image(systemName: "chevron.right") }
                                .disabled(index == order.items.count - 1 || order.busy)
                                .help("Vers la droite")
                        }
                        .buttonStyle(.borderless)
                    }
                    Button("Actualiser") { order.refresh() }.disabled(order.busy)
                }
            } header: {
                Text("Ordre dans la barre des menus")
            } footer: {
                Text("De gauche à droite. Toute la barre est dépliée le temps de réorganiser ; certaines icônes système (heure, Centre de contrôle) restent fixes.")
            }

            Section("Général") {
                Picker("Replier automatiquement", selection: $controller.autoCollapseSeconds) {
                    Text("Jamais").tag(0)
                    Text("Après 5 s").tag(5)
                    Text("Après 10 s").tag(10)
                    Text("Après 30 s").tag(30)
                    Text("Après 1 min").tag(60)
                }
                Toggle("Ouvrir au démarrage de la session", isOn: $controller.launchAtLogin)
                Toggle("Afficher aussi les processus système", isOn: $controller.showSystemProcesses)
            }
        }
        .formStyle(.grouped)
        .onAppear { refresh.start() }
        .onDisappear { refresh.stop() }
        .frame(width: 460, height: 560)
    }

    private func row(_ app: HidingController.AppRow) -> some View {
        HStack(spacing: 10) {
            if let icon = app.icon {
                Image(nsImage: icon).resizable().frame(width: 20, height: 20)
            }
            Text(app.name).foregroundStyle(app.isRunning ? .primary : .secondary)
            Spacer()
            Picker("", selection: Binding(
                get: { controller.level(of: app.id) },
                set: { controller.setLevel($0, for: app.id) }
            )) {
                ForEach(HideLevel.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

/// Rafraîchit la liste des apps ouvertes, seulement tant que la fenêtre est visible.
final class RefreshTicker: ObservableObject {
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
