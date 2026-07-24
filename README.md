# Waybar Codex Weekly Usage

A small Waybar custom module for Linux that displays the weekly Codex quota of the ChatGPT account currently logged in through the local `codex` CLI.

Example block:

```text
󰚩 W 37%
```

The percentage is usage consumed, not quota remaining. The tooltip shows the current plan and the local reset time. The block becomes orange at 80% and red at 95%.

## Why it uses `codex app-server`

The module calls `codex app-server --stdio` and asks it for `account/rateLimits/read`. This lets Codex use and refresh its own login state; the module never reads, exports, or logs OAuth tokens.

Codex's current account response is validated as a weekly (10,080-minute) limit. This project intentionally does not show the retired 5-hour quota.

## Requirements

- Waybar
- Python 3.10+
- Codex CLI in `PATH`
- An active ChatGPT login in Codex (`codex login`)

## Install / update

```bash
./deploy.sh
```

The deployer first checks `codex login status` and makes a real weekly-quota query. It exits without changing Waybar if either check fails.

On success it:

1. Installs the module script under `~/.local/share/waybar-codex-usage/`.
2. Creates `~/.config/waybar/config.jsonc` and `style.css` from Fedora's defaults only when they do not exist.
3. Adds `custom/codex-usage` to the right side of Waybar and adds its CSS once (idempotently).
4. Reloads an already-running Waybar with `SIGUSR2`.

The user-level Waybar files are used deliberately so package updates do not overwrite the customization.

## Manual check

```bash
python3 scripts/codex_usage.py --check
python3 scripts/codex_usage.py
```

The first prints a human-readable result; the second emits Waybar JSON.

The last successful quota response is cached under
`~/.cache/waybar-codex-usage/payload.json`. If the Codex usage endpoint is
temporarily unavailable, Waybar keeps displaying that cached value and notes
the refresh failure in the tooltip instead of hiding the module.

## Test

```bash
python3 -m unittest discover -s tests -v
```

## Uninstall

Remove the `custom/codex-usage` entry and module definition from `~/.config/waybar/config.jsonc`, remove the CSS block delimited by `waybar-codex-usage:start/end` in `~/.config/waybar/style.css`, then run:

```bash
rm -rf ~/.local/share/waybar-codex-usage
pkill -SIGUSR2 -x waybar
```

## License

MIT
