# OpenClaw Proxmox + Discord Starter (Docs-First)

A shareable, docs-first starter kit for running OpenClaw on **Proxmox + Ubuntu LXC + systemd**, with Discord chat access and operational recovery guidance.

## Who this is for

Use this if you want a practical, manual setup flow from infrastructure to first Discord `pong`, without hidden automation.

## Start here

1. Read `docs/PUBLIC_PRIVATE_BOUNDARY.md`
2. Read `docs/PREREQUISITES.md`
3. Check off `docs/FROM_ZERO_CHECKLIST.md`
4. Follow `docs/GETTING_STARTED.md`
5. Use modular setup guides:
	- `docs/NETWORK_REMOTE_ACCESS.md`
	- `docs/DISCORD_SETUP.md`
6. Use `docs/OPERATIONS.md` for day-2 support
7. Review versions: `docs/VERSIONS.md`
8. Use script references: `docs/SCRIPT_RUNBOOKS.md`
9. Run `docs/PUBLISHING_CHECKLIST.md` before sharing
10. Run `docs/REDACTION_QUICK_CHECK.md` for final privacy pass

## Current setup assets

- `docs/OPENCLAW_REMOTE_ACCESS_QUICKSTART.md` (legacy all-in-one runbook; being decomposed)
- `scripts/proxmox_create_openclaw_lxc.sh`
- `scripts/proxmox_tailscale_subnet_router.sh`
- `scripts/openclaw_gateway_info.sh`
- `scripts/openclaw_discord_watchdog_install.sh`

## Project status

This repository is being productized into a public-core + private-overlay model.
The modular docs path is in progress; the legacy quickstart remains valid during transition.
