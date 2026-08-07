#!/bin/bash
# start-vpn-tor.sh
# Entry point for VPN -> Tor Browser container
# Sets up WireGuard, then runs base image's init (starts nginx, VNC, Tor Browser)

set -e

echo "[+] Starting VPN -> Tor Browser container..."

# Validate required env vars
: "${WIREGUARD_PRIVATE_KEY:?WIREGUARD_PRIVATE_KEY not set}"
: "${WIREGUARD_PEER_PUBLIC_KEY:?WIREGUARD_PEER_PUBLIC_KEY not set}"
: "${WIREGUARD_ENDPOINT:?WIREGUARD_ENDPOINT not set}"
# SERVER_PUBLIC_IP is now optional - auto-detected in policy routing script

# Generate WireGuard config from template
envsubst < /etc/wireguard/wg0.conf.template > /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

echo "[+] WireGuard config generated"

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Start WireGuard
echo "[+] Starting WireGuard..."
wg-quick up wg0

# Run policy routing (auto-detects public IP)
echo "[+] Setting up policy routing..."
/usr/local/bin/setup-vpn-policy-routing.sh

# Verify WireGuard is up
wg show
ip route show table 51820
ip rule show | grep -E '51820|fwmark'

# Start base image services (nginx on 5800, VNC, Tor Browser)
echo "[+] Starting base services (nginx, VNC, Tor Browser)..."
exec /init