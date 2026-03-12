#!/usr/bin/env bash
# =============================================================================
#  TOTEM KIOSK — Install Script v3.0
#  Repository: git@github.com:manuelpetrolo/kiosk-setup.git
#
#  Compatibile con:
#    - Ubuntu Desktop 24.04 LTS  x86_64  (PC)
#    - Ubuntu Desktop 24.04 LTS  ARM64   (Raspberry Pi 5)
#
#  Uso:
#    sudo bash install.sh
# =============================================================================

set -euo pipefail

# ── Colori ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()    { echo -e "  ${GREEN}✅ $1${NC}"; }
warn()  { echo -e "  ${YELLOW}⚠️  $1${NC}"; }
err()   { echo -e "  ${RED}❌ ERRORE: $1${NC}"; exit 1; }
info()  { echo -e "  ${BLUE}ℹ️  $1${NC}"; }
hdr()   { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
pause() { echo -e "  ${YELLOW}⏳ Attendo 5 secondi...${NC}"; sleep 5; }

# ── Config repository ─────────────────────────────────────────────────────────
GITHUB_USER="manuelpetrolo"
REPO_NAME="kiosk-setup"
REPO_SSH="git@github.com:${GITHUB_USER}/${REPO_NAME}.git"
REPO_DIR="/opt/kiosk-setup"
SSH_KEY="/root/.ssh/id_ed25519_kiosk"

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "\n${BLUE}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║        TOTEM KIOSK — INSTALLER v3.0             ║"
echo "  ║  github.com/manuelpetrolo/kiosk-setup           ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Controlli iniziali ────────────────────────────────────────────────────────
[ "$EUID" -eq 0 ] || err "Esegui come root: sudo bash install.sh"

# Rileva architettura
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" ]]; then
  IS_ARM=1
  info "Architettura: ARM64 (Raspberry Pi 5)"
  BROWSER_BIN="chromium-browser"
else
  IS_ARM=0
  info "Architettura: x86_64 (PC)"
  BROWSER_BIN="/snap/bin/chromium"
fi

# =============================================================================
# STEP 1 — Pacchetti base
# =============================================================================
hdr "STEP 1/10 — Installazione pacchetti base"
apt update -qq
apt install -y git curl openssh-client openssh-server \
  unclutter x11-xserver-utils xdotool -qq
ok "Pacchetti base installati"
pause

# =============================================================================
# STEP 2 — Chromium
# =============================================================================
hdr "STEP 2/10 — Installazione Chromium"
if [ "$IS_ARM" -eq 1 ]; then
  info "ARM64: installo chromium via apt..."
  apt install -y chromium-browser 2>/dev/null || \
  apt install -y chromium 2>/dev/null || \
  err "Impossibile installare Chromium su ARM"
  BROWSER_BIN=$(which chromium-browser 2>/dev/null || which chromium 2>/dev/null)
else
  info "x86_64: installo chromium via snap..."
  apt install -y snapd -qq
  if ! snap list chromium &>/dev/null; then
    snap install chromium
  fi
  BROWSER_BIN="/snap/bin/chromium"
fi
[ -x "$BROWSER_BIN" ] || err "Chromium non trovato: $BROWSER_BIN"
ok "Chromium installato: $BROWSER_BIN"
pause

# =============================================================================
# STEP 3 — SSH Key per GitHub
# =============================================================================
hdr "STEP 3/10 — Generazione SSH key per GitHub"

if [ ! -f "${SSH_KEY}" ]; then
  ssh-keygen -t ed25519 -C "kiosk-$(hostname)" -f "${SSH_KEY}" -N ""
  ok "SSH key generata: ${SSH_KEY}"
else
  warn "SSH key già esistente — riutilizzo quella esistente"
fi

# Configura SSH per usare questa key con GitHub
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat > /root/.ssh/config << EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ${SSH_KEY}
  StrictHostKeyChecking no
EOF
chmod 600 /root/.ssh/config

# Mostra la chiave pubblica e aspetta
echo ""
echo -e "${YELLOW}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║              🔑 AZIONE RICHIESTA — LEGGI ATTENTAMENTE       ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "  ${BOLD}COPIA questa chiave pubblica su GitHub:${NC}"
echo ""
echo -e "  ${CYAN}$(cat ${SSH_KEY}.pub)${NC}"
echo ""
echo -e "  ${BOLD}Poi segui questi passi:${NC}"
echo ""
echo "   1. Apri dal telefono o dal Mac:"
echo -e "      ${CYAN}https://github.com/${GITHUB_USER}/${REPO_NAME}/settings/keys${NC}"
echo ""
echo "   2. Clicca il pulsante verde  →  Add deploy key"
echo "   3. Title: kiosk-$(hostname)"
echo "   4. Key: incolla la chiave sopra"
echo "   5. Lascia 'Allow write access' NON selezionato"
echo "   6. Clicca  →  Add key"
echo ""
echo -e "  ${YELLOW}Poi torna qui e premi INVIO per continuare...${NC}"
echo ""
read -r

# Verifica connessione GitHub
info "Verifico connessione a GitHub..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  ok "Connessione GitHub verificata"
else
  warn "Verifica connessione non conclusiva — provo comunque a clonare"
fi
pause

# =============================================================================
# STEP 4 — Clone repository
# =============================================================================
hdr "STEP 4/10 — Download file da GitHub"

if [ -d "$REPO_DIR/.git" ]; then
  warn "Repository già presente — aggiorno"
  git -C "$REPO_DIR" pull
else
  git clone "$REPO_SSH" "$REPO_DIR"
fi
ok "File scaricati in $REPO_DIR"

# Verifica file essenziali
for f in files/content.js files/sw.js files/manifest.json \
          files/totem-kiosk-start.sh files/totem-display.sh; do
  [ -f "$REPO_DIR/$f" ] || err "File mancante nel repository: $f"
done
ok "Tutti i file necessari presenti"
pause

# =============================================================================
# STEP 5 — Parametri configurazione
# =============================================================================
hdr "STEP 5/10 — Configurazione kiosk"

# Leggi kiosk.env dal repo se presente
if [ -f "$REPO_DIR/config/kiosk.env" ]; then
  source "$REPO_DIR/config/kiosk.env"
  info "kiosk.env trovato nel repository — valori precaricati"
fi

read -rp "  → URL server (es. http://192.168.1.253:8000/) [${KIOSK_SERVER_URL:-}]: " input
KIOSK_SERVER_URL="${input:-${KIOSK_SERVER_URL:-http://192.168.1.253:8000/}}"

read -rp "  → Token kiosk [${KIOSK_TOKEN:-nessuno}]: " input
KIOSK_TOKEN="${input:-${KIOSK_TOKEN:-}}"

read -rp "  → Risoluzione schermo [1920x1080]: " input
SCREEN_RES="${input:-1920x1080}"
SCREEN_W="${SCREEN_RES%x*}"
SCREEN_H="${SCREEN_RES#*x}"

read -rp "  → Utente admin del sistema [$(logname 2>/dev/null || echo ubuntu)]: " input
ADMIN_USER="${input:-$(logname 2>/dev/null || echo ubuntu)}"

HOME_HOST=$(echo "$KIOSK_SERVER_URL" | sed 's|http[s]*://||' | sed 's|/.*||')
HOME_URL="${KIOSK_SERVER_URL}?token=${KIOSK_TOKEN}"

echo ""
echo -e "  Server   : ${CYAN}$KIOSK_SERVER_URL${NC}"
echo -e "  Host     : ${CYAN}$HOME_HOST${NC}"
echo -e "  Token    : ${CYAN}${KIOSK_TOKEN:-<nessuno>}${NC}"
echo -e "  Schermo  : ${CYAN}$SCREEN_RES${NC}"
echo -e "  Browser  : ${CYAN}$BROWSER_BIN${NC}"
echo ""
read -rp "  Confermi? [s/N]: " confirm
[[ "${confirm,,}" == "s" ]] || { echo "Annullato."; exit 0; }
pause

# =============================================================================
# STEP 6 — Utente kiosk
# =============================================================================
hdr "STEP 6/10 — Creazione utente kiosk"

if ! id kiosk &>/dev/null; then
  useradd -m -s /bin/bash kiosk
  echo "kiosk:kiosk123" | chpasswd
  ok "Utente kiosk creato (password temporanea: kiosk123)"
else
  warn "Utente kiosk già esistente — skip"
fi

EXTRA_GROUPS="video,audio,input,render"
[ "$IS_ARM" -eq 1 ] && EXTRA_GROUPS="${EXTRA_GROUPS},gpio"
usermod -aG "$EXTRA_GROUPS" kiosk 2>/dev/null || true
ok "Gruppi assegnati: $EXTRA_GROUPS"
pause

# =============================================================================
# STEP 7 — GDM3 autologin + kiosk.env
# =============================================================================
hdr "STEP 7/10 — Configurazione GDM3 e server"

cat > /etc/gdm3/custom.conf << EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=kiosk

[security]

[xdmcp]

[chooser]

[debug]
EOF
ok "GDM3 autologin configurato"

mkdir -p /etc/totem
cat > /etc/totem/kiosk.env << EOF
KIOSK_TOKEN=${KIOSK_TOKEN}
KIOSK_VERSION=kiosk-0.3.0
KIOSK_SERVER_URL=${KIOSK_SERVER_URL}
EOF
chmod 644 /etc/totem/kiosk.env
ok "kiosk.env creato in /etc/totem/"
pause

# =============================================================================
# STEP 8 — Script di sistema
# =============================================================================
hdr "STEP 8/10 — Installazione script di sistema"

cp "$REPO_DIR/files/totem-kiosk-start.sh" /usr/local/bin/
cp "$REPO_DIR/files/totem-display.sh"     /usr/local/bin/
cp "$REPO_DIR/files/totem-agent.sh"       /usr/local/bin/ 2>/dev/null || true


# ── totem-agent: systemd service + timer ─────────────────────────────────────
cat > /etc/systemd/system/totem-agent.service << 'EOF'
[Unit]
Description=Totem Kiosk Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/totem-agent.sh
StandardOutput=journal
StandardError=journal
EOF

cat > /etc/systemd/system/totem-agent.timer << 'EOF'
[Unit]
Description=Totem Kiosk Agent Timer

[Timer]
OnBootSec=30
OnUnitActiveSec=30
AccuracySec=5

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now totem-agent.timer
echo "[OK] totem-agent.timer attivo"

# Aggiorna browser path e risoluzione
sed -i "s|/snap/bin/chromium|${BROWSER_BIN}|g"         /usr/local/bin/totem-kiosk-start.sh
sed -i "s|/usr/bin/chromium-browser|${BROWSER_BIN}|g"  /usr/local/bin/totem-kiosk-start.sh
sed -i "s|1920,1080|${SCREEN_W},${SCREEN_H}|g"         /usr/local/bin/totem-kiosk-start.sh
chmod +x /usr/local/bin/totem-*.sh
ok "Script installati e configurati"
pause

# =============================================================================
# STEP 9 — Estensione Chromium totem-ext
# =============================================================================
hdr "STEP 9/10 — Installazione estensione Chromium"

mkdir -p /home/kiosk/totem-ext
cp "$REPO_DIR/files/manifest.json" /home/kiosk/totem-ext/
cp "$REPO_DIR/files/sw.js"         /home/kiosk/totem-ext/
cp "$REPO_DIR/files/content.js"    /home/kiosk/totem-ext/

# Aggiorna HOME_HOST e HOME_URL nei file JS
sed -i "s|HOME_HOST = \".*\"|HOME_HOST = \"${HOME_HOST}\"|g" /home/kiosk/totem-ext/sw.js
sed -i "s|HOME_URL = \".*\"|HOME_URL = \"${HOME_URL}\"|g"    /home/kiosk/totem-ext/sw.js
sed -i "s|HOME_HOST = \".*\"|HOME_HOST = \"${HOME_HOST}\"|g" /home/kiosk/totem-ext/content.js
sed -i "s|HOME_URL = \".*\"|HOME_URL = \"${HOME_URL}\"|g"    /home/kiosk/totem-ext/content.js

# Autostart GNOME
mkdir -p /home/kiosk/.config/autostart

cat > /home/kiosk/.config/autostart/totem-display.desktop << EOF
[Desktop Entry]
Type=Application
Name=Totem Display
Exec=/usr/local/bin/totem-display.sh
X-GNOME-Autostart-enabled=true
EOF

cat > /home/kiosk/.config/autostart/totem-kiosk.desktop << EOF
[Desktop Entry]
Type=Application
Name=Totem Kiosk
Exec=bash -lc "/usr/local/bin/totem-kiosk-start.sh"
X-GNOME-Autostart-enabled=true
EOF

chown -R kiosk:kiosk /home/kiosk/totem-ext
chown -R kiosk:kiosk /home/kiosk/.config
chmod 644 /home/kiosk/totem-ext/*
ok "Estensione e autostart configurati"
pause

# =============================================================================
# STEP 10 — Touchscreen, ottimizzazioni, finalizzazione
# =============================================================================
hdr "STEP 10/10 — Touchscreen e ottimizzazioni finali"

# Rilevamento automatico touchscreen
if grep -qi "2575" /proc/bus/input/devices; then
  info "Touchscreen Weida Hi-Tech rilevato — applico regola udev"
  cat > /etc/udev/rules.d/99-weida-touch.rules << 'UDEVRULES'
SUBSYSTEM=="input", ATTRS{idVendor}=="2575", ATTRS{idProduct}=="0920", \
  ENV{ID_INPUT_TOUCHSCREEN}="1", \
  ENV{ID_INPUT_MOUSE}="0", \
  ENV{ID_INPUT_JOYSTICK}="0"
UDEVRULES
  udevadm control --reload-rules && udevadm trigger
  ok "Regola udev Weida applicata"
elif grep -qi "222a" /proc/bus/input/devices; then
  ok "Touchscreen ILITEK rilevato — nessuna regola necessaria"
else
  warn "Touchscreen non rilevato automaticamente"
  info "Potresti dover configurare manualmente dopo il riavvio"
fi

# Disabilita sospensione sistema
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
ok "Sospensione sistema disabilitata"

# Disabilita screensaver e blocco schermo per utente kiosk
KIOSK_UID=$(id -u kiosk 2>/dev/null || echo "1001")
KIOSK_DBUS="unix:path=/run/user/${KIOSK_UID}/bus"

# Via dconf direttamente (funziona anche senza sessione attiva)
mkdir -p /home/kiosk/.config/dconf
chown -R kiosk:kiosk /home/kiosk/.config
chmod 700 /home/kiosk/.config/dconf
cat > /tmp/kiosk-dconf-settings << 'DCONF'
[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/desktop/screensaver]
lock-enabled=false
lock-delay=uint32 0
idle-activation-enabled=false

[org/gnome/desktop/a11y/applications]
screen-keyboard-enabled=false

[org/gnome/desktop/interface]
toolkit-accessibility=false
DCONF

# Applica tramite dconf load
sudo -u kiosk dbus-run-session -- dconf load / < /tmp/kiosk-dconf-settings 2>/dev/null || \
  info "dconf load non disponibile — verrà applicato al primo avvio"
rm -f /tmp/kiosk-dconf-settings

# Anche via gsettings se la sessione è già attiva
if [ -S "/run/user/${KIOSK_UID}/bus" ]; then
  sudo -u kiosk DBUS_SESSION_BUS_ADDRESS="$KIOSK_DBUS" gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
  sudo -u kiosk DBUS_SESSION_BUS_ADDRESS="$KIOSK_DBUS" gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null || true
  sudo -u kiosk DBUS_SESSION_BUS_ADDRESS="$KIOSK_DBUS" gsettings set org.gnome.desktop.screensaver lock-delay 0 2>/dev/null || true
  sudo -u kiosk DBUS_SESSION_BUS_ADDRESS="$KIOSK_DBUS" gsettings set org.gnome.desktop.screensaver idle-activation-enabled false 2>/dev/null || true
fi
ok "Screensaver e blocco schermo disabilitati"

# Disabilita notifiche GNOME e popup di sistema
cat >> /tmp/kiosk-dconf-notif << 'DCONF'
[org/gnome/desktop/notifications]
show-banners=false
show-in-lock-screen=false

[org/gnome/desktop/sound]
event-sounds=false

[org/gnome/shell]
welcome-dialog-last-shown-version='99.0'

[org/gnome/software]
download-updates=false
allow-updates=false
DCONF
sudo -u kiosk dbus-run-session -- dconf load / < /tmp/kiosk-dconf-notif 2>/dev/null || true
rm -f /tmp/kiosk-dconf-notif

# Rimuovi update-notifier
apt remove -y update-notifier update-notifier-common 2>/dev/null || true
systemctl disable apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
ok "Notifiche e popup di sistema disabilitati"

# Disabilita aggiornamenti automatici
systemctl disable unattended-upgrades 2>/dev/null || true
systemctl disable apt-daily.timer 2>/dev/null || true
systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
ok "Aggiornamenti automatici disabilitati"

# SSH server attivo
systemctl enable ssh 2>/dev/null || true
systemctl start ssh 2>/dev/null || true
ok "SSH server attivo"

# Ottimizzazioni specifiche Raspberry Pi
if [ "$IS_ARM" -eq 1 ]; then
  echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
  systemctl disable bluetooth 2>/dev/null || true
  ok "Ottimizzazioni Raspberry Pi applicate"
fi

pause

# =============================================================================
# Fine
# =============================================================================
KIOSK_UID=$(id -u kiosk 2>/dev/null || echo "1001")

echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║         ✅  INSTALLAZIONE COMPLETATA!            ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "  ${BOLD}Dopo il riavvio:${NC}"
echo "   • Chromium si aprirà automaticamente in fullscreen"
echo "   • Connettiti via SSH per completare la configurazione"
echo ""
echo -e "  ${BOLD}Disabilita tastiera GNOME (dopo il riavvio, via SSH):${NC}"
echo -e "  ${CYAN}sudo -u kiosk DBUS_SESSION_BUS_ADDRESS=\"unix:path=/run/user/${KIOSK_UID}/bus\" \\"
echo -e "    gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false${NC}"
echo ""
echo -e "  ${YELLOW}Password utente kiosk: kiosk123 — ricordati di cambiarla!${NC}"
echo ""
echo -e "  ${BOLD}Riavvio tra 10 secondi... (Ctrl+C per annullare)${NC}"
sleep 10
reboot
