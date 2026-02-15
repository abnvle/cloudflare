#!/bin/bash
# =============================================================================
# @author: https://github.com/abnvle
# Cloudflare-only Firewall Script for Ubuntu Server
# Allows HTTP/HTTPS traffic only from Cloudflare IPs + SSH on a custom port
#
# Recommended: add to cron to keep Cloudflare IPs up to date
#   sudo crontab -e
#   0 3 * * 0 /path/to/cf-firewall.sh >> /var/log/cf-firewall.log 2>&1
# =============================================================================

set -euo pipefail

# ======================== CONFIGURATION ========================
SSH_PORT=22          # <-- Change to your SSH port
# ===============================================================

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] This script must be run as root: sudo $0"
    exit 1
fi

echo "[INFO] Configuring firewall..."
echo "       SSH port: $SSH_PORT"
echo ""

# Fetch current Cloudflare IP ranges
echo "[INFO] Fetching Cloudflare IP ranges..."
CF_IPV4=$(curl -sf https://www.cloudflare.com/ips-v4) || {
    echo "[ERROR] Failed to fetch Cloudflare IPv4 ranges"
    exit 1
}
CF_IPV6=$(curl -sf https://www.cloudflare.com/ips-v6) || {
    echo "[ERROR] Failed to fetch Cloudflare IPv6 ranges"
    exit 1
}

echo "       IPv4: $(echo "$CF_IPV4" | wc -l) ranges"
echo "       IPv6: $(echo "$CF_IPV6" | wc -l) ranges"
echo ""

# Flush existing rules
echo "[INFO] Flushing existing rules..."
iptables -F
iptables -X
ip6tables -F
ip6tables -X

# Default policy: drop everything
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
ip6tables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH - open to all on configured port
echo "[INFO] Opening SSH on port $SSH_PORT..."
iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT
ip6tables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT

# ICMP (ping) - useful for diagnostics
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
ip6tables -A INPUT -p ipv6-icmp -j ACCEPT

# HTTP/HTTPS from Cloudflare IPv4 only
echo "[INFO] Adding Cloudflare IPv4 rules..."
while IFS= read -r ip; do
    [[ -z "$ip" ]] && continue
    iptables -A INPUT -p tcp -s "$ip" --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp -s "$ip" --dport 443 -j ACCEPT
done <<< "$CF_IPV4"

# HTTP/HTTPS from Cloudflare IPv6 only
echo "[INFO] Adding Cloudflare IPv6 rules..."
while IFS= read -r ip; do
    [[ -z "$ip" ]] && continue
    ip6tables -A INPUT -p tcp -s "$ip" --dport 80 -j ACCEPT
    ip6tables -A INPUT -p tcp -s "$ip" --dport 443 -j ACCEPT
done <<< "$CF_IPV6"

# Log dropped packets (rate limited to avoid log flooding)
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "IPT-DROP: " --log-level 4
ip6tables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "IP6T-DROP: " --log-level 4

echo ""
echo "[OK] Firewall configured successfully."
echo ""
echo "IPv4 rules summary:"
iptables -L INPUT -n --line-numbers | head -30
echo ""

# Persist rules across reboots
if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save
    echo "[INFO] Rules saved via netfilter-persistent."
elif command -v iptables-save &>/dev/null; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
    echo "[INFO] Rules saved to /etc/iptables/rules.v{4,6}"
    echo "       Install iptables-persistent to load them on boot:"
    echo "       apt install iptables-persistent"
fi

echo ""
echo "[WARNING] Make sure SSH is running on port $SSH_PORT before disconnecting!"
echo "          To update Cloudflare IPs, re-run this script."
echo "          Dropped packet logs: journalctl -k | grep IPT-DROP"