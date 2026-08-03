#!/usr/bin/env python3
import json
import subprocess
import os

def run_hyprctl(cmd):
    res = subprocess.run(["hyprctl"] + cmd, capture_output=True, text=True)
    return res.stdout

def main():
    run_dir = os.path.expanduser("~/.local/state/quickshell")
    if "XDG_RUNTIME_DIR" in os.environ:
        run_dir = os.path.join(os.environ["XDG_RUNTIME_DIR"], "quickshell")
    widget_file = os.path.join(run_dir, "current_widget")

    if not os.path.exists(widget_file):
        return
    with open(widget_file, "r") as f:
        if f.read().strip() != "discord":
            return

    cursor_out = run_hyprctl(["cursorpos"])
    try:
        parts = cursor_out.split(",")
        cur_x = int(parts[0].strip())
        cur_y = int(parts[1].strip())
    except:
        return

    clients_out = run_hyprctl(["clients", "-j"])
    try:
        clients = json.loads(clients_out)
    except:
        return

    for c in clients:
        if c.get("class", "").lower() in ["discord", "com.discordapp.discord", "vesktop"]:
            at_x, at_y = c.get("at", [0, 0])
            w, h = c.get("size", [0, 0])
            
            # Check if outside
            if cur_x < at_x or cur_x > at_x + w or cur_y < at_y or cur_y > at_y + h:
                with open(widget_file, "w") as f:
                    f.write("")
            break

if __name__ == "__main__":
    main()
