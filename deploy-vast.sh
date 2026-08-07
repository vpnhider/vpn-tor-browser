#!/bin/bash
# deploy-vast.sh
# Deploy VPN -> Tor Browser to Vast.ai

set -e

# Load environment
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found. Copy .env.template to .env and fill in values."
    exit 1
fi

# Vast.ai API key
export VAST_API_KEY="${VAST_API_KEY}"

# Search for GPU offers under budget
echo "[+] Searching for GPU offers under £0.10/hr..."
OFFER=$(vastai search offers 'vms_enabled=true rented=False reliability>0.9' --raw | python3 -c "
import json, sys
data = json.load(sys.stdin)
for o in data:
    cost = o.get('dph_total', 0)
    if cost < 0.12:  # ~£0.10 at 0.78 rate
        print(o['id'])
        break
")

if [ -z "$OFFER" ]; then
    echo "No suitable offers found"
    exit 1
fi

echo "[+] Using offer: $OFFER"

# Build image locally and push to registry (or use GHCR)
# For now, build on Vast.ai directly using docker.io as registry
# You'll need to push to a registry first

# Create instance with our image
echo "[+] Creating Vast.ai instance..."
INSTANCE=$(vastai create instance "$OFFER" \
    --image docker.io/your-username/vpn-tor-browser:latest \
    --disk 20 \
    --env WIREGUARD_PRIVATE_KEY="$WIREGUARD_PRIVATE_KEY" \
    --env WIREGUARD_PEER_PUBLIC_KEY="$WIREGUARD_PEER_PUBLIC_KEY" \
    --env WIREGUARD_ENDPOINT="$WIREGUARD_ENDPOINT" \
    --raw | python3 -c "import json, sys; print(json.load(sys.stdin)['new_contract'])")

echo "[+] Instance created: $INSTANCE"
echo "[+] Waiting for instance to be ready..."

# Wait for instance
for i in {1..60}; do
    STATUS=$(vastai show instance "$INSTANCE" --raw | python3 -c "import json, sys; print(json.load(sys.stdin).get('actual_status', '?'))")
    if [ "$STATUS" = "running" ]; then
        break
    fi
    sleep 10
done

# Get connection info
vastai show instance "$INSTANCE" --raw | python3 -c "
import json, sys
data = json.load(sys.stdin)
print('SSH:', 'ssh -p', data.get('ports', {}).get('22/tcp', [{}])[0].get('HostPort'), 'root@', data.get('public_ipaddr'))
print('noVNC: http://', data.get('public_ipaddr'), ':', data.get('ports', {}).get('5800/tcp', [{}])[0].get('HostPort'))
"