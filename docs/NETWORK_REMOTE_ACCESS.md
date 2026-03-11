# Network Remote Access (Proxmox + Tailscale)

This guide configures Proxmox as a Tailscale subnet router so clients can reach the OpenClaw host.

## Recommended architecture

- OpenClaw app host: `<openclaw-host-ip>`
- OpenClaw UI URL: `https://<openclaw-host-ip>/config`
- Tailscale subnet router: Proxmox host `<proxmox-host-ip>`
- Advertised route: `<lan-subnet-cidr>` (example: `192.168.1.0/24`)

## One-time admin setup

Run on the Proxmox host as `root`:

- `scripts/proxmox_tailscale_subnet_router.sh`

Then in Tailscale admin:

1. Open **Machines**
2. Select your Proxmox host
3. Approve subnet route `192.168.1.0/24`

## New user setup

1. Install and connect Tailscale on the client device.
2. Open OpenClaw UI: `https://<openclaw-host>/config`
3. Enter gateway token in OpenClaw Control UI settings.

To retrieve token on host:

- `SHOW_TOKEN=1 scripts/openclaw_gateway_info.sh`

## Troubleshooting

### Cannot reach OpenClaw host

- Confirm Tailscale client is connected
- Confirm Proxmox host is online in tailnet
- Confirm subnet route is approved

### `gateway token missing`

- Paste gateway token in Control UI settings
- Refresh and retry

### `too many failed authentication attempts`

- Wait 60 seconds or restart gateway:
  - `systemctl restart openclaw-gateway.service`
