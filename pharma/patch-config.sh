#!/usr/bin/env bash
# Intègre le serveur, la clé et le nom d'application de pharma-outils.fr dans le client RustDesk.
# À lancer à la racine du dépôt rustdesk (fork), après `git submodule update --init`.
#
# Usage : RS_PUB_KEY="xxxx=" ./patch-config.sh
# Variables optionnelles : RENDEZVOUS_SERVER, APP_NAME
set -euo pipefail

SERVER="${RENDEZVOUS_SERVER:-support.pharma-outils.fr}"
KEY="${RS_PUB_KEY:?Définir RS_PUB_KEY (contenu de /opt/rustdesk/data/id_ed25519.pub)}"
# Sans espace : sert aussi aux noms de dossiers de config et de service Windows.
# Un nom différent de "RustDesk" fait du client un « custom client » : il ne propose plus
# de mise à jour vers le RustDesk officiel (qui pointerait vers les serveurs publics).
NAME="${APP_NAME:-PharmaOutils}"
CFG="libs/hbb_common/src/config.rs"

[ -f "$CFG" ] || { echo "Introuvable : $CFG (submodules initialisés ?)" >&2; exit 1; }
[[ "$NAME" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "APP_NAME invalide : lettres, chiffres, - et _ uniquement" >&2; exit 1; }

sed -i.bak \
  -e "s|^pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[.*\];|pub const RENDEZVOUS_SERVERS: \&[\&str] = \&[\"${SERVER}\"];|" \
  -e "s|^pub const RS_PUB_KEY: &str = \".*\";|pub const RS_PUB_KEY: \&str = \"${KEY}\";|" \
  -e "s|\(pub static ref APP_NAME: RwLock<String> = RwLock::new(\)\"RustDesk\"|\1\"${NAME}\"|" \
  -e "s|\(pub static ref PROD_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new(\)\"[^\"]*\"|\1\"${SERVER}\"|" \
  -e 's|^\(    pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = \)Default::default();|\1RwLock::new(HashMap::from([("hide-server-settings".to_owned(), "Y".to_owned())]));|' \
  -e 's|^\(    pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = \)Default::default();|\1RwLock::new(HashMap::from([("disable-account".to_owned(), "Y".to_owned())]));|' \
  "$CFG"
rm -f "$CFG.bak"

# Vérification : échoue si un remplacement n'a pas eu lieu (format du fichier changé en amont)
grep -q "RENDEZVOUS_SERVERS: &\[&str\] = &\[\"${SERVER}\"\];" "$CFG" || { echo "ÉCHEC : RENDEZVOUS_SERVERS non modifié" >&2; exit 1; }
grep -q "RS_PUB_KEY: &str = \"${KEY}\";" "$CFG"                       || { echo "ÉCHEC : RS_PUB_KEY non modifié" >&2; exit 1; }
grep -q "APP_NAME: RwLock<String> = RwLock::new(\"${NAME}\"" "$CFG"    || { echo "ÉCHEC : APP_NAME non modifié" >&2; exit 1; }
# Serveur « maison » compilé : sans lui, RustDesk se croit sur le serveur public (message
# « mettez en place votre propre serveur », qualité/FPS bridés en relais : client.rs, dialog.dart)
grep -q "PROD_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new(\"${SERVER}\"" "$CFG" || { echo "ÉCHEC : PROD_RENDEZVOUS_SERVER non modifié" >&2; exit 1; }
# Réglages intégrés : masque l'écran « Serveur ID/relais » (personne ne peut changer de serveur)
grep -q 'BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from(\[("hide-server-settings"' "$CFG" || { echo "ÉCHEC : BUILTIN_SETTINGS non modifié" >&2; exit 1; }
# Pas de serveur d'API (compte, carnet d'adresses) : on masque compte, carnet d'adresses et
# « Appareils accessibles » (peer_tab_model.dart, desktop_setting_page.dart). Les Favoris restent.
grep -q 'HARD_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from(\[("disable-account"' "$CFG" || { echo "ÉCHEC : HARD_SETTINGS non modifié" >&2; exit 1; }
if grep -q "rs-ny.rustdesk.com" "$CFG"; then echo "ÉCHEC : serveur public RustDesk encore présent" >&2; exit 1; fi

echo "OK : client « ${NAME} » configuré pour ${SERVER}"
