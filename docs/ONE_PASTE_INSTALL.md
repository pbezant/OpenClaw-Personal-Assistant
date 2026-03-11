# One-Paste Proxmox Installer

If you want the Community-Scripts style workflow, use this one-paste launcher in the **Proxmox host shell**.

## One-paste command

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/pbezant/OpenClaw-Personal-Assistant/main/scripts/proxmox_openclaw_onepaste.sh)"
```

## What it does

The launcher shows a small menu:

1. Create OpenClaw Ubuntu LXC
2. Configure Tailscale subnet router
3. Run both (recommended)

It then runs the corresponding script(s) directly from this repository.

## Safety checks

- Requires root user
- Requires Proxmox host (`pct` command present)
- Exits on invalid menu selection

## After running

- Continue with `docs/FROM_ZERO_CHECKLIST.md`
- Follow `docs/DISCORD_SETUP.md` for channel setup + pairing

## Security note

Always verify the URL before running remote scripts in shell.
