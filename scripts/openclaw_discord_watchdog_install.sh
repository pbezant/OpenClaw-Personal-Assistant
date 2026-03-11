#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Installing healthcheck script..."
cat >/usr/local/bin/openclaw-discord-healthcheck.sh <<'EOF'
set -euo pipefail
STATUS="$(openclaw channels status --probe 2>&1 || true)"
LINE="$(printf "%s\n" "$STATUS" | grep -E "Discord default:" | tail -n1 || true)"
if printf "%s" "$LINE" | grep -Eq "running, connected,"; then
	logger -t openclaw-discord-healthcheck "healthy(connected)"
	exit 0
fi
if printf "%s" "$LINE" | grep -Eq "in:(just now|[0-4]m ago)"; then
	logger -t openclaw-discord-healthcheck "healthy(recent-inbound)"
	exit 0
fi
logger -t openclaw-discord-healthcheck "unhealthy -> restarting gateway"
systemctl restart openclaw-gateway
sleep 8
POST="$(openclaw channels status --probe 2>&1 || true)"
POSTLINE="$(printf "%s\n" "$POST" | grep -E "Discord default:" | tail -n1 || true)"
logger -t openclaw-discord-healthcheck "post-restart state: ${POSTLINE:-unknown}"
exit 0
EOF

chmod +x /usr/local/bin/openclaw-discord-healthcheck.sh

echo "[2/4] Writing systemd service..."
cat >/etc/systemd/system/openclaw-discord-healthcheck.service <<'EOF'
[Unit]
Description=OpenClaw Discord channel health check
After=network-online.target openclaw-gateway.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/bin/openclaw-discord-healthcheck.sh
User=root
EOF

echo "[3/4] Writing systemd timer..."
cat >/etc/systemd/system/openclaw-discord-healthcheck.timer <<'EOF'
[Unit]
Description=Run OpenClaw Discord channel health check every 10 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=10min
AccuracySec=30s
Unit=openclaw-discord-healthcheck.service

[Install]
WantedBy=timers.target
EOF

echo "[4/4] Enabling timer and running first check..."
systemctl daemon-reload
systemctl enable --now openclaw-discord-healthcheck.timer
systemctl start openclaw-discord-healthcheck.service

echo
systemctl status openclaw-discord-healthcheck.timer --no-pager -l | tail -n 8
echo
openclaw channels status --probe

echo
echo "Done. Discord watchdog is installed."
