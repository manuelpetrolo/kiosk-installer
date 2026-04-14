#!/usr/bin/env bash
# =============================================================================
#  TOTEM KIOSK — Install Script v4.1 (Ubuntu Server + Cage)
#  Repository: git@github.com:manuelpetrolo/kiosk-setup.git
#
#  Compatibile con:
#    - Ubuntu Server 24.04 LTS  x86_64  (PC)
#    - Ubuntu Server 24.04 LTS  ARM64   (Raspberry Pi 5)
#
#  Uso:
#    sudo bash install-server.sh
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
echo "  ║      TOTEM KIOSK — INSTALLER v4.1               ║"
echo "  ║      Ubuntu Server + Cage (Wayland)             ║"
echo "  ║  github.com/manuelpetrolo/kiosk-setup           ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Controlli iniziali ────────────────────────────────────────────────────────
[ "$EUID" -eq 0 ] || err "Esegui come root: sudo bash install-server.sh"

# Rileva architettura
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" ]]; then
  IS_ARM=1
  info "Architettura: ARM64 (Raspberry Pi 5)"
else
  IS_ARM=0
  info "Architettura: x86_64 (PC)"
fi

# =============================================================================
# STEP 1 — Pacchetti base
# =============================================================================
hdr "STEP 1/9 — Installazione pacchetti base"

export DEBIAN_FRONTEND=noninteractive

apt update -qq
apt install -y \
  git curl wget jq \
  openssh-client openssh-server \
  cage xwayland \
  snapd \
  python3 python3-flask python3-venv python3-pip \
  ffmpeg \
  unclutter-xfixes \
  fonts-liberation fonts-dejavu-core \
  ca-certificates \
  -qq

command -v cage >/dev/null 2>&1 || err "Cage non installato correttamente"
command -v ffprobe >/dev/null 2>&1 || err "ffprobe non disponibile: ffmpeg non installato correttamente"
ok "Pacchetti base installati"

if ! snap list chromium &>/dev/null; then
  info "Installazione Chromium snap..."
  snap install chromium
  ok "Chromium snap installato"
else
  warn "Chromium snap già installato"
fi

BROWSER_BIN=$(command -v chromium-browser 2>/dev/null || command -v chromium 2>/dev/null || echo "/snap/bin/chromium")
[ -x "$BROWSER_BIN" ] || BROWSER_BIN="/snap/bin/chromium"
ok "Chromium: $BROWSER_BIN"

pause

# =============================================================================
# STEP 2 — SSH Key per GitHub
# =============================================================================
hdr "STEP 2/9 — Generazione SSH key per GitHub"

if [ ! -f "${SSH_KEY}" ]; then
  ssh-keygen -t ed25519 -C "kiosk-$(hostname)" -f "${SSH_KEY}" -N ""
  ok "SSH key generata: ${SSH_KEY}"
else
  warn "SSH key già esistente — riutilizzo quella esistente"
fi

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
echo "   1. Apri: ${CYAN}https://github.com/${GITHUB_USER}/${REPO_NAME}/settings/keys${NC}"
echo "   2. Clicca → Add deploy key"
echo "   3. Title: kiosk-$(hostname)"
echo "   4. Key: incolla la chiave sopra"
echo "   5. Clicca → Add key"
echo ""
echo -e "  ${YELLOW}Poi torna qui e premi INVIO per continuare...${NC}"
read -r

info "Verifico connessione a GitHub..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  ok "Connessione GitHub verificata"
else
  warn "Verifica non conclusiva — provo comunque a clonare"
fi
pause

# =============================================================================
# STEP 3 — Clone repository
# =============================================================================
hdr "STEP 3/9 — Download file da GitHub"

if [ -d "$REPO_DIR/.git" ]; then
  warn "Repository già presente — aggiorno"
  git -C "$REPO_DIR" pull
else
  git clone "$REPO_SSH" "$REPO_DIR"
fi

for f in \
  files/content.js \
  files/sw.js \
  files/manifest.json \
  files/totem-kiosk-start.sh \
  files/totem-agent.sh \
  files/totem-agent-sync.sh \
  files/totem-display.sh \
  update.sh \
  panel/totem-panel.py \
  panel/app.py \
  panel/totem-panel.service
do
  [ -f "$REPO_DIR/$f" ] || err "File mancante nel repository: $f"
done
ok "File scaricati in $REPO_DIR"
pause

# =============================================================================
# STEP 4 — Parametri configurazione
# =============================================================================
hdr "STEP 4/9 — Configurazione kiosk"

if [ -f "$REPO_DIR/config/kiosk.env" ]; then
  source "$REPO_DIR/config/kiosk.env"
  info "kiosk.env trovato nel repository — valori precaricati"
fi

read -rp "  → URL server (es. http://192.168.1.253/) [${KIOSK_SERVER_URL:-}]: " input
KIOSK_SERVER_URL="${input:-${KIOSK_SERVER_URL:-http://192.168.1.253/}}"
[[ "$KIOSK_SERVER_URL" == */ ]] || KIOSK_SERVER_URL="${KIOSK_SERVER_URL}/"

read -rp "  → Token kiosk [${KIOSK_TOKEN:-nessuno}]: " input
KIOSK_TOKEN="${input:-${KIOSK_TOKEN:-}}"

read -rp "  → Utente admin del sistema [$(logname 2>/dev/null || echo ubuntu)]: " input
ADMIN_USER="${input:-$(logname 2>/dev/null || echo ubuntu)}"

HOME_HOST=$(echo "$KIOSK_SERVER_URL" | sed 's|https\?://||' | sed 's|/.*||')
HOME_URL="${KIOSK_SERVER_URL}?token=${KIOSK_TOKEN}"

echo ""
echo -e "  Server  : ${CYAN}$KIOSK_SERVER_URL${NC}"
echo -e "  Token   : ${CYAN}${KIOSK_TOKEN:-<nessuno>}${NC}"
echo -e "  Browser : ${CYAN}$BROWSER_BIN${NC}"
echo ""
read -rp "  Confermi? [s/N]: " confirm
[[ "${confirm,,}" == "s" ]] || { echo "Annullato."; exit 0; }
pause

# =============================================================================
# STEP 5 — Utente kiosk
# =============================================================================
hdr "STEP 5/9 — Creazione utente kiosk"

if ! id kiosk &>/dev/null; then
  useradd -m -s /bin/bash kiosk
  echo "kiosk:kiosk123" | chpasswd
  ok "Utente kiosk creato (password temporanea: kiosk123)"
else
  warn "Utente kiosk già esistente — skip"
fi

usermod -aG video,audio,input,render kiosk 2>/dev/null || true
[ "$IS_ARM" -eq 1 ] && usermod -aG gpio kiosk 2>/dev/null || true
ok "Gruppi assegnati"
pause

# =============================================================================
# STEP 6 — kiosk.env
# =============================================================================
hdr "STEP 6/9 — File di configurazione"

mkdir -p /etc/totem
cat > /etc/totem/kiosk.env << EOF
KIOSK_TOKEN=${KIOSK_TOKEN}
KIOSK_VERSION=kiosk-0.4.1
KIOSK_SERVER_URL=${KIOSK_SERVER_URL}
KIOSK_HOME_URL=${HOME_URL}
KIOSK_HOME_HOST=${HOME_HOST}
TOTEM_PANEL_PASSWORD=totem2026
EOF
chmod 644 /etc/totem/kiosk.env
ok "kiosk.env creato in /etc/totem/"
pause

# =============================================================================
# STEP 7 — Estensione Chromium totem-ext
# =============================================================================
hdr "STEP 7/9 — Installazione estensione Chromium"

mkdir -p /home/kiosk/totem-ext
cp "$REPO_DIR/files/manifest.json" /home/kiosk/totem-ext/
cp "$REPO_DIR/files/sw.js"         /home/kiosk/totem-ext/
cp "$REPO_DIR/files/content.js"    /home/kiosk/totem-ext/

# Aggiorna HOME_HOST e HOME_URL nei file dell'estensione
sed -i "s|HOME_HOST = \"[^\"]*\"|HOME_HOST = \"${HOME_HOST}\"|g" /home/kiosk/totem-ext/sw.js
sed -i "s|HOME_URL = \"[^\"]*\"|HOME_URL = \"${HOME_URL}\"|g"    /home/kiosk/totem-ext/sw.js
sed -i "s|HOME_HOST = \"[^\"]*\"|HOME_HOST = \"${HOME_HOST}\"|g" /home/kiosk/totem-ext/content.js
sed -i "s|HOME_URL = \"[^\"]*\"|HOME_URL = \"${HOME_URL}\"|g"    /home/kiosk/totem-ext/content.js

chown -R kiosk:kiosk /home/kiosk/totem-ext
chmod 644 /home/kiosk/totem-ext/*
ok "Estensione installata"
pause

# =============================================================================
# STEP 8 — Servizio systemd Cage
# =============================================================================
hdr "STEP 8/9 — Configurazione servizio Cage"

# Script runtime kiosk
cp "$REPO_DIR/files/totem-kiosk-start.sh" /usr/local/bin/totem-kiosk-start.sh
cp "$REPO_DIR/files/totem-display.sh" /usr/local/bin/totem-display.sh
chmod +x /usr/local/bin/totem-kiosk-start.sh /usr/local/bin/totem-display.sh

# Servizio systemd per cage
cat > /etc/systemd/system/totem-kiosk.service << 'EOF'
[Unit]
Description=Totem Kiosk (Cage + Chromium)
After=systemd-user-sessions.service network-online.target snapd.seeded.service
Wants=network-online.target snapd.seeded.service

[Service]
User=kiosk
Group=kiosk
PAMName=login
TTYPath=/dev/tty7
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty
StandardOutput=journal
StandardError=journal
EnvironmentFile=/etc/totem/kiosk.env
Environment=XDG_RUNTIME_DIR=/run/user/1001
ExecStartPre=/bin/sleep 3
ExecStartPre=/bin/bash -c 'mkdir -p /run/user/$(id -u kiosk) && chown kiosk:kiosk /run/user/$(id -u kiosk)'
ExecStart=/bin/bash -lc 'export XDG_RUNTIME_DIR=/run/user/$(id -u kiosk); exec /usr/bin/cage -s -- /usr/local/bin/totem-kiosk-start.sh'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable totem-kiosk.service

snap connect chromium:wayland 2>/dev/null || true
snap connect chromium:hardware-observe 2>/dev/null || true
ok "Servizio totem-kiosk configurato"
pause

# =============================================================================
# STEP 9 — Ottimizzazioni finali
# =============================================================================
hdr "STEP 9/9 — Ottimizzazioni finali"

systemctl enable ssh 2>/dev/null || true
systemctl start ssh 2>/dev/null || true
ok "SSH server attivo"

systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
ok "Sospensione sistema disabilitata"

systemctl disable unattended-upgrades 2>/dev/null || true
systemctl disable apt-daily.timer 2>/dev/null || true
systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
apt remove -y update-notifier update-notifier-common 2>/dev/null || true
ok "Aggiornamenti automatici disabilitati"

# Pannello admin Flask
if [ -f "$REPO_DIR/panel/totem-panel.py" ] && [ -f "$REPO_DIR/panel/app.py" ]; then
  install -d -m 755 /opt/kiosk-setup/panel
  cp -r "$REPO_DIR/panel/"* /opt/kiosk-setup/panel/

  chmod +x /opt/kiosk-setup/panel/totem-panel.py
  rm -f /usr/local/bin/totem-panel.py

  cat > /etc/systemd/system/totem-panel.service << 'EOF'
[Unit]
Description=Totem Kiosk Panel
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/kiosk-setup/panel
EnvironmentFile=/etc/totem/kiosk.env
ExecStart=/usr/bin/python3 /opt/kiosk-setup/panel/totem-panel.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable totem-panel
  systemctl restart totem-panel
  ok "Pannello admin Flask avviato su porta 8080"
fi

# Totem Agent + updater
if [ -f "$REPO_DIR/files/totem-agent.sh" ]; then
  cp "$REPO_DIR/files/totem-agent.sh" /usr/local/bin/totem-agent.sh
  cp "$REPO_DIR/files/totem-agent-sync.sh" /usr/local/bin/totem-agent-sync.sh
  cp "$REPO_DIR/files/totem-display.sh" /usr/local/bin/totem-display.sh
  cp "$REPO_DIR/update.sh" /usr/local/bin/totem-update.sh

  chmod +x \
    /usr/local/bin/totem-agent.sh \
    /usr/local/bin/totem-agent-sync.sh \
    /usr/local/bin/totem-display.sh \
    /usr/local/bin/totem-update.sh

  cat > /etc/systemd/system/totem-agent.service << 'EOF'
[Unit]
Description=Totem Kiosk Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/totem/kiosk.env
ExecStart=/usr/local/bin/totem-agent.sh
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
  systemctl enable totem-agent.timer
  systemctl restart totem-agent.timer
  systemctl start totem-agent.service || true
  ok "Totem agent installato e avviato (ogni 30s)"
fi

# Ottimizzazioni Raspberry Pi
if [ "$IS_ARM" -eq 1 ]; then
  echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
  systemctl disable bluetooth 2>/dev/null || true
  ok "Ottimizzazioni Raspberry Pi applicate"
fi

pause

hdr "Verifica servizi"

systemctl daemon-reload
systemctl enable totem-kiosk.service 2>/dev/null || true
systemctl restart totem-kiosk.service 2>/dev/null || true

systemctl is-enabled totem-panel.service >/dev/null 2>&1 && systemctl restart totem-panel.service || true
systemctl restart totem-agent.timer 2>/dev/null || true
systemctl start totem-agent.service 2>/dev/null || true

ok "Servizi aggiornati"


pause
# =============================================================================
# Fine
# =============================================================================
IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║         ✅  INSTALLAZIONE COMPLETATA!            ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "  ${BOLD}Dopo il riavvio:${NC}"
echo "   • Cage avvierà Chromium automaticamente in fullscreen"
echo "   • Nessuna gesture — schermo completamente bloccato"
echo ""
echo -e "  ${BOLD}Pannello admin:${NC}"
echo -e "   ${CYAN}http://${IP}:8080${NC}  —  password: totem2026"
echo ""
echo -e "  ${BOLD}Comandi utili:${NC}"
echo -e "   ${CYAN}sudo systemctl restart totem-kiosk${NC}  — riavvia kiosk"
echo -e "   ${CYAN}sudo systemctl status totem-kiosk${NC}   — stato kiosk"
echo -e "   ${CYAN}sudo journalctl -u totem-kiosk -f${NC}   — log live"
echo ""
echo -e "  ${YELLOW}Password utente kiosk: kiosk123 — ricordati di cambiarla!${NC}"
echo ""
echo -e "  ${BOLD}Riavvio tra 10 secondi... (Ctrl+C per annullare)${NC}"
sleep 10
reboot
