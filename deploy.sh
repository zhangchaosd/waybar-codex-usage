#!/usr/bin/env bash
# Install/update the Codex weekly-usage module in the current user's Waybar.
set -euo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WAYBAR_DIR=${XDG_CONFIG_HOME:-"$HOME/.config"}/waybar
INSTALL_DIR=${XDG_DATA_HOME:-"$HOME/.local/share"}/waybar-codex-usage
CONFIG="$WAYBAR_DIR/config.jsonc"
STYLE="$WAYBAR_DIR/style.css"

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

command -v python3 >/dev/null || fail 'python3 is required.'
command -v codex >/dev/null || fail 'Codex CLI was not found in PATH.'
command -v waybar >/dev/null || fail 'Waybar was not found in PATH.'

printf 'Checking Codex login and weekly quota access...\n'
codex login status >/dev/null || fail 'Codex is not logged in. Run: codex login'
python3 "$PROJECT_DIR/scripts/codex_usage.py" --check || fail 'Could not read the Codex weekly quota.'

mkdir -p "$WAYBAR_DIR" "$INSTALL_DIR"
install -m 0755 "$PROJECT_DIR/scripts/codex_usage.py" "$INSTALL_DIR/codex_usage.py"

# Start from Fedora's shipped Waybar configuration when the user has none.
if [[ ! -f "$CONFIG" ]]; then
    [[ -f /etc/xdg/waybar/config.jsonc ]] || fail "No Waybar config at $CONFIG or /etc/xdg/waybar/config.jsonc"
    cp /etc/xdg/waybar/config.jsonc "$CONFIG"
    printf 'Created user config: %s\n' "$CONFIG"
fi
if [[ ! -f "$STYLE" ]]; then
    [[ -f /etc/xdg/waybar/style.css ]] || fail "No Waybar style at $STYLE or /etc/xdg/waybar/style.css"
    cp /etc/xdg/waybar/style.css "$STYLE"
    printf 'Created user stylesheet: %s\n' "$STYLE"
fi

python3 - "$CONFIG" "$INSTALL_DIR/codex_usage.py" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
script = sys.argv[2]
text = path.read_text()
if '"custom/codex-usage"' not in text:
    modules = re.search(r'("modules-right"\s*:\s*\[)', text)
    if not modules:
        raise SystemExit('Could not find "modules-right" in Waybar config; no files changed.')
    text = text[:modules.end()] + '\n        "custom/codex-usage",' + text[modules.end():]
    module = f'''\n    "custom/codex-usage": {{
        "exec": "{script}",
        "return-type": "json",
        "interval": 60,
        "tooltip": true
    }},\n'''
    closing = text.rfind('}')
    if closing < 0:
        raise SystemExit('Could not find the end of Waybar config; no files changed.')
    text = text[:closing].rstrip() + ',\n' + module + text[closing:]
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(text)
    temporary.replace(path)
PY

if ! grep -q 'waybar-codex-usage:start' "$STYLE"; then
    cat >>"$STYLE" <<'CSS'

/* waybar-codex-usage:start */
#custom-codex-usage {
    padding: 0 10px;
    background-color: #5865f2;
    color: #ffffff;
}
#custom-codex-usage.warning {
    background-color: #f0932b;
    color: #000000;
}
#custom-codex-usage.critical {
    background-color: #eb4d4b;
    color: #ffffff;
}
/* waybar-codex-usage:end */
CSS
fi

if pgrep -x waybar >/dev/null; then
    pkill -SIGUSR2 -x waybar
    printf 'Waybar reloaded.\n'
else
    printf 'Installed. Start or restart Waybar to display the module.\n'
fi
printf 'Installed Codex weekly-usage module.\n'
