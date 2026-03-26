#!/usr/bin/env bash
# mode=generated
# var_cpu="4"
# var_ram="4096"
# var_disk="32"
set -euo pipefail
#
# Creates a Debian 12 LXC on Proxmox with:
#   - OpenClaw platform + Control UI (HTTPS via Caddy)
#   - Discord bot from the OpenClaw Personal Assistant repo
#   - SSH enabled for root
#
# Usage:  CTID=300 bash proxmox_create_openclaw_lxc.sh
#
# The user should be able to paste the one-liner and open
#   https://<container-ip>/connect
# with zero additional config.

# ── Guard rails ──────────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then echo "Run as root on the Proxmox host." >&2; exit 1; fi
for cmd in pct pveam; do command -v "$cmd" >/dev/null 2>&1 || { echo "Missing: $cmd" >&2; exit 1; }; done

# ── Configurable defaults (override via env) ─────────────────────────────
CTID="${CTID:-246}"
HOSTNAME="${HOSTNAME:-openclaw}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
ROOTFS_STORAGE="${ROOTFS_STORAGE:-local-lvm}"
DISK_SIZE_GB="${DISK_SIZE_GB:-${var_disk:-32}}"
CORES="${CORES:-${var_cpu:-4}}"
MEMORY_MB="${MEMORY_MB:-${var_ram:-4096}}"
SWAP_MB="${SWAP_MB:-1024}"
BRIDGE="${BRIDGE:-vmbr0}"
IP_CONFIG="${IP_CONFIG:-dhcp}"
GATEWAY="${GATEWAY:-}"
UNPRIVILEGED="${UNPRIVILEGED:-1}"
SSH_PUBLIC_KEY_FILE="${SSH_PUBLIC_KEY_FILE:-}"
ROOT_PASSWORD="${ROOT_PASSWORD:-ChangeMeNow123!}"

if pct status "$CTID" >/dev/null 2>&1; then
  echo "Container CTID $CTID already exists. Pick a new CTID (e.g., CTID=247)." >&2
  exit 1
fi

# Helper: extract IPv4 only (hostname -I returns IPv6 too and breaks configs)
IPV4_CMD='hostname -I | tr " " "\n" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$" | head -1'

# =====================================================================
#  PHASE 1 — Create & start the Debian 12 container
# =====================================================================
echo "[1/8] Downloading Debian 12 template..."
pveam update
TEMPLATE_NAME="$(pveam available --section system | awk '/debian-12-standard/ {print $2}' | tail -n1)"
[[ -z "$TEMPLATE_NAME" ]] && { echo "Could not find debian-12-standard template." >&2; exit 1; }
pveam download "$TEMPLATE_STORAGE" "$TEMPLATE_NAME"

NET_ARG="name=eth0,bridge=${BRIDGE},ip=${IP_CONFIG}"
[[ "$IP_CONFIG" != "dhcp" && -n "$GATEWAY" ]] && NET_ARG="${NET_ARG},gw=${GATEWAY}"

echo "[2/8] Creating container CTID ${CTID}..."
pct create "$CTID" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE_NAME}" \
  --hostname "$HOSTNAME" --cores "$CORES" --memory "$MEMORY_MB" --swap "$SWAP_MB" \
  --rootfs "${ROOTFS_STORAGE}:${DISK_SIZE_GB}" --net0 "$NET_ARG" \
  --unprivileged "$UNPRIVILEGED" --onboot 1 --password "$ROOT_PASSWORD"

pct start "$CTID"
sleep 3

# Persistent DNS (Debian uses resolv.conf, not Netplan)
pct exec "$CTID" -- bash -c "
printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf
chattr +i /etc/resolv.conf 2>/dev/null || true"
sleep 2

# =====================================================================
#  PHASE 2 — Install all packages
# =====================================================================
echo "[3/8] Installing system packages + Node.js 22..."
pct exec "$CTID" -- bash -lc "
  apt-get update -q && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-server ca-certificates curl sudo git python3-venv gnupg openssl && \
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
"

# =====================================================================
#  PHASE 3 — Install OpenClaw + initialize workspace
# =====================================================================
echo "[4/8] Installing OpenClaw platform..."
pct exec "$CTID" -- bash -lc "
  curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
"

echo "         Initializing workspace..."
pct exec "$CTID" -- bash -lc "
  openclaw onboard --non-interactive --accept-risk --mode local --skip-health 2>&1 || true
"

# =====================================================================
#  PHASE 4 — Configure gateway (AFTER onboard so we overwrite its config)
# =====================================================================
echo "[5/8] Configuring gateway + Caddy HTTPS proxy..."
pct exec "$CTID" -- bash -lc "
  CT_IP=\$($IPV4_CMD)
  GW_TOKEN=\$(openssl rand -hex 24)

  # ── Gateway config ──
  # - token auth for LAN binding
  # - dangerouslyDisableDeviceAuth so the first browser connects without pairing
  # - allowedOrigins so the HTTPS Control UI passes CORS
  mkdir -p /root/.openclaw
  cat > /root/.openclaw/openclaw.json <<OCCONF
{
  \"gateway\": {
    \"mode\": \"local\",
    \"bind\": \"lan\",
    \"auth\": {
      \"mode\": \"token\",
      \"token\": \"\${GW_TOKEN}\"
    },
    \"trustedProxies\": [\"127.0.0.1\"],
    \"controlUi\": {
      \"dangerouslyDisableDeviceAuth\": true,
      \"allowedOrigins\": [
        \"http://localhost:18789\",
        \"http://127.0.0.1:18789\",
        \"http://\${CT_IP}:18789\",
        \"https://\${CT_IP}\"
      ]
    }
  }
}
OCCONF

  # ── Gateway systemd service (system-level, LXC has no user-level systemd) ──
  OPENCLAW_BIN=\$(command -v openclaw)
  cat > /etc/systemd/system/openclaw-gateway.service <<GWSVC
[Unit]
Description=OpenClaw Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=\${OPENCLAW_BIN} gateway run --bind lan
Restart=on-failure
RestartSec=5
Environment=HOME=/root
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
GWSVC
  systemctl daemon-reload
  systemctl enable openclaw-gateway
  systemctl start openclaw-gateway
  sleep 3
  systemctl is-active openclaw-gateway && echo 'Gateway: running' || echo 'Gateway: FAILED'

  # ── Caddy HTTPS reverse proxy (Control UI requires secure context) ──
  curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
    | tee /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -q && DEBIAN_FRONTEND=noninteractive apt-get install -y caddy

  cat > /etc/caddy/Caddyfile <<CADDY
{
  local_certs
}

https://\${CT_IP}:443 {
  tls internal

  @connect path /connect
  redir @connect /#token=\${GW_TOKEN} 302

  reverse_proxy localhost:18789
}
CADDY
  systemctl restart caddy
  sleep 2
  systemctl is-active caddy && echo 'Caddy: running' || echo 'Caddy: FAILED'
"

# =====================================================================
#  PHASE 5 — Discord bot
# =====================================================================
echo "[6/8] Setting up Discord bot..."
pct exec "$CTID" -- bash -lc "
  cd /root
  [[ ! -d openclaw-assistant ]] && \
    git clone https://github.com/pbezant/OpenClaw-Personal-Assistant.git openclaw-assistant
  cd /root/openclaw-assistant
  python3 -m venv venv
  venv/bin/pip install -q --upgrade pip
  venv/bin/pip install -q -r requirements.txt
  [[ ! -f .env && -f .env.example ]] && cp .env.example .env

  if [[ -f discord_bot.service ]]; then
    sed -e 's|OPENCLAW_USER|root|g' \
        -e 's|/OPENCLAW_HOME/openclaw/workspace|/root/openclaw-assistant|g' \
        discord_bot.service > /etc/systemd/system/openclaw-bot.service
    systemctl daemon-reload
    systemctl enable openclaw-bot
  fi
  systemctl restart openclaw-bot || true
"

# =====================================================================
#  PHASE 6 — SSH
# =====================================================================
echo "[7/8] Enabling SSH..."
pct exec "$CTID" -- bash -lc "
  sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
"
pct exec "$CTID" -- systemctl restart ssh || pct exec "$CTID" -- systemctl restart sshd

if [[ -n "$SSH_PUBLIC_KEY_FILE" ]]; then
  [[ ! -f "$SSH_PUBLIC_KEY_FILE" ]] && { echo "SSH key file not found: $SSH_PUBLIC_KEY_FILE" >&2; exit 1; }
  PUBKEY="$(cat "$SSH_PUBLIC_KEY_FILE")"
  pct exec "$CTID" -- bash -lc "mkdir -p /root/.ssh && chmod 700 /root/.ssh"
  pct exec "$CTID" -- bash -lc "printf '%s\n' '$PUBKEY' >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"
fi

# =====================================================================
#  PHASE 7 — Summary
# =====================================================================
sleep 2
CT_IP="$(pct exec "$CTID" -- bash -lc "$IPV4_CMD" | tr -d '\r' || true)"
GW_TOKEN="$(pct exec "$CTID" -- bash -lc "python3 -c \"import json; print(json.load(open('/root/.openclaw/openclaw.json'))['gateway']['auth']['token'])\"" 2>/dev/null || true)"

echo
echo "[8/8] Done!"
echo
echo "============================================"
echo "  🦞 OpenClaw Debian LXC — Ready"
echo "============================================"
echo
echo "  Container IP:  $CT_IP"
echo "  SSH:           ssh root@$CT_IP"
echo "  Root password: $ROOT_PASSWORD"
echo
echo "  ── OpenClaw Control UI ──"
echo "  Dashboard:     https://$CT_IP/connect"
echo "                 (auto-authenticates with gateway token)"
echo
echo "  Or open manually:"
echo "    URL:   https://$CT_IP/#token=$GW_TOKEN"
echo
echo "  Accept the self-signed cert warning — you will land"
echo "  directly in the Control UI. No pairing required."
echo
echo "  ── Discord Bot ──"
echo "  Edit:  /root/openclaw-assistant/.env"
echo "    Set DISCORD_BOT_TOKEN + ANTHROPIC_API_KEY (or OPENAI_API_KEY)"
echo "  Then:  systemctl restart openclaw-bot"
echo
echo "  IMPORTANT: Change root password after first login."
echo "============================================"
