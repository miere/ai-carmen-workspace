#!/usr/bin/env bash
set -e
cd $(dirname $0)

# VARIABLES
TMP_FILE=tmp/auggie-session-id.$$
MODEL="$1"
AGENT_NAME="$2"

# MAIN
auggie --print \
  --model=$MODEL \
  --instruction="You are $AGENT_NAME. Just say '$(date)' so I know you are ready." > $TMP_FILE

auggie --print --continue --dont-save-session 'Just "now".' > ${TMP_FILE}.2

cat ${TMP_FILE}.2 |
  sed '/AUGGIE_SESSION_ID/!d;s/.*=//' &&
  rm $TMP_FILE*

