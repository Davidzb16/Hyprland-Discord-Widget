#!/usr/bin/env bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${CYAN}🗑️  Desinstalando Hyprland Discord Widget...${RESET}"

HYPR_SCRIPTS="$HOME/.config/hypr/scripts"
QUICKSHELL_DIR="$HYPR_SCRIPTS/quickshell/discord"
SYSTEMD_USER="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_USER/discord-lock.service"

# 1. Detener y deshabilitar el servicio systemd
if systemctl --user is-active --quiet discord-lock.service 2>/dev/null || systemctl --user is-enabled --quiet discord-lock.service 2>/dev/null; then
    echo -e "${BLUE}⚙️ Deteniendo y deshabilitando el servicio discord-lock.service...${RESET}"
    systemctl --user stop discord-lock.service 2>/dev/null || true
    systemctl --user disable discord-lock.service 2>/dev/null || true
fi

if [ -f "$SERVICE_FILE" ]; then
    echo -e "${BLUE}🗑️ Eliminando archivo de servicio systemd...${RESET}"
    rm -f "$SERVICE_FILE"
    systemctl --user daemon-reload
fi

# 2. Eliminar archivos instalados del widget
echo -e "${BLUE}📂 Eliminando archivos instalados en ~/.config/hypr/...${RESET}"

[ -f "$HYPR_SCRIPTS/position_discord_widget.py" ] && rm -f "$HYPR_SCRIPTS/position_discord_widget.py"
[ -f "$HYPR_SCRIPTS/discord_lock_daemon.py" ] && rm -f "$HYPR_SCRIPTS/discord_lock_daemon.py"
[ -f "$HYPR_SCRIPTS/discord_voice.py" ] && rm -f "$HYPR_SCRIPTS/discord_voice.py"
[ -d "$QUICKSHELL_DIR" ] && rm -rf "$QUICKSHELL_DIR"

# 3. Remover la regla de ventana de Hyprland si existe
RULES_CONF="$HOME/.config/hypr/config/rules.conf"
[ ! -f "$RULES_CONF" ] && RULES_CONF="$HOME/.config/hypr/hyprland.conf"

if [ -f "$RULES_CONF" ] && grep -q "discord_widget" "$RULES_CONF"; then
    echo -e "${BLUE}📝 Removiendo reglas de ventana en $RULES_CONF...${RESET}"
    python3 -c "
import re

config_file = '$RULES_CONF'
try:
    with open(config_file, 'r') as f:
        content = f.read()

    pattern = r'\n?# ─+ DISCORD WIDGET ─+\nwindowrule\s*\{[^}]*name\s*=\s*\"discord_widget\"[^}]*\}\n?'
    new_content = re.sub(pattern, '', content)

    with open(config_file, 'w') as f:
        f.write(new_content)
except Exception as e:
    pass
" 2>/dev/null || true

    hyprctl reload >/dev/null 2>&1 || true
fi

echo -e "\n${GREEN}✨ ¡Desinstalación completada con éxito!${RESET}\n"
