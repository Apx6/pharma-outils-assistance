#!/usr/bin/env python3
"""Renomme l'application macOS : RustDesk.app -> PharmaOutils.app.

Le code macOS de RustDesk attend /Applications/<APP_NAME>.app/Contents/MacOS/<APP_NAME>
(installation du service, mises à jour, autorisations) et lit l'identifiant de bundle
à l'exécution : il suffit donc d'aligner le projet Xcode sur APP_NAME.

  - flutter/macos/Runner/Configs/AppInfo.xcconfig : PRODUCT_NAME, PRODUCT_COPYRIGHT
  - flutter/macos/Runner.xcodeproj/project.pbxproj : PRODUCT_BUNDLE_IDENTIFIER
  - build.py : chemin du bundle où est copié le binaire `service`

À lancer à la racine du dépôt rustdesk, après patch-config.sh. Échoue si une valeur
attendue est introuvable (format modifié en amont).
"""
import datetime
import os
import re
import sys
from pathlib import Path

# La console Windows des runners GitHub est en cp1252 : forcer l'UTF-8 pour les messages.
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

APP_NAME = os.environ.get("APP_NAME", "PharmaOutils")
BUNDLE_ID = os.environ.get("MACOS_BUNDLE_ID", "fr.pharmaoutils.assistance")
COMPANY = os.environ.get("COMPANY_NAME", "Holding Dioux")
YEAR = datetime.date.today().year
COPYRIGHT = f"© {YEAR} {COMPANY}. Basé sur RustDesk, Copyright © Purslane Tech Pte. Ltd. (AGPL-3.0)"

errors = []


def patch(path: str, pattern: str, repl: str, expected: int, label: str):
    p = Path(path)
    t = p.read_text(encoding="utf-8")
    new, n = re.subn(pattern, repl, t, flags=re.M)
    if n != expected:
        if n == 0 and _already(t, label):  # relance du script : déjà appliqué
            return
        errors.append(f"{path} : {label} — {n} remplacement(s) au lieu de {expected}")
        return
    p.write_text(new, encoding="utf-8")


def _already(text: str, label: str) -> bool:
    return {
        "PRODUCT_NAME": f"PRODUCT_NAME = {APP_NAME}\n" in text,
        "PRODUCT_COPYRIGHT": f"PRODUCT_COPYRIGHT = {COPYRIGHT}\n" in text,
        "PRODUCT_BUNDLE_IDENTIFIER": f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};" in text,
        "service": f"Release/{APP_NAME}.app/Contents/MacOS/" in text,
    }.get(label, False)


def main():
    if not re.fullmatch(r"[A-Za-z0-9_-]+", APP_NAME):
        sys.exit(f"APP_NAME invalide : {APP_NAME}")
    if not re.fullmatch(r"[A-Za-z0-9.-]+", BUNDLE_ID):
        sys.exit(f"MACOS_BUNDLE_ID invalide : {BUNDLE_ID}")

    xc = "flutter/macos/Runner/Configs/AppInfo.xcconfig"
    patch(xc, r"^PRODUCT_NAME = .*$", f"PRODUCT_NAME = {APP_NAME}", 1, "PRODUCT_NAME")
    patch(xc, r"^PRODUCT_COPYRIGHT = .*$", f"PRODUCT_COPYRIGHT = {COPYRIGHT}", 1, "PRODUCT_COPYRIGHT")

    # Les 3 configurations (Debug, Profile, Release) de la cible Runner
    patch("flutter/macos/Runner.xcodeproj/project.pbxproj",
          r"PRODUCT_BUNDLE_IDENTIFIER = com\.carriez\.rustdesk;",
          f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};", 3, "PRODUCT_BUNDLE_IDENTIFIER")

    patch("build.py",
          r"Release/RustDesk\.app/Contents/MacOS/",
          f"Release/{APP_NAME}.app/Contents/MacOS/", 1, "service")

    if errors:
        print("ÉCHEC :", *errors, sep="\n  ", file=sys.stderr)
        sys.exit(1)
    print(f"OK : application macOS « {APP_NAME}.app » ({BUNDLE_ID})")


if __name__ == "__main__":
    main()
