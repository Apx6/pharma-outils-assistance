#!/usr/bin/env python3
"""Remplace les propriétés Windows des binaires (clic droit → Propriétés → Détails).

Trois sources dans RustDesk 1.4.9 :
  - flutter/windows/runner/Runner.rc        → exe principal (PharmaOutils.exe)
  - Cargo.toml [package.metadata.winres]    → librustdesk.dll
  - libs/portable/Cargo.toml (idem)         → exe portable téléchargé par les pharmacies

À lancer à la racine du dépôt rustdesk. Échoue si une valeur attendue est introuvable
(format modifié en amont). Les mentions de copyright RustDesk sont conservées (AGPL-3.0).
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
COMPANY = os.environ.get("COMPANY_NAME", "Holding Dioux")
PRODUCT = os.environ.get("PRODUCT_NAME", "Pharma-Outils Assistance")
DESCRIPTION = os.environ.get("FILE_DESCRIPTION", "Pharma-Outils Assistance à distance")
PORTABLE_FILENAME = os.environ.get("PORTABLE_FILENAME", "pharma-outils-assistance.exe")
YEAR = datetime.date.today().year
COPYRIGHT = (
    f"© {YEAR} {COMPANY}. Basé sur RustDesk, "
    "Copyright © Purslane Tech Pte. Ltd. (AGPL-3.0)"
)

errors = []


def sub_one(text: str, pattern: str, repl: str, label: str) -> str:
    new, n = re.subn(pattern, lambda m: m.group(1) + repl + m.group(2), text, flags=re.M)
    if n != 1:
        errors.append(f"{label} : {n} occurrence(s) au lieu de 1")
    return new


def patch_rc(path: Path):
    t = path.read_text(encoding="utf-8")
    values = {
        "CompanyName": COMPANY,
        "FileDescription": DESCRIPTION,
        "InternalName": APP_NAME,
        "LegalCopyright": COPYRIGHT,
        "OriginalFilename": f"{APP_NAME}.exe",
        "ProductName": PRODUCT,
    }
    for key, val in values.items():
        t = sub_one(t, rf'^(\s*VALUE "{key}", ")[^"]*(" "\\0")', val, f"{path}:{key}")
    path.write_text(t, encoding="utf-8")


def patch_winres(path: Path, original_filename: str):
    t = path.read_text(encoding="utf-8")
    block = re.search(r"^\[package\.metadata\.winres\]\n(?:(?!\[).*\n)*", t, flags=re.M)
    if not block:
        errors.append(f"{path} : section [package.metadata.winres] introuvable")
        return
    b = block.group(0)
    values = {
        "LegalCopyright": COPYRIGHT,
        "ProductName": PRODUCT,
        "FileDescription": DESCRIPTION,
        "OriginalFilename": original_filename,
    }
    for key, val in values.items():
        b = sub_one(b, rf'^({key} = ")[^"]*(")', val, f"{path}:{key}")
    if "CompanyName" not in b:
        b = b.rstrip("\n") + f'\nCompanyName = "{COMPANY}"\n'
    t = t[: block.start()] + b + t[block.end():]
    path.write_text(t, encoding="utf-8")


def main():
    for v in (COMPANY, PRODUCT, DESCRIPTION, COPYRIGHT):
        if '"' in v or "\\" in v:
            sys.exit(f"Valeur invalide (guillemet ou antislash interdit) : {v}")

    patch_rc(Path("flutter/windows/runner/Runner.rc"))
    patch_winres(Path("Cargo.toml"), f"{APP_NAME}.exe")
    patch_winres(Path("libs/portable/Cargo.toml"), PORTABLE_FILENAME)

    if errors:
        print("ÉCHEC :", *errors, sep="\n  ", file=sys.stderr)
        sys.exit(1)
    print(f"OK : propriétés des fichiers → {PRODUCT} / {COMPANY}")


if __name__ == "__main__":
    main()
