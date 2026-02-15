#!/bin/bash
# =============================================================================
# @author: https://github.com/abnvle
# Cloudflare Cache Purge Script
# Purges cache for a given zone - supports full purge and selective URL purge
#
# Usage:
#   ./cf-purge-cache.sh                          # purge everything
#   ./cf-purge-cache.sh https://example.com/page  # purge specific URLs
#   ./cf-purge-cache.sh url1 url2 url3            # purge multiple URLs
# =============================================================================

set -euo pipefail

# ======================== CONFIGURATION ========================
CF_API_TOKEN=""      # <-- Cloudflare API token (Zone.Cache Purge permission)
CF_ZONE_ID=""        # <-- Zone ID (found in Cloudflare dashboard -> Overview)
# ===============================================================

CF_API_URL="https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache"

# Validate configuration
if [[ -z "$CF_API_TOKEN" || -z "$CF_ZONE_ID" ]]; then
    echo "[ERROR] CF_API_TOKEN and CF_ZONE_ID must be set in the script."
    exit 1
fi

purge_all() {
    echo "[INFO] Purging entire cache for zone $CF_ZONE_ID..."

    RESPONSE=$(curl -sf -X POST "$CF_API_URL" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"purge_everything":true}') || {
        echo "[ERROR] API request failed."
        exit 1
    }

    if echo "$RESPONSE" | grep -q '"success":true'; then
        echo "[OK] Full cache purge completed."
    else
        echo "[ERROR] Purge failed."
        echo "        $RESPONSE"
        exit 1
    fi
}

purge_urls() {
    local urls=("$@")
    local json_urls

    # Build JSON array of URLs
    json_urls=$(printf '%s\n' "${urls[@]}" | jq -R . | jq -s '.')

    echo "[INFO] Purging ${#urls[@]} URL(s) from cache..."
    for url in "${urls[@]}"; do
        echo "       - $url"
    done

    RESPONSE=$(curl -sf -X POST "$CF_API_URL" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"files\":$json_urls}") || {
        echo "[ERROR] API request failed."
        exit 1
    }

    if echo "$RESPONSE" | grep -q '"success":true'; then
        echo "[OK] URL cache purge completed."
    else
        echo "[ERROR] Purge failed."
        echo "        $RESPONSE"
        exit 1
    fi
}

# Check for jq (needed for URL purge)
if [[ $# -gt 0 ]] && ! command -v jq &>/dev/null; then
    echo "[ERROR] jq is required for selective URL purge: apt install jq"
    exit 1
fi

# Main
if [[ $# -eq 0 ]]; then
    read -rp "[CONFIRM] Purge entire cache for zone $CF_ZONE_ID? (y/N): " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        purge_all
    else
        echo "[INFO] Aborted."
    fi
else
    purge_urls "$@"
fi