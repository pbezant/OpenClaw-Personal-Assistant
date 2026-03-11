# Operations

## Health checks

- `openclaw channels status --probe`
- `systemctl status openclaw-gateway --no-pager -l`
- `systemctl status openclaw-discord-healthcheck.timer --no-pager -l`

## Common recoveries

### Discord channel disconnected or stale

1. Restart gateway:
   - `systemctl restart openclaw-gateway`
2. Wait 10–20 seconds.
3. Re-check `openclaw channels status --probe`.

### Bot reacts but does not send final reply

1. Check mention-gating in server channels.
2. Clear stale Discord sessions from sessions index (if applicable).
3. Restart gateway and re-test DM + mention flows.

## Maintenance cadence

- Weekly: verify Discord DM and channel mention `ping`/`pong` path
- Monthly: verify watchdog timer is enabled and running
- After OpenClaw upgrades: re-verify pairing and channel health
