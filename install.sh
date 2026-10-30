#!/usr/bin/env bash
# Install audacity-quicksave for the current user.
#
#   ./install.sh                  install with the default shortcut (Ctrl+Alt+S)
#   ./install.sh --shortcut KEY   use another GNOME accelerator, e.g. '<Super>s'
#   ./install.sh --no-shortcut    do not create a keyboard shortcut

set -euo pipefail

NAME="audacity-quicksave"
BIN_DIR="${HOME}/.local/bin"
TARGET="${BIN_DIR}/${NAME}"
SHORTCUT="<Primary><Alt>s"
ADD_SHORTCUT=1
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [ $# -gt 0 ]; do
    case "$1" in
        --shortcut) SHORTCUT="$2"; shift 2 ;;
        --no-shortcut) ADD_SHORTCUT=0; shift ;;
        -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

say()  { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }

# 1. Requirements -----------------------------------------------------------
if ! command -v python3 >/dev/null; then
    echo "python3 is required." >&2; exit 1
fi
if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 8))'; then
    echo "Python 3.8 or newer is required." >&2; exit 1
fi
if ! command -v ffmpeg >/dev/null || ! command -v ffprobe >/dev/null; then
    warn "ffmpeg and ffprobe were not found. Install them with:"
    warn "    sudo apt install ffmpeg"
fi
if ! command -v notify-send >/dev/null; then
    warn "notify-send was not found, so you will not see desktop notifications."
    warn "    sudo apt install libnotify-bin"
fi

# 2. Install the script -----------------------------------------------------
mkdir -p "$BIN_DIR"
# Development builds ran a background helper: stop it before replacing them.
if [ -x "$TARGET" ]; then "$TARGET" --stop >/dev/null 2>&1 || true; fi
install -m 755 "$HERE/$NAME" "$TARGET"
say "Installed $TARGET"


# 3. Keyboard shortcut (GNOME) ----------------------------------------------
if [ "$ADD_SHORTCUT" = 1 ]; then
    if command -v gsettings >/dev/null && \
       gsettings list-schemas 2>/dev/null | grep -qx org.gnome.settings-daemon.plugins.media-keys; then
        python3 - "$TARGET" "$SHORTCUT" <<'PY'
import ast, subprocess, sys

target, accel = sys.argv[1], sys.argv[2]
schema = "org.gnome.settings-daemon.plugins.media-keys"
base = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"

def get(key, path=None):
    s = f"{schema}.custom-keybinding:{path}" if path else schema
    out = subprocess.run(["gsettings", "get", s, key],
                         capture_output=True, text=True).stdout.strip()
    return out

def set_(key, value, path=None):
    s = f"{schema}.custom-keybinding:{path}" if path else schema
    subprocess.run(["gsettings", "set", s, key, value], check=True)

raw = get("custom-keybindings")
paths = [] if raw.startswith("@as") else ast.literal_eval(raw or "[]")

mine, used = None, set()
for p in paths:
    cmd = get("command", p).strip("'")
    binding = get("binding", p).strip("'")
    if cmd.endswith("audacity-quicksave"):
        mine = p
    elif binding:
        used.add(binding.lower())

if accel.lower() in used:
    print(f"Warning: {accel} is already used by another custom shortcut.")

if mine is None:
    n = 0
    while f"{base}custom{n}/" in paths:
        n += 1
    mine = f"{base}custom{n}/"
    paths.append(mine)
    set_("custom-keybindings", str(paths))

set_("name", "'Audacity Quick Save'", mine)
set_("command", repr(target), mine)
set_("binding", repr(accel), mine)
print(f"Keyboard shortcut set: {accel}")
PY
    else
        warn "GNOME was not detected. Create a keyboard shortcut in your desktop settings"
        warn "that runs: $TARGET"
    fi
fi

# 4. Next steps -------------------------------------------------------------
cat <<EOF

Almost done. Enable Audacity's scripting module once:
  1. Open Audacity
  2. Edit > Preferences > Modules
  3. Set "mod-script-pipe" to "Enabled"
  4. Restart Audacity

Then open an audio file, edit it and press the shortcut to save it in place.
Backups of the previous versions go to ~/.local/state/audacity-quicksave/backups
EOF
