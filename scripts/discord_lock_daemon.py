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
        return {} if "activewindow" in cmd else []
    try:
        return json.loads(out)
    except Exception:
        return {} if "activewindow" in cmd else []

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

    was_maximized = False
    open_time = 0

    while True:
        try:
            if os.path.exists(widget_file):
                with open(widget_file, "r") as f:
                    status = f.read().strip()
            else:
                status = ""

            clients = get_json(["clients", "-j"])
            discord_win = None
            if isinstance(clients, list):
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

                # Reset open_time if Discord is hidden
                if not is_visible or status != "discord":
                    open_time = 0

                # Only auto-close Discord if another active Quickshell widget is explicitly open
                if status in OTHER_WIDGETS and is_visible:
                    if is_pinned:
                        run_hyprctl(["dispatch", "pin", f"address:{addr}"])
                    run_hyprctl(["dispatch", "movetoworkspacesilent", f"special:discord_widget,address:{addr}"])
                    was_maximized = False
                    open_time = 0

                elif status == "discord" and is_visible:
                    if open_time == 0:
                        open_time = time.time()

                    # Auto-hide if user clicks outside Discord window (focus loss)
                    if time.time() - open_time > 0.35:
                        active_win = get_json(["activewindow", "-j"])
                        active_addr = active_win.get("address", "") if isinstance(active_win, dict) else ""
                        active_pid = active_win.get("pid") if isinstance(active_win, dict) else None
                        discord_pid = discord_win.get("pid")

                        if active_addr != addr and active_pid != discord_pid:
                            if is_pinned:
                                run_hyprctl(["dispatch", "pin", f"address:{addr}"])
                            run_hyprctl(["dispatch", "movetoworkspacesilent", f"special:discord_widget,address:{addr}"])
                            with open(widget_file, "w") as f:
                                f.write("")
                            was_maximized = False
                            open_time = 0
                            time.sleep(0.05)
                            continue

                    # Anchor Discord strictly to the monitor where the widget was opened
                    monitors = get_json(["monitors", "-j"])
                    target_mon_name = ""
                    if os.path.exists(mon_file):
                        with open(mon_file, "r") as f:
                            target_mon_name = f.read().strip()

                    target_mon = None
                    if target_mon_name and isinstance(monitors, list):
                        for m in monitors:
                            if m.get("name") == target_mon_name:
                                target_mon = m
                                break

                    if not target_mon and isinstance(monitors, list):
                        for m in monitors:
                            if m.get("focused"):
                                target_mon = m
                                break
                    if not target_mon and isinstance(monitors, list) and monitors:
                        target_mon = monitors[0]

                    if not target_mon:
                        target_mon = {}

                    mon_x = target_mon.get("x", 0)
                    mon_y = target_mon.get("y", 0)
                    mon_w = target_mon.get("width", 1920)
                    mon_h = target_mon.get("height", 1080)
                    mon_scale = target_mon.get("scale", 1.0)
                    logical_w = int(mon_w / mon_scale)
                    logical_h = int(mon_h / mon_scale)

                    curr_size = discord_win.get("size", [480, 680])
                    curr_w, curr_h = curr_size[0], curr_size[1]

                    is_hypr_fullscreen = (discord_win.get("fullscreen", 0) != 0) or (discord_win.get("fullscreenClient", 0) != 0)
                    is_size_maximized = (curr_w >= logical_w - 80) and (curr_h >= logical_h - 120)

                    is_maximized = is_hypr_fullscreen or is_size_maximized

                    if is_maximized:
                        was_maximized = True
                        time.sleep(0.05)
                        continue

                    # If window was just un-maximized, restore default widget size first
                    if was_maximized:
                        was_maximized = False
                        run_hyprctl(["dispatch", "resizewindowpixel", f"exact 480 680,address:{addr}"])
                        time.sleep(0.05)
                        clients = get_json(["clients", "-j"])
                        if isinstance(clients, list):
                            for c in clients:
                                if c.get("address") == addr:
                                    discord_win = c
                                    break

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
