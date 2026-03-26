#!/usr/bin/env bash
# mode=generated
# var_cpu="4"
# var_ram="4096"
# var_disk="32"
set -euo pipefail
#
# Creates a Debian 12 LXC on Proxmox with:
#   - OpenClaw platform + Control UI (HTTPS via Caddy)
#   - SSH enabled for root
#
# Usage:  CTID=300 bash proxmox_create_openclaw_lxc.sh
#         DRY_RUN=1 bash proxmox_create_openclaw_lxc.sh   ← preview only, no changes
#
# After install: SSH in, run `openclaw config`, then start the gateway service.

# ── Dry-run mode (DRY_RUN=1 to preview without making changes) ───────────
DRY_RUN="${DRY_RUN:-0}"
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

# ── Guard rails ──────────────────────────────────────────────────────────
if [[ "$DRY_RUN" != "1" ]] && [[ "${EUID}" -ne 0 ]]; then echo "Run as root on the Proxmox host." >&2; exit 1; fi
if [[ "$DRY_RUN" != "1" ]]; then
  for cmd in pct pveam; do command -v "$cmd" >/dev/null 2>&1 || { echo "Missing: $cmd" >&2; exit 1; }; done
else
  echo "[DRY-RUN] Skipping root/pct checks"
fi

# ── Auto-detect next available CTID (sequential from 100) ─────────────────
next_available_ctid() {
  local id=100
  while pct status "$id" >/dev/null 2>&1 || qm status "$id" >/dev/null 2>&1; do
    id=$((id + 1))
  done
  echo "$id"
}
if [[ -n "${CTID:-}" ]]; then
  : # user override
elif [[ "$DRY_RUN" == "1" ]]; then
  CTID="100"
else
  CTID="$(next_available_ctid)"
fi

# ── Configurable defaults (override via env) ─────────────────────────────
CT_HOSTNAME="${CT_HOSTNAME:-OpenClaw}"
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

if [[ "$DRY_RUN" == "1" ]]; then
  echo "=========================================="
  echo "  DRY-RUN MODE — no changes will be made"
  echo "  CTID=$CTID  HOSTNAME=$CT_HOSTNAME  CORES=$CORES"
  echo "  MEMORY=${MEMORY_MB}MB  DISK=${DISK_SIZE_GB}GB  BRIDGE=$BRIDGE"
  echo "  IP=$IP_CONFIG  STORAGE=$ROOTFS_STORAGE"
  echo "=========================================="
  echo
fi

if [[ "$DRY_RUN" != "1" ]] && pct status "$CTID" >/dev/null 2>&1; then
  echo "Container CTID $CTID already exists. Remove CTID override for auto-assignment, or pick a different CTID." >&2
  exit 1
fi

# Helper: extract IPv4 only (hostname -I returns IPv6 too and breaks configs)
IPV4_CMD='hostname -I | tr " " "\n" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$" | head -1'

# =====================================================================
#  PHASE 1 — Create & start the Debian 12 container
# =====================================================================
echo "[1/6] Downloading Debian 12 template..."
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] pveam update"
  echo "[DRY-RUN] pveam available --section system | awk '/debian-12-standard/ {print \$2}'"
  TEMPLATE_NAME="debian-12-standard_12.x-x_amd64.tar.zst"
  echo "[DRY-RUN] pveam download $TEMPLATE_STORAGE $TEMPLATE_NAME"
else
  pveam update
  TEMPLATE_NAME="$(pveam available --section system | awk '/debian-12-standard/ {print $2}' | tail -n1)"
  [[ -z "$TEMPLATE_NAME" ]] && { echo "Could not find debian-12-standard template." >&2; exit 1; }
  pveam download "$TEMPLATE_STORAGE" "$TEMPLATE_NAME"
fi

NET_ARG="name=eth0,bridge=${BRIDGE},ip=${IP_CONFIG}"
[[ "$IP_CONFIG" != "dhcp" && -n "$GATEWAY" ]] && NET_ARG="${NET_ARG},gw=${GATEWAY}"

echo "[2/6] Creating container CTID ${CTID}..."
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] pct create $CTID ${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE_NAME} \\"
  echo "          --hostname $CT_HOSTNAME --cores $CORES --memory $MEMORY_MB --swap $SWAP_MB \\"
  echo "          --rootfs ${ROOTFS_STORAGE}:${DISK_SIZE_GB} --net0 $NET_ARG \\"
  echo "          --unprivileged $UNPRIVILEGED --onboot 1 --password ***"
  echo "[DRY-RUN] pct start $CTID"
  echo "[DRY-RUN] Set DNS: nameserver 8.8.8.8, 1.1.1.1"
else
  pct create "$CTID" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE_NAME}" \
    --hostname "$CT_HOSTNAME" --cores "$CORES" --memory "$MEMORY_MB" --swap "$SWAP_MB" \
    --rootfs "${ROOTFS_STORAGE}:${DISK_SIZE_GB}" --net0 "$NET_ARG" \
    --unprivileged "$UNPRIVILEGED" --onboot 1 --password "$ROOT_PASSWORD"
  pct start "$CTID"
  sleep 3
  # Persistent DNS (Debian uses resolv.conf, not Netplan)
  pct exec "$CTID" -- bash -c "
printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf
chattr +i /etc/resolv.conf 2>/dev/null || true"
  sleep 2
fi

# =====================================================================
#  PHASE 2 — Install all packages
# =====================================================================
echo "[3/6] Installing system packages + Node.js 22..."
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] apt-get install openssh-server ca-certificates curl sudo git gnupg openssl nodejs"
else
  pct exec "$CTID" -- bash -lc "
  apt-get update -q && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-server ca-certificates curl sudo git gnupg openssl && \
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
"
fi

# =====================================================================
#  PHASE 3 — Install OpenClaw + initialize workspace
# =====================================================================
echo "[4/6] Installing OpenClaw platform..."
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] curl https://openclaw.ai/install.sh | bash -s -- --no-onboard"
  echo "[DRY-RUN] openclaw onboard --non-interactive --accept-risk --mode local --skip-health"
else
  pct exec "$CTID" -- bash -lc "
  curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
"
  echo "         Initializing workspace..."
  pct exec "$CTID" -- bash -lc "
  openclaw onboard --non-interactive --accept-risk --mode local --skip-health 2>&1 || true
"
fi

# =====================================================================
#  PHASE 4 — Gateway service + Caddy HTTPS reverse proxy
# =====================================================================
echo "[5/6] Configuring Caddy HTTPS proxy + gateway service..."
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] Install caddy, write /etc/caddy/Caddyfile (HTTPS -> localhost:18789)"
  echo "[DRY-RUN] Write /etc/systemd/system/openclaw-gateway.service"
  echo "[DRY-RUN] systemctl enable openclaw-gateway (not started until user runs openclaw config)"
else
pct exec "$CTID" -- bash -lc "
  CT_IP=\$($IPV4_CMD)

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
  echo 'Gateway: installed and enabled (not started — run openclaw config first)'

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
  reverse_proxy localhost:18789
}
CADDY
  systemctl restart caddy
  sleep 2
  systemctl is-active caddy && echo 'Caddy: running' || echo 'Caddy: FAILED'
"
fi  # end DRY_RUN gate for phase 4

# =====================================================================
#  PHASE 5 — SSH
# =====================================================================
echo "[6/6] Enabling SSH..."
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] sshd_config: PermitRootLogin yes, PasswordAuthentication yes"
  echo "[DRY-RUN] systemctl restart ssh"
  [[ -n "$SSH_PUBLIC_KEY_FILE" ]] && echo "[DRY-RUN] Install SSH key from $SSH_PUBLIC_KEY_FILE"
  CT_IP="<container-ip>"
else
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
fi

# =====================================================================
#  PHASE 6 — Summary
# =====================================================================
if [[ "$DRY_RUN" != "1" ]]; then
  sleep 2
  CT_IP="$(pct exec "$CTID" -- bash -lc "$IPV4_CMD" | tr -d '\r' || true)"
fi

echo
echo "============================================"
echo "  OpenClaw Debian LXC — Ready"
echo "============================================"
echo
echo "  Container IP:  $CT_IP"
echo "  SSH:           ssh root@$CT_IP"
echo "  Root password: $ROOT_PASSWORD"
echo
echo "  ── Next Steps ──"
echo "  1. ssh root@$CT_IP"
echo "  2. Change root password immediately"
echo "  3. Run: openclaw config   ← configure API keys etc."
echo "  4. Run: systemctl start openclaw-gateway"
echo "  5. Open https://$CT_IP  (accept self-signed cert)"
echo ""
echo "  Then tell OpenClaw: 'review BOOTSTRAP.md'"
echo "============================================"
