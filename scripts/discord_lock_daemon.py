#!/usr/bin/env python3
import os
import sys
import time
import json
import subprocess

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
    run_dir = os.path.expanduser("~/.local/state/quickshell")
    if "XDG_RUNTIME_DIR" in os.environ:
        run_dir = os.path.join(os.environ["XDG_RUNTIME_DIR"], "quickshell")
    os.makedirs(run_dir, exist_ok=True)
    widget_file = os.path.join(run_dir, "current_widget")
    mon_file = os.path.join(run_dir, "discord_monitor")

    OTHER_WIDGETS = [
        "network", "battery", "volume", "calendar", "settings",
        "applauncher", "clipboard", "music", "focustime", "stewart",
        "updater", "guide", "movies", "wallpaper"
    ]

    was_fullscreen = False

    while True:
        try:
            if os.path.exists(widget_file):
                with open(widget_file, "r") as f:
                    status = f.read().strip()
            else:
                status = ""

            clients = get_json(["clients", "-j"])
            discord_win = None
            for c in clients:
                if c.get("class", "").lower() in ["discord", "com.discordapp.discord", "vesktop"]:
                    discord_win = c
                    break

            if discord_win:
                addr = discord_win.get("address")
                win_ws_name = discord_win.get("workspace", {}).get("name", "")
                is_pinned = discord_win.get("pinned", False)
                is_hidden = discord_win.get("hidden", False)

                is_visible = (win_ws_name != "special:discord_widget") and (not is_hidden)

                # Only auto-close Discord if another active Quickshell widget is explicitly open
                if status in OTHER_WIDGETS and is_visible:
                    if is_pinned:
                        run_hyprctl(["dispatch", "pin", f"address:{addr}"])
                    run_hyprctl(["dispatch", "movetoworkspacesilent", f"special:discord_widget,address:{addr}"])
                    was_fullscreen = False

                elif status == "discord" and is_visible:
                    is_fullscreen = (discord_win.get("fullscreen", 0) != 0) or (discord_win.get("fullscreenClient", 0) != 0)

                    if is_fullscreen:
                        was_fullscreen = True
                        time.sleep(0.05)
                        continue

                    # If window was just un-maximized, restore default widget size first
                    if was_fullscreen:
                        was_fullscreen = False
                        run_hyprctl(["dispatch", "resizewindowpixel", f"exact 480 680,address:{addr}"])
                        time.sleep(0.05)
                        clients = get_json(["clients", "-j"])
                        for c in clients:
                            if c.get("address") == addr:
                                discord_win = c
                                break

                    # Anchor Discord strictly to the monitor where the widget was opened
                    monitors = get_json(["monitors", "-j"])
                    target_mon_name = ""
                    if os.path.exists(mon_file):
                        with open(mon_file, "r") as f:
                            target_mon_name = f.read().strip()

                    target_mon = None
                    if target_mon_name:
                        for m in monitors:
                            if m.get("name") == target_mon_name:
                                target_mon = m
                                break

                    if not target_mon:
                        for m in monitors:
                            if m.get("focused"):
                                target_mon = m
                                break
                    if not target_mon and monitors:
                        target_mon = monitors[0]

                    mon_x = target_mon.get("x", 0)
                    mon_y = target_mon.get("y", 0)
                    mon_w = target_mon.get("width", 1920)
                    mon_scale = target_mon.get("scale", 1.0)
                    logical_w = int(mon_w / mon_scale)

                    actual_w = discord_win.get("size", [480, 680])[0]
                    margin = 16
                    target_x = int(mon_x + logical_w - actual_w - margin)
                    if target_x < mon_x:
                        target_x = mon_x
                    target_y = int(mon_y + round(60 * mon_scale))

                    curr_at = discord_win.get("at", [0, 0])

                    # Snap back if user dragged window or pointer moved across screens
                    if abs(curr_at[0] - target_x) > 2 or abs(curr_at[1] - target_y) > 2:
                        run_hyprctl(["dispatch", "movewindowpixel", f"exact {target_x} {target_y},address:{addr}"])

            time.sleep(0.05)
        except Exception:
            time.sleep(0.2)

if __name__ == "__main__":
    main()
