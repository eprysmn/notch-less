import Foundation

// Pont vers MenuBarClientCore.framework (privé, macOS 27).
// Depuis macOS 27, la barre des menus est dessinée par MenuBarAgent, qui accepte une
// restriction « n'afficher que ces éléments système et ces apps » (celle du mode examen).
// Technique reprise de MenuBarHider de Saveliy Yudin (licence MIT) :
// https://github.com/happy666End/MenuBarHider

@objc private protocol AssessmentModeAssertion {
    @objc(activateWithConfiguration:completionHandler:)
    func activate(with configuration: AnyObject, completionHandler: @escaping (NSError?) -> Void)
    func invalidate()
}

final class MenuBarAgentBridge {
    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore"
    private static let configurationInit = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
    /// Identifiants des éléments système (0 batterie, 1 Bluetooth, 2 horloge, … 8 Centre de contrôle).
    /// Plage large pour garder visibles ceux qu'ajouteraient de futures versions.
    private static let systemItems = (0..<64).map { NSNumber(value: $0) } as NSArray

    private let classes: (assertion: NSObject.Type, configuration: NSObject.Type)?
    private var active: AssessmentModeAssertion?
    private var pending: AssessmentModeAssertion?
    private(set) var appliedAllowList: [String]?

    init() {
        // Chaque sélecteur est vérifié : un envoi non vérifié planterait au lieu de se dégrader.
        guard dlopen(Self.frameworkPath, RTLD_NOW) != nil,
              let assertion = NSClassFromString("MBAssessmentModeAssertion") as? NSObject.Type,
              let configuration = NSClassFromString("MBAssessmentModeConfiguration") as? NSObject.Type,
              assertion.instancesRespond(to: #selector(AssessmentModeAssertion.activate(with:completionHandler:))),
              assertion.instancesRespond(to: #selector(AssessmentModeAssertion.invalidate)),
              configuration.instancesRespond(to: Self.configurationInit)
        else {
            classes = nil
            return
        }
        classes = (assertion, configuration)
    }

    var isAvailable: Bool { classes != nil }

    /// N'affiche que les apps listées (plus les éléments système). L'ancienne restriction
    /// n'est retirée qu'une fois la nouvelle en place, pour éviter tout clignotement.
    func restrict(allowing bundleIDs: [String]) {
        guard let classes, appliedAllowList != bundleIDs else { return }
        let allocated = (classes.configuration as AnyObject).perform(NSSelectorFromString("alloc"))?.takeUnretainedValue()
        guard let configuration = allocated?.perform(Self.configurationInit, with: Self.systemItems,
                                                     with: bundleIDs as NSArray)?.takeRetainedValue()
        else { return }

        pending?.invalidate()
        let assertion = unsafeBitCast(classes.assertion.init(), to: AssessmentModeAssertion.self)
        pending = assertion
        assertion.activate(with: configuration) { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.pending === assertion else { return }
                self.pending = nil
                if let error {
                    assertion.invalidate()
                    NSLog("Notch Less : restriction refusée: \(error.localizedDescription)")
                } else {
                    self.active?.invalidate()
                    self.active = assertion
                    self.appliedAllowList = bundleIDs
                }
            }
        }
    }

    func release() {
        pending?.invalidate()
        pending = nil
        active?.invalidate()
        active = nil
        appliedAllowList = nil
    }
}
