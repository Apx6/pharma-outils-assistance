#!/usr/bin/env bash
# Signature Developer ID + notarisation Apple de PharmaOutils.app (exécuté par GitHub Actions).
#
#   sign-macos.sh keychain            # importe le certificat dans un trousseau temporaire
#   sign-macos.sh app <App.app>       # signe le bundle (de l'intérieur vers l'extérieur)
#   sign-macos.sh dmg <fichier.dmg>   # signe, notarise et agrafe (staple) le .dmg
#   sign-macos.sh cleanup             # supprime trousseau et clés temporaires
#
# Variables d'environnement (secrets GitHub) :
#   APPLE_CERT_P12_BASE64, APPLE_CERT_PASSWORD           certificat « Developer ID Application »
#   APPLE_API_KEY_P8_BASE64, APPLE_API_KEY_ID,
#   APPLE_API_ISSUER_ID                                  clé API App Store Connect (notarisation)
#   APPLE_SIGNING_IDENTITY (facultatif)                  sinon déduite du certificat
set -euo pipefail

TMP="${RUNNER_TEMP:-/tmp}/pharma-signing"
KEYCHAIN="$TMP/signing.keychain-db"
ENTITLEMENTS="flutter/macos/Runner/Release.entitlements"

die() { echo "ÉCHEC : $*" >&2; exit 1; }

identity() {
  if [ -n "${APPLE_SIGNING_IDENTITY:-}" ]; then echo "$APPLE_SIGNING_IDENTITY"; return; fi
  local id
  id=$(security find-identity -v -p codesigning "$KEYCHAIN" | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
  [ -n "$id" ] || die "aucune identité « Developer ID Application » dans le certificat fourni"
  echo "$id"
}

cmd_keychain() {
  : "${APPLE_CERT_P12_BASE64:?}" "${APPLE_CERT_PASSWORD:?}"
  mkdir -p "$TMP"
  local kpw
  kpw=$(openssl rand -hex 24)
  security create-keychain -p "$kpw" "$KEYCHAIN"
  security set-keychain-settings -lut 21600 "$KEYCHAIN"
  security unlock-keychain -p "$kpw" "$KEYCHAIN"

  printf '%s' "$APPLE_CERT_P12_BASE64" | base64 --decode > "$TMP/cert.p12"
  security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$APPLE_CERT_PASSWORD" -T /usr/bin/codesign
  rm -f "$TMP/cert.p12"

  # Autorité intermédiaire Developer ID (G2), au cas où le runner ne l'aurait pas
  curl -fsSL https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer -o "$TMP/DeveloperIDG2CA.cer"
  security import "$TMP/DeveloperIDG2CA.cer" -k "$KEYCHAIN" >/dev/null 2>&1 || true

  security set-key-partition-list -S apple-tool:,apple: -s -k "$kpw" "$KEYCHAIN" >/dev/null
  # shellcheck disable=SC2046
  security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
  echo "Identité : $(identity)"
}

sign() { codesign --force --options runtime --timestamp --keychain "$KEYCHAIN" -s "$ID" "$@"; }

cmd_app() {
  local APP="${1:?chemin de l.app}"
  [ -d "$APP" ] || die "$APP introuvable"
  ID=$(identity)

  # 1. Bibliothèques et exécutables isolés dans Frameworks (liblibrustdesk.dylib…)
  find "$APP/Contents/Frameworks" -maxdepth 1 -type f \( -name "*.dylib" -o -perm -u+x \) -print0 |
    while IFS= read -r -d '' f; do echo "  signe $f"; sign "$f"; done
  # 2. Frameworks (Flutter, plugins)
  find "$APP/Contents/Frameworks" -maxdepth 1 -type d -name "*.framework" -print0 |
    while IFS= read -r -d '' f; do echo "  signe $f"; sign "$f"; done
  # 3. Exécutables secondaires (binaire « service » du serveur RustDesk)
  find "$APP/Contents/MacOS" -type f -perm -u+x ! -name "$(basename "$APP" .app)" -print0 |
    while IFS= read -r -d '' f; do echo "  signe $f"; sign "$f"; done
  # 4. L'application, avec ses entitlements (micro, réseau…)
  echo "  signe $APP"
  sign --entitlements "$ENTITLEMENTS" "$APP"

  codesign --verify --deep --strict --verbose=2 "$APP"
  codesign -dv --verbose=2 "$APP" 2>&1 | grep -E "^(Authority|TeamIdentifier|Runtime)" || true
}

cmd_dmg() {
  local DMG="${1:?chemin du .dmg}"
  : "${APPLE_API_KEY_P8_BASE64:?}" "${APPLE_API_KEY_ID:?}" "${APPLE_API_ISSUER_ID:?}"
  ID=$(identity)
  sign "$DMG"

  mkdir -p "$TMP"
  printf '%s' "$APPLE_API_KEY_P8_BASE64" | base64 --decode > "$TMP/AuthKey.p8"

  echo "Notarisation (quelques minutes)…"
  local out status sub
  out=$(xcrun notarytool submit "$DMG" --key "$TMP/AuthKey.p8" --key-id "$APPLE_API_KEY_ID" \
        --issuer "$APPLE_API_ISSUER_ID" --wait --timeout 45m --output-format json)
  echo "$out"
  status=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))')
  sub=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))')
  if [ "$status" != "Accepted" ]; then
    [ -n "$sub" ] && xcrun notarytool log "$sub" --key "$TMP/AuthKey.p8" \
      --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID" || true
    die "notarisation refusée (statut : ${status:-inconnu})"
  fi

  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  spctl --assess --type open --context context:primary-signature -vv "$DMG"
}

cmd_cleanup() {
  security delete-keychain "$KEYCHAIN" 2>/dev/null || true
  rm -rf "$TMP"
}

case "${1:-}" in
  keychain) cmd_keychain ;;
  app) shift; cmd_app "$@" ;;
  dmg) shift; cmd_dmg "$@" ;;
  cleanup) cmd_cleanup ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac
