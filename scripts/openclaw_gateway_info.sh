#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
OPENCLAW_HOST="${OPENCLAW_HOST:-${1:-192.168.1.100}}"
SHOW_TOKEN="${SHOW_TOKEN:-0}"

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "OpenClaw config not found at ${CONFIG_PATH}" >&2
  exit 1
fi

python3 - <<'PY' "$CONFIG_PATH" "$OPENCLAW_HOST" "$SHOW_TOKEN"
import json, sys
config_path, host, show = sys.argv[1:4]
with open(config_path) as f:
    data = json.load(f)

gateway = data.get('gateway', {})
auth = gateway.get('auth', {})
token = auth.get('token')
print(f"Gateway URL: https://{host}/config")
print(f"Gateway auth mode: {auth.get('mode', 'unknown')}")
if show == '1':
    print(f"Gateway token: {token or '<missing>'}")
else:
    masked = '<missing>' if not token else ('*' * max(0, len(token) - 6) + token[-6:])
    print(f"Gateway token: {masked} (set SHOW_TOKEN=1 to reveal)")
print("Remote gateway token: leave blank unless using split-host remote mode")
print("Tip: paste the gateway token into Control UI settings on a new phone/browser.")
PY
