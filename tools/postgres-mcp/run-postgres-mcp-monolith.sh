#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment
export PG_HOST="10.111.160.60"
export PG_PORT="5432"
export PG_LOCAL_PORT="20003"
export PG_USER="operator_ro"
export PG_PASS="FKHRbM8uVxVEHv9p0rQK1qZM885go502CwIH1MTo6MNtC1IXrqsPh8l8zJe0uN3N"
export PG_DB_NAME="nurturecloud"
export DATABASE_URI="postgresql://operator_ro:FKHRbM8uVxVEHv9p0rQK1qZM885go502CwIH1MTo6MNtC1IXrqsPh8l8zJe0uN3N@localhost:20003/nurturecloud"

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
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Tunnel ready. Starting postgres-mcp SSE on port 20103..."

# Run postgres-mcp with SSE
exec /Users/miere/.local/bin/postgres-mcp --transport=sse --sse-port=20103 --sse-host=localhost --access-mode=restricted
