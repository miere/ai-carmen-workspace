#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# VARIABLES
TMP_DIR="temp"

# FUNCTIONS
create_session() {
    local MODEL="$1"
    local AGENT_NAME="$2"
    local WORKSPACE_ROOT="${3:-}"
    local ADD_WORKSPACE="${4:-}"

    local TMP_FILE
    TMP_FILE="$(mktemp "$TMP_DIR/auggie-session-id.XXXXXX")"

    local AUGGIE_PARAMS=(
        --print
        "--model=$MODEL"
    )

    if [[ -n "$WORKSPACE_ROOT" ]]; then
        AUGGIE_PARAMS+=("--workspace-root=$WORKSPACE_ROOT")
    fi

    if [[ -n "$ADD_WORKSPACE" ]]; then
        AUGGIE_PARAMS+=("--add-workspace=$ADD_WORKSPACE")
    fi

    auggie "${AUGGIE_PARAMS[@]}" \
        --instruction="You are $AGENT_NAME. Just say '$(date)' so I know you are ready." \
        > "$TMP_FILE"

    auggie \
        --startup-script-file=./auggie-print-current-session.sh \
        --print \
        --continue \
        --dont-save-session \
        'Just "now".' \
        > "${TMP_FILE}.2"

    sed '/AUGGIE_SESSION_ID/!d;s/.*=//' "${TMP_FILE}.2"

#    rm -f "$TMP_FILE" "${TMP_FILE}.2"
}

run_auggie() {
    local SESSION_ID="$1"
    local PROMPT="$2"

    auggie \
        --resume="$SESSION_ID" \
        --print \
        --instruction="$PROMPT"
}

usage() {
    printf 'Usage:\n'
    printf '  %s init <model> <agent-name> [workspace-root] [add-workspace]\n' "$0"
    printf '  %s send-to <session-id> <prompt>\n' "$0"
}

# MAIN
mkdir -p "$TMP_DIR"

CMD="${1:-}"

if [[ $# -gt 0 ]]; then
    shift
fi

case "$CMD" in
    init)
        create_session "$@"
        ;;
    send-to)
        run_auggie "$@"
        ;;
    *)
        usage
        exit 1
        ;;
esac

