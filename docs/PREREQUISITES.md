# Prerequisites

## Infrastructure

- Proxmox host available
- Ubuntu 24.04 LXC container for OpenClaw (or create one using `scripts/proxmox_create_openclaw_lxc.sh`)
- Internet connectivity from container and Proxmox host

## Accounts

- Tailscale account with admin access to approve subnet routes
- Discord account
- Discord server where you can install bots

## Access

- SSH access to Proxmox host and OpenClaw LXC
- `root` or equivalent sudo privileges for systemd and networking changes

## Software assumptions

- OpenClaw installed on the Ubuntu LXC
- `systemctl` available and OpenClaw gateway managed as a service
- Bash shell available for script execution

## Validation before starting

- You can run `systemctl status openclaw-gateway` on the OpenClaw host
- You can run `tailscale status` on Proxmox host
- You can access the Discord Developer Portal
