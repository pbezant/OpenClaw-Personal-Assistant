# Discord Setup for OpenClaw

## Prerequisites

- Discord server where you have admin permissions
- OpenClaw running and reachable

## 1) Create Discord app and bot

1. Open `https://discord.com/developers/applications`
2. Create a new application
3. In **Bot** tab, reset/copy token
4. Enable privileged intents:
   - Presence Intent
   - Server Members Intent
   - Message Content Intent

## 2) Invite bot to your server

Use OAuth2 Generated URL with bot scope and permissions for sending/reading messages and slash commands.

## 3) Configure OpenClaw channel

In this OpenClaw version, direct JSON editing may be required.

Update `/root/.openclaw/openclaw.json` with a Discord channel block and restart gateway.

## 4) Pair your Discord user

1. DM bot to receive pairing code
2. Approve on host:
   - `openclaw pairing approve discord <PAIRING_CODE>`

## 5) Validate

- DM `ping` → `pong`
- In server channel use mention: `@Bot ping` → `pong`

## Troubleshooting highlights

- `4014`: privileged intents missing
- `4004`: invalid bot token
- `This channel is not allowed`: check `groupPolicy`
- Bot reacts but no reply: clear stale Discord sessions and restart gateway
- No channel response without mention: mention-gating behavior in guild channels
