# From-Zero Checklist (Proxmox → OpenClaw → Discord)

Use this as the fastest no-surprises path.

## A) Proxmox host prep

- [ ] Confirm you can SSH to Proxmox host as root
- [ ] Confirm `pct` and `pveam` are available on Proxmox
- [ ] Confirm storage/bridge values you want (`local`, `local-lvm`, `vmbr0` defaults are supported)

## B) Create Debian LXC for OpenClaw

- [ ] Run `scripts/proxmox_create_openclaw_lxc.sh` on Proxmox host
- [ ] Record printed container IP
- [ ] If IP not printed, run `pct exec <CTID> -- hostname -I`

## C) First SSH connection to container

- [ ] Connect with `ssh root@<container-ip>`
- [ ] Use printed temporary password (unless SSH key was provided)
- [ ] Change root password immediately after login
- [ ] (Recommended) add your SSH key and move toward key-only auth

## D) Verify OpenClaw platform in container

The LXC script installs OpenClaw automatically. Verify it:

- [ ] `openclaw --version`
- [ ] `openclaw doctor`
- [ ] `systemctl status openclaw-gateway --no-pager -l`

## E) Enable remote access networking

- [ ] Run `scripts/proxmox_tailscale_subnet_router.sh` on Proxmox host
- [ ] Approve advertised route in Tailscale admin
- [ ] Confirm client is connected to same tailnet

## F) Configure gateway token access

- [ ] Run `SHOW_TOKEN=1 scripts/openclaw_gateway_info.sh` on OpenClaw host
- [ ] Open `https://<openclaw-host-ip>/config`
- [ ] Paste gateway token into Control UI settings

## G) Configure Discord channel

- [ ] Create Discord app + bot token in Discord Dev Portal
- [ ] Enable privileged intents (Presence, Members, Message Content)
- [ ] Invite bot to your server
- [ ] Configure channel settings in OpenClaw config
- [ ] Restart gateway and verify `openclaw channels status --probe`

## H) Pair your Discord user

- [ ] DM bot to receive pairing code
- [ ] Approve pairing on host: `openclaw pairing approve discord <CODE>`

## I) Validate end-to-end

- [ ] DM `ping` → bot replies `pong`
- [ ] Channel mention `@Bot ping` → bot replies `pong`
- [ ] `openclaw channels status --probe` reports healthy/connected

## J) Reliability hardening

- [ ] Run `scripts/openclaw_discord_watchdog_install.sh`
- [ ] Confirm timer active: `systemctl status openclaw-discord-healthcheck.timer --no-pager -l`

## K) Publish-safe pass (if sharing)

- [ ] Run `docs/PUBLISHING_CHECKLIST.md`
- [ ] Run `docs/REDACTION_QUICK_CHECK.md`
