# Known-Good Versions Matrix

Use this matrix to reduce setup drift. If behavior differs, compare your versions first.

| Component | Known-good / target | Notes |
|---|---|---|
| Proxmox VE | 8.x (target family) | Subnet router host platform |
| Ubuntu LXC | 24.04 LTS | OpenClaw runtime container |
| OpenClaw | 2026.3.8 | Discord channel setup validated on this version |
| Discord extension | `@openclaw/discord 2026.3.8-beta.1` | Observed in environment during stabilization |
| Model (primary) | `google/gemini-2.5-flash` | Improved final-reply behavior in Discord flow |
| Tailscale | current stable | Required on Proxmox subnet-router host |

## Version verification checklist

- Confirm OpenClaw version from host runtime output/log header.
- Confirm Ubuntu release with `lsb_release -a`.
- Confirm Proxmox major version in host summary.
- Confirm Tailscale is installed and route approved.

## When to update this file

Update after any successful end-to-end validation on a newer stack.
