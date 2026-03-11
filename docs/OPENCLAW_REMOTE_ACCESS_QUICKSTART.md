# OpenClaw Remote Access Quickstart

This is the fastest repeatable setup for a new user to reach OpenClaw remotely using Tailscale.

> Legacy all-in-one runbook: preferred entrypoint is now modular docs.
>
> Start with:
> - `docs/GETTING_STARTED.md`
> - `docs/NETWORK_REMOTE_ACCESS.md`
> - `docs/DISCORD_SETUP.md`
> - `docs/OPERATIONS.md`

## Recommended architecture

- **OpenClaw app host:** `<openclaw-host-ip>`
- **OpenClaw UI URL:** `https://<openclaw-host-ip>/config`
- **Tailscale subnet router:** Proxmox host `<proxmox-host-ip>`
- **Advertised route:** `192.168.1.0/24`

If the OpenClaw host IP changes later, update the two values above and optionally set `OPENCLAW_HOST=<new-ip>` when running the helper scripts.

This keeps OpenClaw where it is and uses Proxmox as the secure Tailscale gateway.

## One-time admin setup

Run on the Proxmox host as `root`:

- `scripts/proxmox_tailscale_subnet_router.sh`

Then in Tailscale admin:

1. Open **Machines**
2. Select `proxmox-host`
3. Approve subnet route `192.168.1.0/24`

## New user setup (2 minutes)

### 1) Join Tailscale
- Install the Tailscale app on the phone or laptop
- Sign into the same tailnet
- Confirm Tailscale shows **Connected**

### 2) Open OpenClaw
In a browser, open:

- the **OpenClaw UI URL** listed above

### 3) Enter the gateway token
In OpenClaw **Control UI settings**:

- Paste the **Gateway Token**
- Leave **Remote Gateway Token** empty unless you intentionally run split-host remote mode

To retrieve the token on the OpenClaw host:

- `SHOW_TOKEN=1 scripts/openclaw_gateway_info.sh`

If you need to override the default host for the printed URL:

- `SHOW_TOKEN=1 OPENCLAW_HOST=<openclaw-host-ip> scripts/openclaw_gateway_info.sh`

## Troubleshooting

### Can't reach the OpenClaw host
- Confirm the phone is connected to Tailscale
- Confirm `proxmox-host` is online in Tailscale admin
- Confirm subnet route `192.168.1.0/24` is approved

### OpenClaw loads but says `gateway token missing`
- Paste the **Gateway Token** in Control UI settings
- Refresh the page

### Says `too many failed authentication attempts`
- Wait a minute or restart the gateway service on the OpenClaw host:
  - `systemctl restart openclaw-gateway.service`
- Retry in a private/incognito tab

## Security notes

- Treat the gateway token like a password
- Prefer sharing it out-of-band or rotating it after onboarding a new user
- If the token is exposed, rotate it and update clients

---

## Discord bot setup

### Prerequisites
- Discord account and a server you own/admin
- OpenClaw running at `https://<openclaw-host-ip>/config`

### 1) Create the Discord app & bot
1. Go to [discord.com/developers/applications](https://discord.com/developers/applications)
2. Click **New Application**, give it a name (e.g. "OpenClawed")
3. Go to **Bot** tab → click **Reset Token** → copy the token
4. Under **Privileged Gateway Intents**, enable all three:
   - **Presence Intent**
   - **Server Members Intent**
   - **Message Content Intent**
5. Click **Save Changes**

### 2) Invite the bot to your server
In the **OAuth2** tab, use the **Generated URL** at the bottom of the page (scope=bot, with Send Messages / Read Message History / Use Slash Commands permissions) — paste it in a browser and authorize it to your server.

### 3) Write the bot token into OpenClaw config
SSH into the server and write the token directly into `openclaw.json` (the CLI `channels add` command has a bug in this version):

```bash
ssh root@<openclaw-host-ip>

python3 - <<'EOF'
import json, shutil, time
path = "/root/.openclaw/openclaw.json"
with open(path) as f:
    cfg = json.load(f)
shutil.copy(path, path + ".bak." + str(int(time.time())))
cfg["channels"] = {
    "discord": {
        "token": "YOUR_BOT_TOKEN_HERE",
        "groupPolicy": "open"
    }
}
# This model has been stable for Discord final replies in this environment.
cfg.setdefault("agents", {}).setdefault("defaults", {}).setdefault("model", {})["primary"] = "google/gemini-2.5-flash"
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
print("Done:", cfg["channels"])
EOF
```

### 4) Restart the gateway
```bash
systemctl restart openclaw-gateway && sleep 8 && openclaw channels status --probe
```

Expected output: `connected, works`

### 5) Pair your Discord user
DM the bot from Discord. It will respond with a pairing code like:

> `Pairing code: XXXXXXXX — Ask the bot owner to approve with: openclaw pairing approve discord XXXXXXXX`

Run on the server:
```bash
openclaw pairing approve discord XXXXXXXX
```

You're done — message the bot in any server channel or via DM.

### 6) (Recommended) enable Discord auto-recovery watchdog
This adds a lightweight timer that checks Discord health every 10 minutes and restarts the gateway if the channel is unhealthy.

```bash
cat >/usr/local/bin/openclaw-discord-healthcheck.sh <<'EOF'
set -euo pipefail
STATUS="$(openclaw channels status --probe 2>&1 || true)"
LINE="$(printf "%s\n" "$STATUS" | grep -E "Discord default:" | tail -n1 || true)"
if printf "%s" "$LINE" | grep -Eq "running, connected,"; then
    logger -t openclaw-discord-healthcheck "healthy(connected)"
    exit 0
fi
if printf "%s" "$LINE" | grep -Eq "in:(just now|[0-4]m ago)"; then
    logger -t openclaw-discord-healthcheck "healthy(recent-inbound)"
    exit 0
fi
logger -t openclaw-discord-healthcheck "unhealthy -> restarting gateway"
systemctl restart openclaw-gateway
sleep 8
POST="$(openclaw channels status --probe 2>&1 || true)"
POSTLINE="$(printf "%s\n" "$POST" | grep -E "Discord default:" | tail -n1 || true)"
logger -t openclaw-discord-healthcheck "post-restart state: ${POSTLINE:-unknown}"
exit 0
EOF

chmod +x /usr/local/bin/openclaw-discord-healthcheck.sh

cat >/etc/systemd/system/openclaw-discord-healthcheck.service <<'EOF'
[Unit]
Description=OpenClaw Discord channel health check
After=network-online.target openclaw-gateway.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/bin/openclaw-discord-healthcheck.sh
User=root
EOF

cat >/etc/systemd/system/openclaw-discord-healthcheck.timer <<'EOF'
[Unit]
Description=Run OpenClaw Discord channel health check every 10 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=10min
AccuracySec=30s
Unit=openclaw-discord-healthcheck.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now openclaw-discord-healthcheck.timer
systemctl start openclaw-discord-healthcheck.service
systemctl status openclaw-discord-healthcheck.timer --no-pager -l
```

### Troubleshooting

| Symptom | Fix |
|---|---|
| No reply in `#general` | Mention-gated behavior is active. Use `@OpenClawed <message>` in guild channels. |
| DM or channel shows 👀 but no text reply | Clear stale Discord sessions and restart: remove `agent:main:discord:*` entries from `/root/.openclaw/agents/main/sessions/sessions.json`, then `systemctl restart openclaw-gateway`. |
| `This channel is not allowed` | Set `groupPolicy: "open"` in `openclaw.json` → restart gateway |
| `gateway closed with code 4014` | Enable all 3 Privileged Gateway Intents in Discord Dev Portal → restart gateway |
| `disconnected` after restart | Wait 15s then run `openclaw channels status --probe` — it needs a moment to reconnect |
| `OpenClaw: access not configured` | Bot is working but your Discord user isn't paired yet — DM it to get a pairing code, then run `openclaw pairing approve` |

### Post-setup verification checklist
1. `openclaw channels status --probe` shows Discord `configured` and `works`
2. DM bot: `ping` → expected reply: `pong`
3. In `#general`: `@OpenClawed ping` → expected reply: `pong`
4. Confirm watchdog timer is active: `systemctl status openclaw-discord-healthcheck.timer`

---

## Optional next improvement

If you want onboarding to be even smoother later:
- expose OpenClaw with a stable private DNS name or Tailscale Serve
- add a small internal onboarding page with the token prefilled for trusted users
