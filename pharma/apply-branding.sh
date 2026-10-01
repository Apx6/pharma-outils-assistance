#!/usr/bin/env bash
# Remplace les icônes et logos RustDesk par ceux de Pharma-Outils (Windows et macOS).
# À lancer à la racine du dépôt rustdesk (fork), avant la compilation.
# Les visuels sont générés par client/branding/generate.py (dépôt « RustDesk outils »).
set -euo pipefail

B="pharma/branding"

# source -> destination
MAP=(
  # Icône de l'exe principal (Flutter) et de librustdesk / exe portable / MSI
  "icon.ico            flutter/windows/runner/resources/app_icon.ico"
  "icon.ico            res/icon.ico"
  # Zone de notification
  "tray-icon.ico       res/tray-icon.ico"
  # Interface Flutter : icône, logo de l'écran d'accueil (clair/sombre),
  # icône des raccourcis et du panneau « Programmes » (client personnalisé)
  "icon-256.png        flutter/assets/icon.png"
  "icon.svg            flutter/assets/icon.svg"
  "icon.ico            flutter/assets/icon.ico"
  "logo_light.png      flutter/assets/logo_light.png"
  "logo_dark.png       flutter/assets/logo_dark.png"
  "logo_light.png      flutter/assets/logo.png"
  # Icônes génériques (lanceur Flutter, paquets Linux)
  "icon-1024.png       res/icon.png"
  "icon-32.png         res/32x32.png"
  "icon-64.png         res/64x64.png"
  "icon-128.png        res/128x128.png"
  "icon-256.png        res/128x128@2x.png"
  # Fenêtre d'extraction de l'exe portable
  "label.png           libs/portable/src/res/label.png"
  # macOS : icône de l'app et de la barre des menus (image « template »)
  "AppIcon.icns        flutter/macos/Runner/AppIcon.icns"
  "mac-icon.png        res/mac-icon.png"
  "mac-tray-x2.png     res/mac-tray-dark-x2.png"
  "mac-tray-x2.png     res/mac-tray-light-x2.png"
  # Installeur MSI (bandeau et écran d'accueil)
  "WixUIBannerBmp.bmp  res/msi/Package/Resources/WixUIBannerBmp.bmp"
  "WixUIDialogBmp.bmp  res/msi/Package/Resources/WixUIDialogBmp.bmp"
)

for entry in "${MAP[@]}"; do
  read -r src dst <<<"$entry"
  [ -f "$B/$src" ] || { echo "ÉCHEC : $B/$src introuvable" >&2; exit 1; }
  mkdir -p "$(dirname "$dst")"
  cp "$B/$src" "$dst"
  echo "  $src -> $dst"
done

# Couleurs de la fenêtre d'extraction de l'exe portable (gris-violet RustDesk -> nuit pharma-outils)
UI="libs/portable/src/ui.rs"
sed -i.bak \
  -e 's/^const BG_COLOR: \[u8; 3\] = \[.*\];/const BG_COLOR: [u8; 3] = [12, 32, 25];/' \
  -e 's/^const BORDER_COLOR: \[u8; 3\] = \[.*\];/const BORDER_COLOR: [u8; 3] = [30, 71, 54];/' \
  "$UI"
rm -f "$UI.bak"
grep -q "BG_COLOR: \[u8; 3\] = \[12, 32, 25\]" "$UI" || { echo "ÉCHEC : BG_COLOR non modifié dans $UI" >&2; exit 1; }

# Propriétés des fichiers (Propriétés → Détails) : exe principal, librustdesk.dll, exe portable
python3 pharma/set-file-metadata.py

echo "OK : visuels Pharma-Outils appliqués"
