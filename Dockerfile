# Dockerfile for VPN -> Tor Browser
# Combines hardened Tor Browser + WireGuard VPN with policy routing
# Accessible via noVNC on port 5800

FROM domistyle/tor-browser:latest

# Switch to root for system packages
USER root

# Install WireGuard and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard-tools \
    iproute2 \
    iptables \
    net-tools \
    curl \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Copy WireGuard config (template - will be populated at runtime)
COPY wg0.conf.template /etc/wireguard/wg0.conf.template

# Policy routing script
COPY setup-vpn-policy-routing.sh /usr/local/bin/setup-vpn-policy-routing.sh
RUN chmod +x /usr/local/bin/setup-vpn-policy-routing.sh

# Startup script
COPY start-vpn-tor.sh /usr/local/bin/start-vpn-tor.sh
RUN chmod +x /usr/local/bin/start-vpn-tor.sh

# Create wireguard directory
RUN mkdir -p /etc/wireguard

# Expose noVNC port
EXPOSE 5800

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5800/ || exit 1

# Run as root (needed for wireguard, iptables)
USER root

# Entry point
ENTRYPOINT ["/usr/local/bin/start-vpn-tor.sh"]