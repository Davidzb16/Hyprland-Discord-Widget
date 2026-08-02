#!/usr/bin/env python3
import os
import sys
import json
import socket
import struct
import uuid
import subprocess

CONFIG_PATH = os.path.expanduser("~/.config/hypr/scripts/quickshell/discord/channels.json")

def find_ipc_socket():
    uid = os.getuid()
    possible_paths = [
        f"/run/user/{uid}/discord-ipc-0",
        f"/run/user/{uid}/app/com.discordapp.Discord/discord-ipc-0",
        "/tmp/discord-ipc-0",
        f"/run/user/{uid}/vesktop-ipc-0",
    ]
    for path in possible_paths:
        if os.path.exists(path):
            return path
    return None

def send_rpc_command(cmd, args=None):
    socket_path = find_ipc_socket()
    if not socket_path:
        return False, "IPC socket not found"

    if args is None:
        args = {}

    payload = {
        "cmd": cmd,
        "args": args,
        "nonce": str(uuid.uuid4())
    }

    data = json.dumps(payload).encode('utf-8')
    opcode = 1 # FRAME
    header = struct.pack('<II', opcode, len(data))

    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(socket_path)
        sock.sendall(header + data)
        
        # Read response header
        resp_hdr = sock.recv(8)
        if len(resp_hdr) == 8:
            _, resp_len = struct.unpack('<II', resp_hdr)
            resp_data = sock.recv(resp_len)
            sock.close()
            return True, json.loads(resp_data.decode('utf-8'))
        sock.close()
        return True, "Sent"
    except Exception as e:
        return False, str(e)

def load_channels():
    if not os.path.exists(CONFIG_PATH):
        return []
    try:
        with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return []

def save_channels(channels):
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
        json.dump(channels, f, indent=2, ensure_ascii=False)

def join_channel(guild_id, channel_id):
    # Try RPC socket first
    success, resp = send_rpc_command("SELECT_VOICE_CHANNEL", {
        "channel_id": channel_id,
        "timeout": 10,
        "force": True
    })
    
    # Always send deep link as reliable backup or primary trigger for Discord UI
    uri = f"discord://discord.com/channels/{guild_id}/{channel_id}"
    subprocess.Popen(["xdg-open", uri], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    return True, "Joined"

def leave_voice():
    send_rpc_command("SELECT_VOICE_CHANNEL", {"channel_id": None})
    return True, "Disconnected"

def launch_discord():
    # Check flatpak or binary
    if subprocess.call(["which", "discord"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
        subprocess.Popen(["discord"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif subprocess.call(["which", "flatpak"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
        subprocess.Popen(["flatpak", "run", "com.discordapp.Discord"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif subprocess.call(["which", "vesktop"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
        subprocess.Popen(["vesktop"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def add_channel(server, channel, guild_id, channel_id, color="#5865F2", icon="󰍡"):
    channels = load_channels()
    channels.append({
        "server": server,
        "channel": channel,
        "guild_id": guild_id,
        "channel_id": channel_id,
        "color": color,
        "icon": icon
    })
    save_channels(channels)
    print(json.dumps({"status": "ok"}))

def remove_channel(idx):
    channels = load_channels()
    if 0 <= idx < len(channels):
        channels.pop(idx)
        save_channels(channels)
        print(json.dumps({"status": "ok"}))
    else:
        print(json.dumps({"status": "error", "message": "Index out of bounds"}))

def main():
    if len(sys.argv) < 2:
        print("Usage: discord_voice.py [list|join|leave|launch|add|remove] ...")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "list":
        print(json.dumps(load_channels(), ensure_ascii=False))
    elif cmd == "join":
        if len(sys.argv) >= 4:
            guild_id = sys.argv[2]
            channel_id = sys.argv[3]
            join_channel(guild_id, channel_id)
        else:
            print("Usage: discord_voice.py join <guild_id> <channel_id>")
    elif cmd == "leave":
        leave_voice()
    elif cmd == "launch":
        launch_discord()
    elif cmd == "add":
        if len(sys.argv) >= 6:
            server = sys.argv[2]
            channel = sys.argv[3]
            guild_id = sys.argv[4]
            channel_id = sys.argv[5]
            color = sys.argv[6] if len(sys.argv) > 6 else "#5865F2"
            icon = sys.argv[7] if len(sys.argv) > 7 else "󰍡"
            add_channel(server, channel, guild_id, channel_id, color, icon)
        else:
            print("Usage: discord_voice.py add <server> <channel> <guild_id> <channel_id> [color] [icon]")
    elif cmd == "remove":
        if len(sys.argv) >= 3:
            remove_channel(int(sys.argv[2]))
    else:
        print("Unknown command")

if __name__ == "__main__":
    main()
