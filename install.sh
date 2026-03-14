#!/usr/bin/env bash
set -euo pipefail

# ── Colori ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "\n${BLUE}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║         TOTEM KIOSK — INSTALLER                 ║"
echo "  ║     github.com/manuelpetrolo/kiosk-setup        ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "  ${BOLD}Seleziona il tipo di installazione:${NC}"
echo ""
echo -e "  ${CYAN}1)${NC} Ubuntu Desktop + GNOME  ${YELLOW}(Raspberry Pi 5)${NC}"
echo -e "  ${CYAN}2)${NC} Ubuntu Server + Cage    ${YELLOW}(PC / Macchina Virtuale)${NC}"
echo ""
read -rp "  Scelta [1/2]: " choice

case "$choice" in
    1)
        echo -e "\n  ${GREEN}▶ Avvio installazione Ubuntu Desktop + GNOME...${NC}\n"
        curl -fsSL https://raw.githubusercontent.com/manuelpetrolo/kiosk-installer/main/install-desktop.sh -o /tmp/install-desktop.sh
        sudo bash /tmp/install-desktop.sh
        ;;
    2)
        echo -e "\n  ${GREEN}▶ Avvio installazione Ubuntu Server + Cage...${NC}\n"
        curl -fsSL https://raw.githubusercontent.com/manuelpetrolo/kiosk-installer/main/install-server.sh -o /tmp/install-server.sh
        sudo bash /tmp/install-server.sh
        ;;
    *)
        echo -e "\n  Scelta non valida. Esegui di nuovo lo script."
        exit 1
        ;;
esac
