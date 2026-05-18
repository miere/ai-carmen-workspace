#!/usr/bin/env bash
cd $(dirname $0)
set -e

if [ -d .venv ]; then
  echo -n ":: Custom Python runtime found. Activating..."
  source .venv/bin/activate
  echo "[OK]"
fi

mkdir -p temp

litellm --config "$(pwd)/config.yml" --host 127.0.0.1 --port 30000 2>> temp/litellm.log
