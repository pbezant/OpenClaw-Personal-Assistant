# Public Core vs Private Overlay Boundary

This project is intentionally split into:

- **Public core:** reusable setup, scripts, docs, templates.
- **Private overlay:** personal profile, private notes, personal workflow data, secrets.

## Safe to publish (public core)

- `docs/` setup and troubleshooting guides
- `scripts/` automation that does not contain secrets
- generic `AGENTS.md` / `ASSISTANT_SYSTEM.md` templates
- sample config files with placeholders only

## Must remain private (private overlay)

- `CV.md`, `USER.md`, personal job strategy details
- any token, key, pairing code, gateway auth material
- private hostnames/IPs tied to personal infrastructure unless intentionally disclosed
- local operational notes containing sensitive identifiers

## Redaction rules

Before publishing, replace:

- real tokens with `YOUR_TOKEN_HERE`
- sensitive IPs with placeholders such as `192.168.x.x`
- user-specific names where not required

## Recommended repo model

- Public repo: reusable starter kit and templates
- Private repo: personal data and custom overlays that consume/extend the public core
