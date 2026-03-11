#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root on the Proxmox host." >&2
  exit 1
fi

for cmd in pct pveam; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

CTID="${CTID:-246}"
HOSTNAME="${HOSTNAME:-openclaw}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
ROOTFS_STORAGE="${ROOTFS_STORAGE:-local-lvm}"
DISK_SIZE_GB="${DISK_SIZE_GB:-20}"
CORES="${CORES:-4}"
MEMORY_MB="${MEMORY_MB:-4096}"
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

echo "[1/9] Updating container template index..."
pveam update

echo "[2/9] Finding latest Ubuntu 24.04 template..."
TEMPLATE_NAME="$(pveam available --section system | awk '/ubuntu-24\.04-standard/ {print $2}' | tail -n1)"
if [[ -z "$TEMPLATE_NAME" ]]; then
  echo "Could not find ubuntu-24.04-standard template via pveam." >&2
  exit 1
fi

echo "[3/9] Downloading template ${TEMPLATE_NAME} to ${TEMPLATE_STORAGE}..."
pveam download "$TEMPLATE_STORAGE" "$TEMPLATE_NAME"

NET_ARG="name=eth0,bridge=${BRIDGE},ip=${IP_CONFIG}"
if [[ "$IP_CONFIG" != "dhcp" && -n "$GATEWAY" ]]; then
  NET_ARG="${NET_ARG},gw=${GATEWAY}"
fi

echo "[4/9] Creating container CTID ${CTID} (${HOSTNAME})..."
pct create "$CTID" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE_NAME}" \
  --hostname "$HOSTNAME" \
  --cores "$CORES" \
  --memory "$MEMORY_MB" \
  --swap "$SWAP_MB" \
  --rootfs "${ROOTFS_STORAGE}:${DISK_SIZE_GB}" \
  --net0 "$NET_ARG" \
  --unprivileged "$UNPRIVILEGED" \
  --onboot 1 \
  --password "$ROOT_PASSWORD"

echo "[5/9] Starting container..."
pct start "$CTID"

echo "[6/9] Installing SSH server and baseline packages..."
pct exec "$CTID" -- bash -lc "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server ca-certificates curl sudo"

echo "[7/9] Enabling SSH password login for first bootstrap..."
pct exec "$CTID" -- bash -lc "sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config"
pct exec "$CTID" -- bash -lc "sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config"
pct exec "$CTID" -- systemctl restart ssh || pct exec "$CTID" -- systemctl restart sshd

if [[ -n "$SSH_PUBLIC_KEY_FILE" ]]; then
  if [[ ! -f "$SSH_PUBLIC_KEY_FILE" ]]; then
    echo "SSH_PUBLIC_KEY_FILE does not exist: $SSH_PUBLIC_KEY_FILE" >&2
    exit 1
  fi
  echo "[8/9] Installing provided SSH public key for root..."
  PUBKEY="$(cat "$SSH_PUBLIC_KEY_FILE")"
  pct exec "$CTID" -- bash -lc "mkdir -p /root/.ssh && chmod 700 /root/.ssh"
  pct exec "$CTID" -- bash -lc "printf '%s\n' '$PUBKEY' >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"
else
  echo "[8/9] No SSH key file provided; password login will be used for first connection."
fi

sleep 2
CT_IP="$(pct exec "$CTID" -- bash -lc "hostname -I | awk '{print \$1}'" | tr -d '\r' || true)"

echo "[9/9] Done."
echo
if [[ -n "$CT_IP" ]]; then
  echo "Container IP: $CT_IP"
  echo "SSH connect: ssh root@$CT_IP"
else
  echo "Container IP could not be detected automatically."
  echo "Check with: pct exec $CTID -- hostname -I"
fi
echo "Root password set by script: ${ROOT_PASSWORD}"
echo "IMPORTANT: Change root password after first login."
echo "Next: install OpenClaw in this container, then continue docs/GETTING_STARTED.md"
