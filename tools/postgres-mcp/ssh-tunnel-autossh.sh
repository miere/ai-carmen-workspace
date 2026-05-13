#!/usr/bin/env bash
cd "$(dirname "$0")"

# =[PROFILE]=================================================================
PROFILE=$1
if [ -z "$PROFILE" ]; then
    echo "Usage: $0 <profile>"
    exit 1
fi

if [ -f ".env.$PROFILE" ]; then
    source ".env.$PROFILE"
else
    echo "Profile file .env.$PROFILE not found"
    exit 1
fi

# =[VARIABLES]==============================================================
PG_HOST=${PG_HOST:-localhost}
PG_PORT=${PG_PORT:-5432}
PG_LOCAL_PORT=${PG_LOCAL_PORT:-5434}
SSH_KEY=${SSH_KEY:-~/.ssh/id_rsa}
REMOTE_USER=${REMOTE_USER:-miere}
REMOTE_IP=${REMOTE_IP:-34.151.77.117}

# =[AUTOSSH]================================================================
# AUTOSSH_GATETIME: espera 0 segundos antes de reconectar la primera vez
# AUTOSSH_POLL: cada 60 segundos revisa si el puerto del tunel responde
export AUTOSSH_GATETIME=0
export AUTOSSH_POLL=60

# ServerAliveInterval: ping cada 30 segundos
# ServerAliveCountMax: tras 3 pings fallidos, reconecta
# ExitOnForwardFailure: si no puede crear el puerto local, muere (launchd reinicia)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting autossh tunnel... [$PG_HOST:$PG_PORT -> localhost:${PG_LOCAL_PORT}]"
/opt/homebrew/bin/autossh -M 0 \
  -N \
  -i "$SSH_KEY" \
  -L "${PG_LOCAL_PORT}:${PG_HOST}:${PG_PORT}" \
  -o "ServerAliveInterval=30" \
  -o "ServerAliveCountMax=3" \
  -o "ExitOnForwardFailure=yes" \
  -o "StrictHostKeyChecking=accept-new" \
  "${REMOTE_USER}@${REMOTE_IP}"
