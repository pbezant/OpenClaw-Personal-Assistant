#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — Sync OpenClaw workspace to server and (re)start the Discord bot
#
# Usage:
#   ./deploy.sh                  # sync + restart
#   ./deploy.sh --sync-only      # rsync only, skip restart
#   ./deploy.sh --restart-only   # skip rsync, just restart the service
#
# Prerequisites on local machine:
#   - SSH key auth to the server (no password prompt)
#   - rsync installed
#
# Prerequisites on server (192.168.1.246):
#   - Python 3.11+ available at /usr/bin/python3 or via pyenv
#   - systemd (the service file handles venv creation on first run)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Config (edit these if your setup differs) ─────────────────────────────────
SERVER_HOST="${OPENCLAW_HOST:-192.168.1.246}"
SERVER_USER="${OPENCLAW_USER:-root}"
REMOTE_DIR="/root/openclaw/workspace"
SERVICE_NAME="openclaw-bot"

# ── Argument parsing ──────────────────────────────────────────────────────────
SYNC_ONLY=false
RESTART_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --sync-only)    SYNC_ONLY=true ;;
    --restart-only) RESTART_ONLY=true ;;
  esac
done

echo "╔══════════════════════════════════════════╗"
echo "║       OpenClaw Discord Bot Deploy        ║"
echo "╚══════════════════════════════════════════╝"
echo "  Server : ${SERVER_USER}@${SERVER_HOST}"
echo "  Remote : ${REMOTE_DIR}"
echo ""

# ── Phase 1: rsync workspace ──────────────────────────────────────────────────
if [[ "$RESTART_ONLY" == "false" ]]; then
  echo "▶ Syncing workspace to server..."
  rsync -avz --progress \
    --exclude '.git' \
    --exclude '__pycache__' \
    --exclude '*.pyc' \
    --exclude '.env' \
    --exclude '.playwright-mcp' \
    --exclude 'node_modules' \
    "$(cd "$(dirname "$0")" && pwd)/" \
    "${SERVER_USER}@${SERVER_HOST}:${REMOTE_DIR}/"
  echo "✓ Sync complete"
  echo ""
fi

# ── Phase 2: server-side setup ────────────────────────────────────────────────
if [[ "$SYNC_ONLY" == "false" ]]; then
  echo "▶ Running server-side setup and restarting bot..."

  # Resolve home dir on the server once, locally, before entering the heredoc
  OPENCLAW_HOME=$(ssh "${SERVER_USER}@${SERVER_HOST}" 'echo $HOME')

  ssh "${SERVER_USER}@${SERVER_HOST}" bash <<REMOTE_EOF
set -euo pipefail
cd "${REMOTE_DIR}"

# Create venv if it doesn't exist
if [[ ! -d venv ]]; then
  echo "  Creating Python venv..."
  python3 -m venv venv
fi

# Install/upgrade dependencies
echo "  Installing Python dependencies..."
venv/bin/pip install -q --upgrade pip
venv/bin/pip install -q -r requirements.txt

# Ensure .env exists (user must have created it from .env.example)
if [[ ! -f .env ]]; then
  echo ""
  echo "  ⚠ WARNING: No .env file found at ${REMOTE_DIR}/.env"
  echo "  Copy .env.example to .env and fill in your tokens before starting the bot."
  echo ""
else
  echo "  ✓ .env found"
fi

# Install systemd service (always re-install so paths stay current)
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
echo "  Installing systemd service..."
sed -e "s|OPENCLAW_USER|${SERVER_USER}|g" -e "s|OPENCLAW_HOME|${OPENCLAW_HOME}|g" "${REMOTE_DIR}/discord_bot.service" \
  | sudo tee "\$SERVICE_FILE" > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
echo "  ✓ Service installed and enabled"

# Restart the bot
echo "  Restarting ${SERVICE_NAME}..."
sudo systemctl restart "${SERVICE_NAME}"
sleep 2
sudo systemctl status "${SERVICE_NAME}" --no-pager -l | tail -12

echo ""
echo "  ✓ Bot is running. Tail logs with:"
echo "    ssh ${SERVER_USER}@${SERVER_HOST} 'journalctl -u ${SERVICE_NAME} -f'"

REMOTE_EOF

  echo ""
  echo "✓ Deploy complete"
fi

echo ""
echo "Quick log tail:"
echo "  ./deploy.sh --logs    (or run manually below)"
echo ""
echo "  ssh ${SERVER_USER}@${SERVER_HOST} 'journalctl -u ${SERVICE_NAME} -f --output=cat'"
