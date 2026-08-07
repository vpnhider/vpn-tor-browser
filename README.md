# VPN → Tor Browser Docker Image

A hardened Tor Browser container with WireGuard VPN and policy routing. All traffic routes: **VPN → Tor Network**.

Accessible via noVNC on port 5800.

## Features

- 🛡️ **Hardened Tor Browser** (Safest level 4, from `domistyle/tor-browser:latest`)
- 🔐 **WireGuard VPN** with automatic config from environment variables
- 🔀 **Policy Routing** (fwmark 51820) - all browser traffic goes VPN → Tor
- 🌐 **Auto-detects public IP** for SSH bypass (no hardcoded IPs)
- 💾 **Persistent volumes** for browser profile/data
- 🚀 **~2 min startup** on Vast.ai (vs 10+ min KVM)
- 🔍 **Health checks** included

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/YOUR_USERNAME/vpn-tor-docker.git
cd vpn-tor-docker

# Copy template and fill in your VPN credentials
cp .env.template .env
# Edit .env with your WireGuard keys
```

### 2. Local Development

```bash
docker-compose up -d
# Access at http://localhost:5800
```

### 3. Deploy to Vast.ai

```bash
# Install vastai CLI
pip install vastai

# Set your API key
export VAST_API_KEY="your_key"

# Run deploy script (edit with your image name)
./deploy-vast.sh
```

## Required Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `WIREGUARD_PRIVATE_KEY` | Your WireGuard private key | ✅ Yes |
| `WIREGUARD_PEER_PUBLIC_KEY` | VPN server's public key | ✅ Yes |
| `WIREGUARD_ENDPOINT` | VPN server IP:port (e.g., `1.2.3.4:51820`) | ✅ Yes |
| `SERVER_PUBLIC_IP` | Override auto-detected IP | ❌ No (auto) |

## Architecture

```
Browser (noVNC:5800)
    │
    ▼
Tor Browser (Safest level)
    │
    ▼
Policy Routing (fwmark 51820)
    │
    ▼
WireGuard VPN (wg0)
    │
    ▼
Tor Network
```

## Vast.ai Deployment

The image is built for Vast.ai KVM instances with:
- `--cap-add=NET_ADMIN,SYS_MODULE,CAP_DAC_OVERRIDE`
- `--device=/dev/net/tun`
- GPU support (optional, for ML workloads)

## GitHub Actions

Automatic builds on push to main and tags:
- Registry: `ghcr.io/username/vpn-tor-docker`
- Tags: `latest`, `v1.0.0`, `sha-abc123`
- Multi-platform: `linux/amd64`

## Security Notes

- Never commit `.env` (in `.gitignore`)
- Use GitHub Secrets for CI/CD deployment
- WireGuard config generated at runtime via `envsubst`
- Runs as root (required for WireGuard/iptables)

## License

MIT