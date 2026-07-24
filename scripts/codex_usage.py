#!/usr/bin/env python3
"""Expose Codex's weekly ChatGPT quota as a Waybar custom module.

The script deliberately asks the local Codex app-server for account data.  It
never reads or prints the OAuth credentials in ~/.codex/auth.json.
"""

import argparse
import datetime as dt
import json
import select
import subprocess
import sys
import time
from typing import Any

WEEK_MINUTES = 7 * 24 * 60
WARNING_PERCENT = 80
CRITICAL_PERCENT = 95


def read_rate_limits(timeout: float = 20.0) -> dict[str, Any]:
    """Read the authenticated account rate limits through Codex app-server."""
    process = subprocess.Popen(
        ["codex", "app-server", "--stdio"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    assert process.stdin is not None
    assert process.stdout is not None

    def request(message: dict[str, Any]) -> dict[str, Any]:
        process.stdin.write(json.dumps(message) + "\n")
        process.stdin.flush()
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            ready, _, _ = select.select([process.stdout], [], [], 0.5)
            if not ready:
                continue
            reply = json.loads(process.stdout.readline())
            if reply.get("id") == message["id"]:
                if "error" in reply:
                    raise RuntimeError(reply["error"].get("message", "Codex app-server error"))
                return reply["result"]
        raise TimeoutError(f"Timed out waiting for {message['method']}")

    try:
        request(
            {
                "id": 1,
                "method": "initialize",
                "params": {
                    "clientInfo": {"name": "waybar-codex-usage", "version": "1.0.0"},
                    "capabilities": {},
                },
            }
        )
        return request({"id": 2, "method": "account/rateLimits/read", "params": {}})
    finally:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()


def make_waybar_payload(result: dict[str, Any], now: int | None = None) -> dict[str, str]:
    """Turn Codex's weekly quota result into Waybar's custom-module JSON."""
    limits = result.get("rateLimits") or {}
    primary = limits.get("primary") or {}
    duration = primary.get("windowDurationMins")
    if duration != WEEK_MINUTES:
        raise ValueError(f"Codex did not return a weekly limit (got {duration!r} minutes)")

    used = int(primary["usedPercent"])
    if used >= CRITICAL_PERCENT:
        css_class = "critical"
    elif used >= WARNING_PERCENT:
        css_class = "warning"
    else:
        css_class = "normal"

    tooltip_lines = [f"Weekly usage: {used}%"]
    plan = limits.get("planType")
    if plan:
        tooltip_lines.append(f"Plan: {plan}")
    resets_at = primary.get("resetsAt")
    if resets_at:
        reset_time = dt.datetime.fromtimestamp(int(resets_at), tz=dt.timezone.utc).astimezone()
        tooltip_lines.append(f"Resets: {reset_time:%Y-%m-%d %H:%M %Z}")

    return {"text": f"󰚩 W {used}%", "tooltip": "\n".join(tooltip_lines), "class": css_class}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate Codex access and print a text status")
    args = parser.parse_args()
    try:
        payload = make_waybar_payload(read_rate_limits())
    except (FileNotFoundError, OSError, RuntimeError, TimeoutError, ValueError, KeyError, json.JSONDecodeError) as exc:
        if args.check:
            print(f"Codex status check failed: {exc}", file=sys.stderr)
        else:
            print(json.dumps({"text": "󰚩 unavailable", "tooltip": str(exc), "class": "critical"}))
        return 1

    if args.check:
        print(payload["tooltip"].replace("\n", " | "))
    else:
        print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
