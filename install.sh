#!/usr/bin/env bash

set -e

GREEN='\030[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

echo -e "${CYAN}🚀 Instalando Hyprland Discord Widget...${RESET}"

HYPR_SCRIPTS="$HOME/.config/hypr/scripts"
QUICKSHELL_DIR="$HYPR_SCRIPTS/quickshell/discord"
SYSTEMD_USER="$HOME/.config/systemd/user"
TMP_DIR=$(mktemp -d)

trap 'rm -rf "$TMP_DIR"' EXIT

# Clone or use local source
if [ -d ".git" ] && [ -f "scripts/position_discord_widget.py" ]; then
    SRC_DIR="."
else
    echo -e "${BLUE}📥 Descargando repositorio desde GitHub...${RESET}"
    git clone --depth 1 https://github.com/Davidzb16/Hyprland-Discord-Widget.git "$TMP_DIR/repo"
    SRC_DIR="$TMP_DIR/repo"
fi

echo -e "${BLUE}📂 Copiando archivos a ~/.config/hypr/...${RESET}"
mkdir -p "$HYPR_SCRIPTS" "$QUICKSHELL_DIR" "$SYSTEMD_USER"

cp "$SRC_DIR/scripts/position_discord_widget.py" "$HYPR_SCRIPTS/"
cp "$SRC_DIR/scripts/discord_lock_daemon.py" "$HYPR_SCRIPTS/"
cp "$SRC_DIR/scripts/discord_voice.py" "$HYPR_SCRIPTS/"
cp -r "$SRC_DIR/quickshell/discord/"* "$QUICKSHELL_DIR/"
cp "$SRC_DIR/systemd/discord-lock.service" "$SYSTEMD_USER/"

chmod +x "$HYPR_SCRIPTS/position_discord_widget.py"
chmod +x "$HYPR_SCRIPTS/discord_lock_daemon.py"
chmod +x "$HYPR_SCRIPTS/discord_voice.py"

echo -e "${BLUE}⚙️ Configurando el servicio de bloqueo systemd...${RESET}"
systemctl --user daemon-reload
systemctl --user enable --now discord-lock.service

# Inject Hyprland windowrule if not present
RULES_CONF="$HOME/.config/hypr/config/rules.conf"
[ ! -f "$RULES_CONF" ] && RULES_CONF="$HOME/.config/hypr/hyprland.conf"

if [ -f "$RULES_CONF" ]; then
    if ! grep -q "discord_widget" "$RULES_CONF"; then
        echo -e "${BLUE}📝 Añadiendo regla de ventana a $RULES_CONF...${RESET}"
        cat << 'EOF' >> "$RULES_CONF"

# ───────── DISCORD WIDGET ─────────
windowrule {
    name = "discord_widget"
    match:class = ^(discord|com.discordapp.Discord)$
    float = on
    size = 480 680
    move = 100%-490 60
    animation = slide top
}
EOF
        hyprctl reload >/dev/null 2>&1 || true
    fi
fi

echo -e "\n${GREEN}✨ ¡Instalación completada con éxito!${RESET}"
echo -e "${YELLOW}📌 Puedes probar el widget ejecutando:${RESET}"
echo -e "   python3 ~/.config/hypr/scripts/position_discord_widget.py\n"
