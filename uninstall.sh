#!/usr/bin/env bash
# Remove audacity-quicksave and its keyboard shortcut. Backups are kept.

set -euo pipefail

TARGET="${HOME}/.local/bin/audacity-quicksave"

if [ -x "$TARGET" ]; then
    "$TARGET" --stop >/dev/null 2>&1 || true
    rm -f "$TARGET"
    echo "Removed $TARGET"
fi

if command -v gsettings >/dev/null && \
   gsettings list-schemas 2>/dev/null | grep -qx org.gnome.settings-daemon.plugins.media-keys; then
    python3 - <<'PY'
import ast, subprocess

schema = "org.gnome.settings-daemon.plugins.media-keys"
raw = subprocess.run(["gsettings", "get", schema, "custom-keybindings"],
                     capture_output=True, text=True).stdout.strip()
paths = [] if raw.startswith("@as") else ast.literal_eval(raw or "[]")
keep = []
for p in paths:
    cmd = subprocess.run(["gsettings", "get", f"{schema}.custom-keybinding:{p}", "command"],
                         capture_output=True, text=True).stdout.strip().strip("'")
    if cmd.endswith("audacity-quicksave"):
        subprocess.run(["gsettings", "reset-recursively",
                        f"{schema}.custom-keybinding:{p}"], check=False)
        print("Removed keyboard shortcut")
    else:
        keep.append(p)
if keep != paths:
    subprocess.run(["gsettings", "set", schema, "custom-keybindings", str(keep)], check=True)
PY
fi

echo "Backups were kept in ~/.local/state/audacity-quicksave/backups"
echo "Restart Audacity if it is open."
