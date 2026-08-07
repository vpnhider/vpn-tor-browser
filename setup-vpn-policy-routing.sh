#!/bin/bash
# setup-vpn-policy-routing.sh
# Policy routing for VPN -> Tor
# Runs after wg-quick up wg0 inside container
# Auto-detects public IP for SSH bypass

set -e

WG_INTERFACE="wg0"
WG_FWMARK=51820
WG_TABLE=51820
WG_SUBNET="10.2.0.2/32"
VPN_ENDPOINT="${WIREGUARD_ENDPOINT%%:*}"

# Auto-detect public IP (try multiple sources)
echo "[+] Detecting public IP..."
SERVER_IP=""
for src in "http://checkip.amazonaws.com" "http://ifconfig.me" "http://ipinfo.io/ip" "http://icanhazip.com"; do
    SERVER_IP=$(curl -s --max-time 5 "$src" 2>/dev/null | tr -d '[:space:]')
    if [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "[+] Detected public IP: $SERVER_IP (from $src)"
        break
    fi
done

if [ -z "$SERVER_IP" ]; then
    echo "[!] Could not auto-detect public IP, trying metadata service..."
    SERVER_IP=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)
fi

if [ -z "$SERVER_IP" ]; then
    echo "[!] WARNING: Could not detect public IP, SSH bypass may not work"
    SERVER_IP="0.0.0.0"
fi

echo "[+] Setting up policy routing for VPN -> Tor..."

# Wait for WireGuard interface to be ready
for i in {1..30}; do
    if ip link show wg0 &>/dev/null; then
        break
    fi
    sleep 1
done

# Clean any existing rules
ip rule del table 51820 priority 100 2>/dev/null || true
ip rule del fwmark 51820 table 51820 priority 100 2>/dev/null || true
ip rule del from 10.2.0.2 table main priority 200 2>/dev/null || true
ip rule del to "${VPN_ENDPOINT}" table main priority 200 2>/dev/null || true
[ "$SERVER_IP" != "0.0.0.0" ] && ip rule del to "${SERVER_IP}" table main priority 200 2>/dev/null || true

# Create routing table
ip route add 0.0.0.0/0 dev wg0 table 51820 2>/dev/null || true

# Add rules for policy routing
ip rule add table 51820 priority 100 2>/dev/null || true
ip rule add fwmark 51820 table 51820 priority 100 2>/dev/null || true

# Allow WireGuard endpoint and local traffic to bypass VPN
ip rule add from 10.2.0.2 table main priority 200 2>/dev/null || true
ip rule add to "${VPN_ENDPOINT}" table main priority 200 2>/dev/null || true
[ "$SERVER_IP" != "0.0.0.0" ] && ip rule add to "${SERVER_IP}" table main priority 200 2>/dev/null || true

# NAT for VPN traffic
iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE 2>/dev/null || true

echo "[+] Policy routing configured for VPN -> Tor"
echo "[+] Server IP for SSH bypass: $SERVER_IP"
wg show
ip route show table 51820
ip rule show | grep -E '51820|fwmark'