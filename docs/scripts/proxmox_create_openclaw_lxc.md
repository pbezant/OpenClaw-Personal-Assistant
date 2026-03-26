# Runbook: `proxmox_create_openclaw_lxc.sh`

## Purpose

Provision a fresh Ubuntu 24.04 LXC on Proxmox for OpenClaw and make first SSH access work out of the box.

## Intended host

- Proxmox host (run as `root`)

## What it does

1. Finds/downloads latest Ubuntu 24.04 LXC template
2. Creates a container with configurable CPU/RAM/disk/network
3. Starts container and installs SSH server + baseline packages
4. Enables root SSH login + password auth for first bootstrap
5. Optionally installs your SSH public key
6. Prints container IP and exact SSH command

## Prerequisites

- Proxmox host with `pct` and `pveam`
- Network bridge available (default: `vmbr0`)
- Storage configured (defaults: template `local`, rootfs `local-lvm`)

## Quick start

- Run: `scripts/proxmox_create_openclaw_lxc.sh`

Optional overrides (examples):

- `CTID=247 CT_HOSTNAME=openclaw-lab scripts/proxmox_create_openclaw_lxc.sh`
- `IP_CONFIG=192.168.1.180/24 GATEWAY=192.168.1.1 scripts/proxmox_create_openclaw_lxc.sh`
- `SSH_PUBLIC_KEY_FILE=~/.ssh/id_ed25519.pub scripts/proxmox_create_openclaw_lxc.sh`

## First SSH connect

After script completion:

1. Copy the printed IP address
2. Connect: `ssh root@<printed-container-ip>`
3. Use printed temporary root password (unless key auth was configured)
4. Immediately rotate password and/or disable root password auth after bootstrap

## Key inputs

- `CTID` auto-assigned (next available ID starting from 100); override with `CTID=xxx`
- `CT_HOSTNAME` default `OpenClaw`
- `IP_CONFIG` default `dhcp`
- `GATEWAY` optional for static IP mode
- `SSH_PUBLIC_KEY_FILE` optional path to public key

## Expected output

- Progress steps `[1/9]` through `[9/9]`
- Printed container IP (or command to fetch it)
- Printed SSH command

## Rollback

If creation should be undone:

1. Stop container: `pct stop <CTID>`
2. Destroy container: `pct destroy <CTID>`
3. Remove template manually if desired from template storage

## Security note

This script enables root SSH password login to simplify first-time setup. After bootstrap, harden SSH settings and prefer key-based auth.
