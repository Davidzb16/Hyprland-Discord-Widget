#!/usr/bin/env bash

set -e

GREEN='\033[0;32m'
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

# Configure Quickshell WindowRegistry.js to not spawn custom DiscordPopup.qml
WIN_REG="$HOME/.config/hypr/scripts/quickshell/WindowRegistry.js"
if [ -f "$WIN_REG" ]; then
    sed -i 's|"discord/DiscordPopup.qml"|""|g' "$WIN_REG"
fi

# Patch Main.qml to safely handle empty component paths (comp: "") without crashing widgetStack
MAIN_QML="$HOME/.config/hypr/scripts/quickshell/Main.qml"
if [ -f "$MAIN_QML" ]; then
    python3 -c "
main_file = '$MAIN_QML'
try:
    with open(main_file, 'r', encoding='utf-8') as f:
        c = f.read()
    if 'widgetStack.clear();' not in c:
        old_target = 'widgetStack.replace(t.comp, props);'
        if old_target in c:
            new_target = '''if (t && t.comp && t.comp !== \"\") {
                if (immediate) {
                    widgetStack.replace(t.comp, props, StackView.Immediate);
                } else {
                    widgetStack.replace(t.comp, props);
                }
            } else {
                widgetStack.clear();
            }'''
            c = c.replace('''if (immediate) {
                widgetStack.replace(t.comp, props, StackView.Immediate);
            } else {
                widgetStack.replace(t.comp, props);
            }''', new_target)
            with open(main_file, 'w', encoding='utf-8') as f:
                f.write(c)
except Exception as e:
    pass
" 2>/dev/null || true
fi

# Inject Discord Icon Pill into TopBar.qml inside sysLayout if present
TOPBAR_QML="$HOME/.config/hypr/scripts/quickshell/TopBar.qml"
if [ -f "$TOPBAR_QML" ]; then
    echo -e "${BLUE}📊 Agregando icono de Discord a la barra superior ($TOPBAR_QML)...${RESET}"
    python3 -c "
import os

topbar_file = '$TOPBAR_QML'
try:
    with open(topbar_file, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'discordPill' not in content:
        discord_block = '''                            // --- Discord QuickVoice Pill ---
                            Rectangle {
                                id: discordPill
                                property bool isHovered: discordMouse.containsMouse
                                property bool isActive: barWindow.activeWidget === \"discord\"
                                radius: barWindow.s(10)
                                height: sysLayout.pillHeight
                                width: barWindow.s(38)
                                clip: true

                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: barWindow.s(10)
                                    opacity: discordPill.isActive ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: \"#5865F2\" }
                                        GradientStop { position: 1.0; color: \"#7983F5\" }
                                    }
                                }

                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !parent.initAnimTrigger; interval: 175; onTriggered: parent.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: parent.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: \"󰙯\"
                                    font.family: \"Iosevka Nerd Font\"
                                    font.pixelSize: barWindow.s(17)
                                    color: discordPill.isActive ? \"#FFFFFF\" : (discordPill.isHovered ? \"#5865F2\" : mocha.text)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                MouseArea {
                                    id: discordMouse
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    onClicked: Quickshell.execDetached([\"bash\", \"-c\", \"~/.config/hypr/scripts/qs_manager.sh toggle discord\"])
                                }
                            }'''

        sys_idx = content.find('id: sysLayout')
        if sys_idx != -1:
            pill_h_idx = content.find('property int pillHeight', sys_idx)
            if pill_h_idx != -1:
                line_end = content.find('\n', pill_h_idx)
                new_content = content[:line_end+1] + '\n' + discord_block + '\n' + content[line_end+1:]
            else:
                line_end = content.find('\n', sys_idx)
                new_content = content[:line_end+1] + '\n' + discord_block + '\n' + content[line_end+1:]

            with open(topbar_file, 'w', encoding='utf-8') as f:
                f.write(new_content)
except Exception as e:
    print(f'Error al modificar TopBar.qml: {e}')
" 2>/dev/null || true
fi

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

# Restart quickshell if running to apply top bar changes
if pgrep -f "quickshell.*Shell.qml" >/dev/null; then
    echo -e "${BLUE}🔄 Reiniciando Quickshell para aplicar los cambios en la barra...${RESET}"
    pkill -f "quickshell.*Shell.qml" || true
    sleep 0.5
    quickshell -p "$HOME/.config/hypr/scripts/quickshell/Shell.qml" >/dev/null 2>&1 &
    disown
fi

echo -e "\n${GREEN}✨ ¡Instalación completada con éxito!${RESET}"
echo -e "${YELLOW}📌 Puedes probar el widget ejecutando:${RESET}"
echo -e "   python3 ~/.config/hypr/scripts/position_discord_widget.py\n"


