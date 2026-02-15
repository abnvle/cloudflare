# Cloudflare Scripts

A collection of practical scripts for managing servers behind Cloudflare.

## Scripts

### `cf-firewall.sh`

Configures iptables to accept HTTP/HTTPS traffic exclusively from [Cloudflare IP ranges](https://www.cloudflare.com/ips/), ensuring that all web traffic passes through Cloudflare's proxy. SSH access is kept open on a configurable port.

**What it does:**

- Fetches current Cloudflare IPv4 and IPv6 ranges directly from their API
- Allows ports 80/443 only from Cloudflare IPs
- Opens SSH on a user-defined port (default: 22)
- Allows ICMP (ping) for diagnostics
- Drops and logs all other incoming traffic
- Persists rules across reboots via `netfilter-persistent`

**Usage:**

```bash
# Edit SSH_PORT inside the script first
chmod +x cf-firewall.sh
sudo ./cf-firewall.sh
```

**Keeping Cloudflare IPs up to date:**

Cloudflare occasionally updates their IP ranges. Add the script to cron to re-apply rules automatically:

```bash
sudo crontab -e
# Run every Sunday at 3:00 AM
0 3 * * 0 /path/to/cf-firewall.sh >> /var/log/cf-firewall.log 2>&1
```

**Requirements:**

- Ubuntu Server (tested on 22.04 / 24.04)
- `iptables` and `curl` (pre-installed on most systems)
- `iptables-persistent` for rule persistence (`apt install iptables-persistent`)

### `cf-realip-nginx.sh`

Generates an Nginx config that maps all Cloudflare IP ranges to `set_real_ip_from` directives, so your access logs and application see the actual client IP instead of Cloudflare's proxy IP.

**What it does:**

- Fetches current Cloudflare IPv4 and IPv6 ranges
- Generates `/etc/nginx/conf.d/cloudflare-real-ip.conf` with `set_real_ip_from` for each range
- Uses `CF-Connecting-IP` header to restore the original client address
- Tests Nginx config before reloading - safe to run in production
- Includes a timestamp in the generated file for easy auditing

**Usage:**

```bash
chmod +x cf-realip-nginx.sh
sudo ./cf-realip-nginx.sh
```

**Keeping it up to date:**

```bash
sudo crontab -e
# Run every Sunday at 3:00 AM
0 3 * * 0 /path/to/cf-realip-nginx.sh >> /var/log/cf-real-ip.log 2>&1
```

**Requirements:**

- Nginx with `ngx_http_realip_module` (included in default Ubuntu packages)
- `curl`

### `cf-purge-cache.sh`

Purges Cloudflare cache via API. Supports full zone purge and selective purge by URL - useful in CI/CD pipelines or after manual deployments.

**What it does:**

- Full cache purge with confirmation prompt (no arguments)
- Selective purge for one or more specific URLs (passed as arguments)
- Validates API response and reports errors clearly

**Usage:**

```bash
chmod +x cf-purge-cache.sh

# Purge entire cache (asks for confirmation)
./cf-purge-cache.sh

# Purge specific URLs
./cf-purge-cache.sh https://example.com/page https://example.com/style.css

# Example CI/CD usage (no confirmation needed for URL purge)
./cf-purge-cache.sh https://example.com/assets/app.js
```

**Configuration:**

Set `CF_API_TOKEN` and `CF_ZONE_ID` at the top of the script. The API token needs the `Zone.Cache Purge` permission - create one at [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens).

**Requirements:**

- `curl`
- `jq` (only for selective URL purge)

## License

MIT