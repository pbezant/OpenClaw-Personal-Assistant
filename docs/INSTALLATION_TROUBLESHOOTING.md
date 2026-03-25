# OpenClaw Installation Troubleshooting

## Issue: DNS Resolution Failure in LXC Container

### Symptoms
```
Temporary failure resolving 'archive.ubuntu.com'
E: Failed to fetch http://archive.ubuntu.com/ubuntu/...
```

### Root Cause
When Proxmox creates an LXC container, DNS is not always properly configured inside the container. This prevents `apt-get update` from reaching Ubuntu package repositories.

### Solution

**If you encounter this error after running the one-paste installer:**

1. **SSH into the container** (use the IP address displayed by the installer):
   ```bash
   ssh root@<container-ip>
   # Default password: ChangeMeNow123! (unless you set a custom one)
   ```

2. **Add DNS servers** to `/etc/resolv.conf`:
   ```bash
   echo "nameserver 8.8.8.8" > /etc/resolv.conf
   echo "nameserver 1.1.1.1" >> /etc/resolv.conf
   cat /etc/resolv.conf
   ```

3. **Retry package installation**:
   ```bash
   apt-get update
   DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server ca-certificates curl sudo
   ```

4. **Verify DNS works**:
   ```bash
   nslookup archive.ubuntu.com
   ```

---

## Post-Installation: Configuring OpenClaw

Once the container is running with DNS fixed, the following steps have been automated:

### ✓ Already Done
- [x] Python 3.12+ installed
- [x] Python venv created at `/root/openclaw/workspace/venv`
- [x] Dependencies installed from `requirements.txt`
- [x] `.env` file created (from `.env.example`)
- [x] Systemd service `openclaw-bot` installed and enabled

### ⚠️ Manual Steps Required

#### 1. Add Your API Keys to `.env`

SSH into the container and edit `.env`:

```bash
ssh root@192.168.1.246
cd /root/openclaw/workspace
nano .env
```

Fill in the required values:

```bash
# Required: Your Discord bot token
DISCORD_BOT_TOKEN=your-actual-discord-bot-token-here

# Required: Choose ONE LLM backend
# Option A: Anthropic Claude (recommended)
ANTHROPIC_API_KEY=your-actual-anthropic-api-key-here

# Option B (alternative): OpenAI GPT-4o
# OPENAI_API_KEY=your-actual-openai-api-key-here
```

Save with `Ctrl+X`, then `Y`, then `Enter` (if using nano).

#### 2. Start the Discord Bot

```bash
sudo systemctl start openclaw-bot
sudo systemctl status openclaw-bot
```

#### 3. Monitor Logs in Real-Time

```bash
journalctl -u openclaw-bot -f
```

---

## Permanent DNS Fix (Optional)

If you want DNS to persist across container reboots, use Netplan:

### For DHCP (recommended):

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```

Replace with:
```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
        use-dns: false
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

Apply changes:
```bash
sudo netplan apply
```

### For Static IP:

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```

Replace with (adjust IP/gateway for your network):
```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 192.168.1.246/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

Apply:
```bash
sudo netplan apply
```

---

## Updating Installation Scripts

The one-paste installer script (`proxmox_openclaw_onepaste.sh`) would benefit from added DNS configuration. This can be improved in the `proxmox_create_openclaw_lxc.sh` script by adding:

```bash
# After starting the container, configure DNS
pct exec "$CTID" -- bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf && echo 'nameserver 1.1.1.1' >> /etc/resolv.conf"
```

This would be inserted after step [5/9] in the script to prevent the DNS errors in step [6/9].

---

## Quick Status Check

At any time, check the status of OpenClaw:

```bash
ssh root@192.168.1.246 "systemctl status openclaw-bot"
```

View recent errors:
```bash
ssh root@192.168.1.246 "journalctl -u openclaw-bot -n 50 --no-pager"
```

---

## Support

If you encounter other issues:
1. Check the logs: `journalctl -u openclaw-bot -f`
2. Verify `.env` has valid API keys
3. Ensure the container has network connectivity: `ping 8.8.8.8`
4. Check that Python venv is active: `/root/openclaw/workspace/venv/bin/python --version`
