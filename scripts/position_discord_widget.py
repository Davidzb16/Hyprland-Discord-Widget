#!/usr/bin/env python3
import json
import os
import sys
import subprocess
import time

def run_hyprctl(cmd):
    try:
        res = subprocess.run(["hyprctl"] + cmd, capture_output=True, text=True, check=True)
        return res.stdout
    except Exception:
        return ""

def get_json(cmd):
    out = run_hyprctl(cmd)
    if not out:
        return []
    try:
        return json.loads(out)
    except Exception:
        return []

def main():
    clients = get_json(["clients", "-j"])
    monitors = get_json(["monitors", "-j"])
    active_ws = get_json(["activeworkspace", "-j"])

    discord_win = None
    for c in clients:
        c_class = c.get("class", "").lower()
        if c_class in ["discord", "com.discordapp.discord", "vesktop"]:
            discord_win = c
            break

    # If Discord not running, launch it
    if not discord_win:
        if subprocess.call(["which", "flatpak"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
            subprocess.Popen(["flatpak", "run", "com.discordapp.Discord"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif subprocess.call(["which", "discord"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
            subprocess.Popen(["discord"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1.5)
        clients = get_json(["clients", "-j"])
        for c in clients:
            c_class = c.get("class", "").lower()
            if c_class in ["discord", "com.discordapp.discord", "vesktop"]:
                discord_win = c
                break

    if not discord_win:
        sys.exit(1)

    addr = discord_win.get("address")

    # Determine focused monitor
    focused_mon = None
    for m in monitors:
        if m.get("focused"):
            focused_mon = m
            break
    if not focused_mon and monitors:
        focused_mon = monitors[0]

    mon_x = focused_mon.get("x", 0)
    mon_y = focused_mon.get("y", 0)
    mon_w = focused_mon.get("width", 1920)
    mon_scale = focused_mon.get("scale", 1.0)
    mon_name = focused_mon.get("name", "")

    logical_w = int(mon_w / mon_scale)

    curr_ws_id = active_ws.get("id")
    win_ws_id = discord_win.get("workspace", {}).get("id")
    win_ws_name = str(discord_win.get("workspace", {}).get("name", ""))
    is_pinned = discord_win.get("pinned", False)

    run_dir = os.path.expanduser("~/.local/state/quickshell")
    if "XDG_RUNTIME_DIR" in os.environ:
        run_dir = os.path.join(os.environ["XDG_RUNTIME_DIR"], "quickshell")
    os.makedirs(run_dir, exist_ok=True)
    widget_file = os.path.join(run_dir, "current_widget")
    mon_file = os.path.join(run_dir, "discord_monitor")

    # Check if currently visible on active workspace
    is_visible_current = (win_ws_name != "special:discord_widget") and (not discord_win.get("hidden", False)) and (win_ws_id == curr_ws_id or is_pinned)

    if is_visible_current:
        # Hide Discord cleanly
        if (discord_win.get("fullscreen", 0) != 0) or (discord_win.get("fullscreenClient", 0) != 0):
            run_hyprctl(["dispatch", "focuswindow", f"address:{addr}"])
            run_hyprctl(["dispatch", "fullscreen", "0"])

        if is_pinned:
            run_hyprctl(["dispatch", "pin", f"address:{addr}"])
        
        with open(widget_file, "w") as f:
            f.write("")

        run_hyprctl(["dispatch", "movetoworkspacesilent", f"special:discord_widget,address:{addr}"])
    else:
        # Close any currently active Quickshell widget first
        shell_qml = os.path.expanduser("~/.config/hypr/scripts/quickshell/Shell.qml")
        if os.path.exists(shell_qml):
            subprocess.run(["quickshell", "-p", shell_qml, "ipc", "call", "main", "handleCommand", "close", "", ""], capture_output=True)

        # Lock monitor name for this widget session
        with open(mon_file, "w") as f:
            f.write(mon_name)

        # Mark current_widget as "discord"
        with open(widget_file, "w") as f:
            f.write("discord")

        # Un-fullscreen if needed
        if (discord_win.get("fullscreen", 0) != 0) or (discord_win.get("fullscreenClient", 0) != 0):
            run_hyprctl(["dispatch", "focuswindow", f"address:{addr}"])
            run_hyprctl(["dispatch", "fullscreen", "0"])

        target_w = 480
        target_h = 680

        # 1) Position off-screen above top bar and bring to active workspace
        run_hyprctl(["--batch", f"dispatch setfloating address:{addr};dispatch movetoworkspacesilent {curr_ws_id},address:{addr}"])
        run_hyprctl(["dispatch", "resizewindowpixel", f"exact {target_w} {target_h},address:{addr}"])

        # 2) Fetch actual window size
        updated_clients = get_json(["clients", "-j"])
        actual_w = target_w
        for c in updated_clients:
            if c.get("address") == addr:
                actual_w = c.get("size", [target_w, target_h])[0]
                break

        margin = 16
        pos_x = int(mon_x + logical_w - actual_w - margin)
        if pos_x < mon_x:
            pos_x = mon_x
        pos_y = int(mon_y + round(60 * mon_scale))

        # 3) Animate sliding down from top bar into widget position
        batch_cmds = [
            f"dispatch movewindowpixel exact {pos_x} {pos_y},address:{addr}",
            f"dispatch pin address:{addr}",
            f"dispatch focuswindow address:{addr}"
        ]
        run_hyprctl(["--batch", ";".join(batch_cmds)])
        
        with open(widget_file, "w") as f:
            f.write("discord")

if __name__ == "__main__":
    main()
