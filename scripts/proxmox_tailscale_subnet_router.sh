#!/usr/bin/env bash
set -euo pipefail

TS_HOSTNAME="${TS_HOSTNAME:-proxmox-host}"
TS_ROUTE="${TS_ROUTE:-192.168.1.0/24}"
OPENCLAW_HOST="${OPENCLAW_HOST:-192.168.1.100}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

cat >/etc/sysctl.d/99-tailscale-forwarding.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl --system >/dev/null

systemctl enable --now tailscaled

echo
echo "Bringing Tailscale up as ${TS_HOSTNAME} and advertising ${TS_ROUTE}..."
tailscale up --ssh --hostname "${TS_HOSTNAME}" --advertise-routes "${TS_ROUTE}"

echo
echo "Done. Next steps:"
echo "1. In Tailscale admin, approve subnet route: ${TS_ROUTE}"
echo "2. On user devices, connect to the same tailnet"
echo "3. Open the OpenClaw URL, e.g. https://${OPENCLAW_HOST}/config"
echo
echo "Current status:"
tailscale status
