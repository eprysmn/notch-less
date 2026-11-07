#!/bin/zsh
# Signe un .app (et ses bibliothèques) avec l'identité locale stable de la suite.
# Une signature « ad hoc » change à chaque compilation : macOS oublie alors les
# autorisations (Accessibilité…). Avec un certificat fixe, elles sont conservées.
# Usage : sign.sh <chemin.app> [fichiers à signer avant l'app…]
set -euo pipefail
APP="$1"; shift
ARGS=(--force -s -)
# Les dossiers synchronisés (Documents, iCloud) remettent sans cesse des attributs étendus que
# codesign refuse : on signe une copie hors synchronisation, puis on la remet en place.
ORIG="$APP"
WORK=$(mktemp -d)
ditto --norsrc --noextattr "$ORIG" "$WORK/$(basename "$ORIG")"
APP="$WORK/$(basename "$ORIG")"
xattr -cr "$APP"
for f in "$@"; do codesign "${ARGS[@]}" "$APP/${f#$ORIG/}"; done
codesign "${ARGS[@]}" --deep "$APP"
rm -rf "$ORIG"
ditto --norsrc --noextattr "$APP" "$ORIG"
rm -rf "$WORK"
