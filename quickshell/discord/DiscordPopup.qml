import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    focus: true

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }

    function s(val) {
        return scaler.s(val);
    }

    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    
    readonly property color mauve: _theme.mauve
    readonly property color red: _theme.red
    readonly property color green: _theme.green
    readonly property color blue: _theme.blue
    readonly property color discordBlurple: "#5865F2"

    property bool showAddForm: false
    property string activeChannelName: "Ninguno"
    property bool isConnectedVoice: false
    property string statusText: "Discord Listo"

    ListModel { id: channelsModel }

    // -------------------------------------------------------------------------
    // PROCESS HANDLERS
    // -------------------------------------------------------------------------
    Process {
        id: listChannelsProc
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/discord_voice.py", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let items = JSON.parse(this.text);
                    channelsModel.clear();
                    for (let i = 0; i < items.length; i++) {
                        channelsModel.append(items[i]);
                    }
                } catch(e) {
                    console.log("Error reading channels json:", e);
                }
            }
        }
    }

    Process {
        id: actionProc
        running: false
        onExited: {
            listChannelsProc.running = false;
            listChannelsProc.running = true;
        }
    }

    function executeAction(args) {
        let fullCmd = ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/discord_voice.py"].concat(args);
        actionProc.command = fullCmd;
        actionProc.running = false;
        actionProc.running = true;
    }

    function joinChannel(server, channel, guildId, channelId) {
        window.activeChannelName = server + " > " + channel;
        window.isConnectedVoice = true;
        window.statusText = "Conectado: " + channel;
        executeAction(["join", guildId, channelId]);
    }

    function disconnectVoice() {
        window.activeChannelName = "Ninguno";
        window.isConnectedVoice = false;
        window.statusText = "Desconectado";
        executeAction(["leave"]);
    }

    function launchDiscord() {
        executeAction(["launch"]);
    }

    function addChannel(server, channel, guildId, channelId, color, icon) {
        executeAction(["add", server, channel, guildId, channelId, color || "#5865F2", icon || "󰍡"]);
        window.showAddForm = false;
    }

    function removeChannel(idx) {
        executeAction(["remove", idx.toString()]);
    }

    // -------------------------------------------------------------------------
    // MAIN BACKGROUND CARD
    // -------------------------------------------------------------------------
    Rectangle {
        id: cardBg
        anchors.fill: parent
        color: Qt.rgba(mantle.r, mantle.g, mantle.b, 0.88)
        radius: window.s(22)
        border.width: 1
        border.color: Qt.rgba(discordBlurple.r, discordBlurple.g, discordBlurple.b, 0.3)

        Behavior on color { ColorAnimation { duration: 300 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: window.s(18)
            spacing: window.s(14)

            // --- HEADER ---
            RowLayout {
                Layout.fillWidth: true
                spacing: window.s(12)

                Rectangle {
                    width: window.s(44)
                    height: window.s(44)
                    radius: window.s(14)
                    color: discordBlurple

                    Text {
                        anchors.centerIn: parent
                        text: "󰙯"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(24)
                        color: "#FFFFFF"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: window.s(2)

                    Text {
                        text: "Discord QuickVoice"
                        font.family: "Outfit"
                        font.pixelSize: window.s(17)
                        font.weight: Font.Bold
                        color: text
                    }

                    RowLayout {
                        spacing: window.s(6)
                        Rectangle {
                            width: window.s(8)
                            height: window.s(8)
                            radius: window.s(4)
                            color: isConnectedVoice ? green : discordBlurple
                        }
                        Text {
                            text: statusText
                            font.family: "JetBrains Mono"
                            font.pixelSize: window.s(11)
                            color: subtext0
                        }
                    }
                }

                // Launch Discord app button
                Rectangle {
                    width: window.s(38)
                    height: window.s(38)
                    radius: window.s(12)
                    color: launchBtnArea.containsMouse ? Qt.rgba(surface2.r, surface2.g, surface2.b, 0.7) : Qt.rgba(surface0.r, surface0.g, surface0.b, 0.5)

                    Text {
                        anchors.centerIn: parent
                        text: "󰅍"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(18)
                        color: text
                    }

                    MouseArea {
                        id: launchBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: launchDiscord()
                    }
                }
            }

            // --- ACTIVE VOICE STATUS CARD ---
            Rectangle {
                Layout.fillWidth: true
                height: window.s(54)
                radius: window.s(14)
                color: isConnectedVoice ? Qt.rgba(green.r, green.g, green.b, 0.12) : Qt.rgba(surface0.r, surface0.g, surface0.b, 0.4)
                border.width: 1
                border.color: isConnectedVoice ? Qt.rgba(green.r, green.g, green.b, 0.4) : Qt.rgba(overlay0.r, overlay0.g, overlay0.b, 0.15)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(10)
                    spacing: window.s(10)

                    Text {
                        text: isConnectedVoice ? "󰍬" : "󰍭"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(20)
                        color: isConnectedVoice ? green : subtext0
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: isConnectedVoice ? "Canal Activo" : "Sin conexión de voz"
                            font.family: "Outfit"
                            font.pixelSize: window.s(11)
                            font.weight: Font.DemiBold
                            color: subtext0
                        }
                        Text {
                            text: activeChannelName
                            font.family: "JetBrains Mono"
                            font.pixelSize: window.s(13)
                            font.weight: Font.Bold
                            color: isConnectedVoice ? green : text
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        visible: isConnectedVoice
                        width: window.s(32)
                        height: window.s(32)
                        radius: window.s(10)
                        color: leaveBtnArea.containsMouse ? red : Qt.rgba(red.r, red.g, red.b, 0.2)

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: window.s(16)
                            color: leaveBtnArea.containsMouse ? "#FFFFFF" : red
                        }

                        MouseArea {
                            id: leaveBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: disconnectVoice()
                        }
                    }
                }
            }

            // --- SECTION TITLE ---
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Servidores & Canales de Voz"
                    font.family: "Outfit"
                    font.pixelSize: window.s(13)
                    font.weight: Font.Bold
                    color: subtext0
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: window.s(28)
                    height: window.s(28)
                    radius: window.s(8)
                    color: addToggleArea.containsMouse ? Qt.rgba(discordBlurple.r, discordBlurple.g, discordBlurple.b, 0.8) : Qt.rgba(surface1.r, surface1.g, surface1.b, 0.5)

                    Text {
                        anchors.centerIn: parent
                        text: showAddForm ? "󰅖" : "󰐕"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(16)
                        color: text
                    }

                    MouseArea {
                        id: addToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: showAddForm = !showAddForm
                    }
                }
            }

            // --- ADD CHANNEL FORM (COLLAPSIBLE) ---
            Rectangle {
                Layout.fillWidth: true
                visible: showAddForm
                implicitHeight: showAddForm ? window.s(190) : 0
                radius: window.s(14)
                color: Qt.rgba(surface0.r, surface0.g, surface0.b, 0.6)
                border.width: 1
                border.color: Qt.rgba(discordBlurple.r, discordBlurple.g, discordBlurple.b, 0.4)
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(10)
                    spacing: window.s(8)

                    RowLayout {
                        spacing: window.s(8)
                        TextField {
                            id: serverInput
                            placeholderText: "Nombre Servidor"
                            Layout.fillWidth: true
                            font.pixelSize: window.s(11)
                        }
                        TextField {
                            id: channelInput
                            placeholderText: "Nombre Canal"
                            Layout.fillWidth: true
                            font.pixelSize: window.s(11)
                        }
                    }

                    RowLayout {
                        spacing: window.s(8)
                        TextField {
                            id: guildInput
                            placeholderText: "ID Servidor (Guild ID)"
                            Layout.fillWidth: true
                            font.pixelSize: window.s(11)
                        }
                        TextField {
                            id: channelIdInput
                            placeholderText: "ID Canal (Channel ID)"
                            Layout.fillWidth: true
                            font.pixelSize: window.s(11)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(8)
                        Button {
                            text: "Guardar Canal"
                            Layout.fillWidth: true
                            onClicked: {
                                if (serverInput.text && channelInput.text && guildInput.text && channelIdInput.text) {
                                    addChannel(serverInput.text, channelInput.text, guildInput.text, channelIdInput.text, "#5865F2", "󰍡");
                                    serverInput.text = ""; channelInput.text = ""; guildInput.text = ""; channelIdInput.text = "";
                                }
                            }
                        }
                    }
                }
            }

            // --- CHANNEL LIST ---
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: channelListView
                    model: channelsModel
                    spacing: window.s(10)

                    delegate: Rectangle {
                        width: channelListView.width
                        height: window.s(60)
                        radius: window.s(14)
                        color: itemArea.containsMouse ? Qt.rgba(surface1.r, surface1.g, surface1.b, 0.7) : Qt.rgba(surface0.r, surface0.g, surface0.b, 0.4)
                        border.width: 1
                        border.color: itemArea.containsMouse ? Qt.rgba(discordBlurple.r, discordBlurple.g, discordBlurple.b, 0.5) : "transparent"

                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: window.s(10)
                            spacing: window.s(12)

                            Rectangle {
                                width: window.s(40)
                                height: window.s(40)
                                radius: window.s(12)
                                color: model.color || discordBlurple

                                Text {
                                    anchors.centerIn: parent
                                    text: model.icon || "󰍡"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(20)
                                    color: "#FFFFFF"
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: window.s(2)

                                Text {
                                    text: model.server
                                    font.family: "Outfit"
                                    font.pixelSize: window.s(13)
                                    font.weight: Font.Bold
                                    color: text
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "🔊 " + model.channel
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: window.s(11)
                                    color: subtext0
                                    elide: Text.ElideRight
                                }
                            }

                            // Join Button
                            Rectangle {
                                width: window.s(84)
                                height: window.s(34)
                                radius: window.s(10)
                                color: joinArea.containsMouse ? discordBlurple : Qt.rgba(discordBlurple.r, discordBlurple.g, discordBlurple.b, 0.2)

                                Text {
                                    anchors.centerIn: parent
                                    text: "Unirme"
                                    font.family: "Outfit"
                                    font.pixelSize: window.s(12)
                                    font.weight: Font.Bold
                                    color: joinArea.containsMouse ? "#FFFFFF" : discordBlurple
                                }

                                MouseArea {
                                    id: joinArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: joinChannel(model.server, model.channel, model.guild_id, model.channel_id)
                                }
                            }

                            // Delete icon button
                            Rectangle {
                                width: window.s(28)
                                height: window.s(28)
                                radius: window.s(8)
                                color: delArea.containsMouse ? red : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(14)
                                    color: delArea.containsMouse ? "#FFFFFF" : overlay0
                                }

                                MouseArea {
                                    id: delArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: removeChannel(index)
                                }
                            }
                        }

                        MouseArea {
                            id: itemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onDoubleClicked: joinChannel(model.server, model.channel, model.guild_id, model.channel_id)
                        }
                    }
                }
            }
        }
    }
}
