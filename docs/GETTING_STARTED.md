# Getting Started (Manual Docs-First)

This is the canonical setup path for v1.

Before starting, confirm your stack against `docs/VERSIONS.md`.
Use `docs/FROM_ZERO_CHECKLIST.md` to track progress as you go.

Want Community-Scripts style setup? Use the one-paste launcher in `docs/ONE_PASTE_INSTALL.md`.

## 1) Provision Ubuntu LXC on Proxmox (if you don't already have one)

On the Proxmox host, run:

- `scripts/proxmox_create_openclaw_lxc.sh`

Reference: `docs/scripts/proxmox_create_openclaw_lxc.md`

The script prints the container IP and SSH command. If it cannot auto-detect IP, run:

- `pct exec <CTID> -- hostname -I`

Then connect:

- `ssh root@<container-ip>`

## 2) Configure Proxmox as Tailscale subnet router

On the Proxmox host, run:

- `scripts/proxmox_tailscale_subnet_router.sh`

References: `docs/NETWORK_REMOTE_ACCESS.md`, `docs/scripts/proxmox_tailscale_subnet_router.md`

Then approve the advertised subnet route in Tailscale admin.

## 3) Verify OpenClaw host reachability

From a Tailscale-connected client, open your OpenClaw config page.

Current known example endpoint pattern:

- `https://<openclaw-host>/config`

## 4) Configure OpenClaw gateway access

On the OpenClaw host, retrieve gateway information:

- `SHOW_TOKEN=1 scripts/openclaw_gateway_info.sh`

Reference: `docs/scripts/openclaw_gateway_info.md`

Paste the gateway token in OpenClaw Control UI settings.

## 5) Configure Discord channel

Follow:

- `docs/DISCORD_SETUP.md`

## 6) Validate end-to-end

- DM bot: `ping` → expect `pong`
- Server channel: `@Bot ping` → expect `pong`
- Run `openclaw channels status --probe` and confirm Discord reports healthy.

## 7) Install recovery watchdog

Run:

- `scripts/openclaw_discord_watchdog_install.sh`

Reference: `docs/scripts/openclaw_discord_watchdog_install.md`

Then confirm timer health via systemd status output.
