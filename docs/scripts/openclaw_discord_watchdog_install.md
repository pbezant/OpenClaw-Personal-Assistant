# Runbook: `openclaw_discord_watchdog_install.sh`

## Purpose

Install a lightweight Discord health watchdog that restarts OpenClaw gateway when channel health appears stale/unhealthy.

## Intended host

- OpenClaw host (run as root or with equivalent privileges)

## Prerequisites

- `systemd` available
- `openclaw` CLI available in PATH
- Gateway service exists (`openclaw-gateway`)

## What it installs

- `/usr/local/bin/openclaw-discord-healthcheck.sh`
- `/etc/systemd/system/openclaw-discord-healthcheck.service`
- `/etc/systemd/system/openclaw-discord-healthcheck.timer`

## Expected output

- Step progress `[1/4] ... [4/4]`
- systemd timer status snippet
- `openclaw channels status --probe` output
- final success line: `Done. Discord watchdog is installed.`

## Post-run verification

1. `systemctl status openclaw-discord-healthcheck.timer --no-pager -l`
2. `systemctl status openclaw-discord-healthcheck.service --no-pager -l`
3. `openclaw channels status --probe`

## Rollback

1. `systemctl disable --now openclaw-discord-healthcheck.timer`
2. Remove service/timer unit files
3. Remove `/usr/local/bin/openclaw-discord-healthcheck.sh`
4. `systemctl daemon-reload`

## Notes

- Health logic treats either connected state or recent inbound activity as healthy.
- On unhealthy state, script restarts `openclaw-gateway` and logs post-restart state.
