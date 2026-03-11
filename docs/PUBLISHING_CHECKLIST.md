# Publishing Checklist (Public Core)

Run this before publishing or tagging a release.

Companion guide: `docs/REDACTION_QUICK_CHECK.md`

## Security and privacy

- [ ] No real tokens, secrets, or pairing codes committed
- [ ] No personally sensitive content in public docs
- [ ] IPs/hostnames reviewed for intended disclosure
- [ ] `.env` is not committed; placeholders only

## Documentation quality

- [ ] `README.md` start path is accurate
- [ ] `docs/GETTING_STARTED.md` works end-to-end
- [ ] Troubleshooting sections include current known errors and fixes
- [ ] Script references match actual file names

## Operational reliability

- [ ] Discord DM and channel mention tests pass (`ping` → `pong`)
- [ ] `openclaw channels status --probe` shows healthy channel
- [ ] Watchdog install path still works

## Release hygiene

- [ ] Changelog notes updated
- [ ] Version/date updated where appropriate
- [ ] Public/private boundary file reviewed
