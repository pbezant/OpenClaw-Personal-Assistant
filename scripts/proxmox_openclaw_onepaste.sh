#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root on a Proxmox host." >&2
  exit 1
fi

if ! command -v pct >/dev/null 2>&1; then
  echo "This does not look like a Proxmox VE host (missing pct)." >&2
  exit 1
fi

REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/pbezant/OpenClaw-Personal-Assistant/main}"

run_remote_script() {
  local script_path="$1"
  echo "\n==> Running ${script_path}"
  bash -c "$(curl -fsSL "${REPO_RAW_BASE}/${script_path}")"
}

cat <<'MENU'
OpenClaw Proxmox One-Paste Installer
------------------------------------
1) Create OpenClaw Ubuntu LXC
2) Configure Tailscale subnet router on Proxmox
3) Run both (recommended)
4) Exit
MENU

read -r -p "Choose an option [1-4]: " choice

case "${choice}" in
  1)
    run_remote_script "scripts/proxmox_create_openclaw_lxc.sh"
    ;;
  2)
    run_remote_script "scripts/proxmox_tailscale_subnet_router.sh"
    ;;
  3)
    run_remote_script "scripts/proxmox_create_openclaw_lxc.sh"
    run_remote_script "scripts/proxmox_tailscale_subnet_router.sh"
    ;;
  4)
    echo "Exiting."
    exit 0
    ;;
  *)
    echo "Invalid option: ${choice}" >&2
    exit 1
    ;;
esac

echo
cat <<'NEXT'
Next steps:
- SSH into your OpenClaw container (use the IP printed by the LXC script)
- Continue with docs/FROM_ZERO_CHECKLIST.md
- Configure Discord via docs/DISCORD_SETUP.md
NEXT
