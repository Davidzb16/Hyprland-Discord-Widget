#!/usr/bin/env bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${CYAN} Desinstalando Hyprland Discord Widget...${RESET}"

HYPR_SCRIPTS="$HOME/.config/hypr/scripts"
QUICKSHELL_DIR="$HYPR_SCRIPTS/quickshell/discord"
SYSTEMD_USER="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_USER/discord-lock.service"

# 1. Detener y deshabilitar el servicio systemd
if systemctl --user is-active --quiet discord-lock.service 2>/dev/null || systemctl --user is-enabled --quiet discord-lock.service 2>/dev/null; then
    echo -e "${BLUE} Deteniendo y deshabilitando el servicio discord-lock.service...${RESET}"
    systemctl --user stop discord-lock.service 2>/dev/null || true
    systemctl --user disable discord-lock.service 2>/dev/null || true
fi

if [ -f "$SERVICE_FILE" ]; then
    echo -e "${BLUE} Eliminando archivo de servicio systemd...${RESET}"
    rm -f "$SERVICE_FILE"
    systemctl --user daemon-reload
fi

# 2. Eliminar archivos instalados del widget
echo -e "${BLUE} Eliminando archivos instalados en ~/.config/hypr/...${RESET}"

[ -f "$HYPR_SCRIPTS/position_discord_widget.py" ] && rm -f "$HYPR_SCRIPTS/position_discord_widget.py"
[ -f "$HYPR_SCRIPTS/discord_lock_daemon.py" ] && rm -f "$HYPR_SCRIPTS/discord_lock_daemon.py"
[ -f "$HYPR_SCRIPTS/discord_voice.py" ] && rm -f "$HYPR_SCRIPTS/discord_voice.py"
[ -d "$QUICKSHELL_DIR" ] && rm -rf "$QUICKSHELL_DIR"

# 3. Remover icono de Discord de TopBar.qml si existe
TOPBAR_QML="$HOME/.config/hypr/scripts/quickshell/TopBar.qml"
if [ -f "$TOPBAR_QML" ]; then
    echo -e "${BLUE} Eliminando el icono de Discord de la barra superior ($TOPBAR_QML)...${RESET}"
    python3 -c "
import os

topbar_file = '$TOPBAR_QML'
try:
    with open(topbar_file, 'r', encoding='utf-8') as f:
        content = f.read()

    changed = False
    while 'discordPill' in content:
        comment_marker = '// --- Discord QuickVoice Pill ---'
        idx = content.find('id: discordPill')
        if idx == -1:
            break
        rect_start = content.rfind('Rectangle', 0, idx)
        if rect_start == -1:
            break
        comment_start = content.rfind(comment_marker, 0, rect_start)
        start_pos = comment_start if comment_start != -1 and content[comment_start:rect_start].strip() == comment_marker else rect_start

        open_brace = content.find('{', rect_start)
        if open_brace == -1:
            break
        depth = 1
        curr = open_brace + 1
        while curr < len(content) and depth > 0:
            if content[curr] == '{':
                depth += 1
            elif content[curr] == '}':
                depth -= 1
            curr += 1
        end_pos = curr

        while end_pos < len(content) and content[end_pos] in '\r\n':
            end_pos += 1
        while start_pos > 0 and content[start_pos-1] in ' \t':
            start_pos -= 1
        if start_pos > 0 and content[start_pos-1] == '\n':
            start_pos -= 1
        if start_pos > 0 and content[start_pos-1] == '\r':
            start_pos -= 1

        content = content[:start_pos] + '\n' + content[end_pos:]
        changed = True

    if changed:
        with open(topbar_file, 'w', encoding='utf-8') as f:
            f.write(content)
except Exception as e:
    print(f'Error al modificar TopBar.qml: {e}')
" 2>/dev/null || true
fi

# 4. Remover la regla de ventana de Hyprland si existe
RULES_CONF="$HOME/.config/hypr/config/rules.conf"
[ ! -f "$RULES_CONF" ] && RULES_CONF="$HOME/.config/hypr/hyprland.conf"

if [ -f "$RULES_CONF" ] && grep -q "discord_widget" "$RULES_CONF"; then
    echo -e "${BLUE} Removiendo reglas de ventana en $RULES_CONF...${RESET}"
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

# 5. Reiniciar quickshell si está corriendo para reflejar cambios en la barra
if pgrep -f "quickshell.*Shell.qml" >/dev/null; then
    echo -e "${BLUE} Reiniciando Quickshell para aplicar los cambios en la barra...${RESET}"
    pkill -f "quickshell.*Shell.qml" || true
    sleep 0.5
    quickshell -p "$HOME/.config/hypr/scripts/quickshell/Shell.qml" >/dev/null 2>&1 &
    disown
fi

echo -e "\n${GREEN} ¡Desinstalación completada con éxito!${RESET}\n"


