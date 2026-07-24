#!/usr/bin/env bash
# Install/update the Codex weekly-remaining module in the current user's Waybar.
set -euo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WAYBAR_DIR=${XDG_CONFIG_HOME:-"$HOME/.config"}/waybar
INSTALL_DIR=${XDG_DATA_HOME:-"$HOME/.local/share"}/waybar-codex-usage
CONFIG="$WAYBAR_DIR/config.jsonc"
STYLE="$WAYBAR_DIR/style.css"
ICON_SOURCE="$PROJECT_DIR/assets/codex-mark-white.png"

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

command -v python3 >/dev/null || fail 'python3 is required.'
command -v codex >/dev/null || fail 'Codex CLI was not found in PATH.'
command -v waybar >/dev/null || fail 'Waybar was not found in PATH.'
[[ -f "$ICON_SOURCE" ]] || fail "Processed Codex icon was not found: $ICON_SOURCE"

printf 'Checking Codex login and weekly quota access...\n'
codex login status >/dev/null || fail 'Codex is not logged in. Run: codex login'
python3 "$PROJECT_DIR/scripts/codex_usage.py" --check || fail 'Could not read the Codex weekly quota.'

mkdir -p "$WAYBAR_DIR" "$INSTALL_DIR"
install -m 0755 "$PROJECT_DIR/scripts/codex_usage.py" "$INSTALL_DIR/codex_usage.py"
install -m 0644 "$ICON_SOURCE" "$INSTALL_DIR/codex-mark-white.png"

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

python3 - "$CONFIG" "$STYLE" "$INSTALL_DIR/codex_usage.py" "$INSTALL_DIR/codex-mark-white.png" <<'PY'
import json
import pathlib
import re
import sys

config_path = pathlib.Path(sys.argv[1])
style_path = pathlib.Path(sys.argv[2])
script = sys.argv[3]
icon = sys.argv[4]
text = config_path.read_text()

layout = re.search(r'("modules-right"\s*:\s*\[)(?P<body>.*?)(\])', text, re.DOTALL)
if not layout:
    raise SystemExit('Could not find "modules-right" in Waybar config; no files changed.')
body = layout.group('body')
if '"group/codex-usage"' not in body:
    if '"custom/codex-usage"' in body:
        body = body.replace('"custom/codex-usage"', '"group/codex-usage"', 1)
    else:
        body = '\n        "group/codex-usage",' + body
    text = text[:layout.start('body')] + body + text[layout.end('body'):]

# Remove only this project's simple module definitions, then append a normalized
# set. This upgrades older deployments without duplicating modules.
def remove_definition(source: str, name: str) -> str:
    pattern = re.compile(
        r'(?ms)^[ \t]*"' + re.escape(name) + r'"\s*:\s*\{.*?^[ \t]*\},?\s*\n?'
    )
    return pattern.sub('', source)

for module_name in ('custom/codex-usage', 'image#codex-icon', 'group/codex-usage'):
    text = remove_definition(text, module_name)

custom_module = f'''    "custom/codex-usage": {{
        "format": "{{text}}",
        "exec": {json.dumps(script)},
        "return-type": "json",
        "interval": 60,
        "tooltip": true
    }}'''
image_module = f'''    "image#codex-icon": {{
        "path": {json.dumps(icon)},
        "size": 14,
        "tooltip": false
    }}'''
group_module = '''    "group/codex-usage": {
        "orientation": "horizontal",
        "modules": [
            "custom/codex-usage",
            "image#codex-icon"
        ]
    }'''

closing = text.rfind('}')
if closing < 0:
    raise SystemExit('Could not find the end of Waybar config; no files changed.')
prefix = text[:closing].rstrip()
if not prefix.endswith(','):
    prefix += ','
definitions = ',\n'.join((custom_module, image_module, group_module))
text = prefix + '\n\n' + definitions + ',\n' + text[closing:]

temporary = config_path.with_suffix(config_path.suffix + '.tmp')
temporary.write_text(text)
temporary.replace(config_path)

style = style_path.read_text()
style_block = '''/* waybar-codex-usage:start */
#group-codex-usage,
#custom-codex-usage,
#image.codex-icon {
    background-color: #5865f2;
    color: #ffffff;
}
#group-codex-usage {
    padding: 0;
}
#custom-codex-usage {
    padding: 0 2px 0 10px;
}
#image.codex-icon {
    padding: 0 8px 0 2px;
}
/* waybar-codex-usage:end */'''
block_pattern = re.compile(
    r'/\* waybar-codex-usage:start \*/.*?/\* waybar-codex-usage:end \*/',
    re.DOTALL,
)
if block_pattern.search(style):
    style = block_pattern.sub(style_block, style)
else:
    style = style.rstrip() + '\n\n' + style_block + '\n'
style_temporary = style_path.with_suffix(style_path.suffix + '.tmp')
style_temporary.write_text(style)
style_temporary.replace(style_path)
PY

if pgrep -x waybar >/dev/null; then
    pkill -SIGUSR2 -x waybar
    printf 'Waybar reloaded.\n'
else
    printf 'Installed. Start or restart Waybar to display the module.\n'
fi
printf 'Installed Codex weekly-remaining module.\n'
