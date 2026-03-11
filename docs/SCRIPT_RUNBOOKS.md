# Script Runbooks

This page indexes the operational scripts with execution guidance.

If you're starting from scratch, use `docs/FROM_ZERO_CHECKLIST.md` first.

## Scripts

- `scripts/proxmox_create_openclaw_lxc.sh` → `docs/scripts/proxmox_create_openclaw_lxc.md`
- `scripts/proxmox_tailscale_subnet_router.sh` → `docs/scripts/proxmox_tailscale_subnet_router.md`
- `scripts/openclaw_gateway_info.sh` → `docs/scripts/openclaw_gateway_info.md`
- `scripts/openclaw_discord_watchdog_install.sh` → `docs/scripts/openclaw_discord_watchdog_install.md`

## Safety notes

- Run scripts only on their intended host (Proxmox or OpenClaw host).
- Prefer running in a maintenance window when modifying networking or systemd services.
- Validate with the checks listed in each runbook after execution.
