#!/usr/bin/env bash
cd $(dirname "$0")

# =[PROFILE]=================================================================
PROFILE=$1
if [ -z "$PROFILE" ]; then
    echo "Usage: $0 <profile>"
    exit 1
fi

if [ -f ".env.$PROFILE" ]; then
    source .env.$PROFILE
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

# =[MAIN]===================================================================
echo "Creating SSH tunnel...[$PG_HOST:$PG_PORT -> localhost:${PG_LOCAL_PORT}]"
ssh -N \
 -i $SSH_KEY \
 -L ${PG_LOCAL_PORT}:${PG_HOST}:${PG_PORT} \
 ${REMOTE_USER}@${REMOTE_IP}
