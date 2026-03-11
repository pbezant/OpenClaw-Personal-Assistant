# Runbook: `openclaw_gateway_info.sh`

## Purpose

Read OpenClaw gateway URL/auth mode/token from `openclaw.json` for onboarding clients.

## Intended host

- OpenClaw host (or any machine with access to the relevant config file)

## Prerequisites

- `python3` installed
- OpenClaw config file exists (default: `~/.openclaw/openclaw.json`)

## Inputs

- `OPENCLAW_CONFIG` to override config path
- `OPENCLAW_HOST` or first positional arg to override printed host
- `SHOW_TOKEN=1` to print full token

## Expected output

- Gateway URL
- Gateway auth mode
- Gateway token (masked by default; full when `SHOW_TOKEN=1`)
- Reminder about remote token mode

## Post-run verification

- Confirm URL matches intended host
- Confirm token presence (`<missing>` means it is not configured)

## Rollback

This script is read-only; no system rollback required.

## Security note

Avoid sharing full token output in public logs/screenshots.
