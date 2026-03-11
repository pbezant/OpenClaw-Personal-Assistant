# Runbook: `proxmox_tailscale_subnet_router.sh`

## Purpose

Configure a Proxmox host as a Tailscale subnet router for LAN reachability to OpenClaw.

## Intended host

- Proxmox host (run as `root`)

## Prerequisites

- Proxmox host has internet access
- You have root access
- Tailscale admin access to approve subnet routes

## What it changes

- Installs Tailscale (if missing)
- Enables IPv4/IPv6 forwarding via `/etc/sysctl.d/99-tailscale-forwarding.conf`
- Enables/starts `tailscaled`
- Runs `tailscale up --advertise-routes`

## Inputs (optional env vars)

- `TS_HOSTNAME` (default: `proxmox-host`)
- `TS_ROUTE` (default: `192.168.1.0/24`)
- `OPENCLAW_HOST` (default: `192.168.1.100`, used for printed next-step URL)

## Expected output

- "Bringing Tailscale up as ..."
- "Done. Next steps:" including route approval reminder
- `tailscale status` output with host visibility

## Post-run verification

1. Approve advertised route in Tailscale admin.
2. Confirm `tailscale status` is healthy.
3. From a Tailscale client, open `https://<openclaw-host>/config`.

## Rollback

If you need to revert quickly:

1. Disable route advertisement on host by re-running `tailscale up` without `--advertise-routes` (or disable in admin policy).
2. Remove `/etc/sysctl.d/99-tailscale-forwarding.conf` if forwarding should be fully disabled.
3. Reload sysctl values and verify forwarding is off.
