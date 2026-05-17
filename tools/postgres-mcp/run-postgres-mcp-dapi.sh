#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment
export PG_HOST="10.3.1.10"
export PG_PORT="5432"
export PG_LOCAL_PORT="20002"
export PG_USER="operator_ro"
export PG_PASS="rFE5Lt74NqAM00OnyNBurkR0wamda4rnNigLrCf1gYWMSNolsMoOPejOp38ktjvb"
export PG_DB_NAME="data-stable"
export DATABASE_URI="postgresql://operator_ro:rFE5Lt74NqAM00OnyNBurkR0wamda4rnNigLrCf1gYWMSNolsMoOPejOp38ktjvb@localhost:20002/data-stable"

# Wait for tunnel (max 30s)
TIMEOUT=30
WAITED=0
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for tunnel on localhost:${PG_LOCAL_PORT}..."
while ! nc -z localhost "${PG_LOCAL_PORT}" 2>/dev/null; do
    sleep 1
    WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge "$TIMEOUT" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Tunnel on port ${PG_LOCAL_PORT} not available after ${TIMEOUT}s"
        exit 1
    fi
done
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Tunnel ready. Starting postgres-mcp SSE on port 20102..."

# Run postgres-mcp with SSE
exec /Users/miere/.local/bin/postgres-mcp --transport=sse --sse-port=20102 --sse-host=localhost --access-mode=restricted
