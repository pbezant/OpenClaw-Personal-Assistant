# Redaction Quick Check (Before Publishing)

Run this 5-minute pass before any public push.

## 1) Check for common sensitive patterns

Search the repository for:

- real IPs tied to private infra (unless intentionally documented)
- `ssh root@...` with personal host addresses
- tokens/keys/secrets (`token`, `api_key`, `secret`, `password`)
- personal names/paths where not needed

## 2) Confirm placeholder policy

Use placeholders in public docs/examples:

- `<openclaw-host-ip>`
- `<proxmox-host-ip>`
- `<lan-subnet-cidr>`
- `YOUR_BOT_TOKEN_HERE`

## 3) Verify safe script defaults

- Script defaults should be generic and reusable
- Environment-variable overrides should be documented

## 4) Review legacy docs

Legacy files can still leak personal details. Re-check:

- `docs/OPENCLAW_REMOTE_ACCESS_QUICKSTART.md`

## 5) Final confidence gate

If any sensitive value is found, replace it before publishing.
Only publish when the repository is safe by inspection and checklist.
