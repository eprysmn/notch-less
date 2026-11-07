import Foundation

/// Traduit un texte affiché ailleurs que dans un texte littéral SwiftUI (menus, libellés calculés).
/// La clé est le texte français, langue de base ; l'anglais vit dans en.lproj/Localizable.strings.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
