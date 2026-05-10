#!/bin/bash
set -euo pipefail

# PR Slack Notifier — checks for new PR review requests, posts one message per PR
# Runs as Hermes no_agent cron job; posts directly to Slack API (not stdout delivery)

CARMEN_AUTOMATIONS="$HOME/Development/Carmen/automations"
STATE_DIR="$CARMEN_AUTOMATIONS/tmp"
STATE_FILE="$STATE_DIR/prs-slack-state.json"
CHANNEL="C0B24F579T4"  # nc-code-reviews

# ── Load Slack token ────────────────────────────────────────────────────────
source ~/.hermes/.env 2>/dev/null || true
SLACK_TOKEN="${SLACK_BOT_TOKEN:-}"

if [[ -z "$SLACK_TOKEN" ]]; then
  echo "ERROR: SLACK_BOT_TOKEN not found" >&2
  exit 1
fi

# ── Ensure state file exists ─────────────────────────────────────────────────
mkdir -p "$STATE_DIR"
if [ ! -f "$STATE_FILE" ]; then
  echo '{"seen_prs":[],"last_check":null}' > "$STATE_FILE"
fi

# ── Read already-seen PRs ────────────────────────────────────────────────────
SEEN=$(jq -r '.seen_prs[]?' "$STATE_FILE")

# ── Fetch open PRs where @me is reviewer ─────────────────────────────────────
CURRENT=""
for org in miere UpsideRealty; do
  result=$(gh search prs --owner "$org" --state open --review-requested @me \
    --json number,title,url,repository,createdAt,author 2>/dev/null || echo "[]")
  CURRENT="${CURRENT}${result}"
done

# Merge results, filter out bots
CURRENT=$(echo "$CURRENT" | jq -s 'add | map(select(.author.login != "dependabot[bot]"))')

# ── Find and post new PRs ────────────────────────────────────────────────────
NEW_COUNT=0

while IFS= read -r pr; do
  repo=$(echo "$pr" | jq -r '.repository.nameWithOwner')
  num=$(echo "$pr" | jq -r '.number')
  id="${repo}#${num}"

  if ! echo "$SEEN" | grep -qxF "$id"; then
    title=$(echo "$pr" | jq -r '.title')
    author=$(echo "$pr" | jq -r '.author.login')
    url=$(echo "$pr" | jq -r '.url')
    link="<$url|$repo#$num>"

    # Build message: **title** \n Author: @author \n <link>
    msg=$(printf '%s\n%s\n%s' \
      "*${title//\*/\\*}*" \
      "Author: @${author}" \
      "${link}")

    # Post to Slack
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST https://slack.com/api/chat.postMessage \
      -H "Authorization: Bearer ${SLACK_TOKEN}" \
      -H "Content-Type: application/json; charset=utf-8" \
      --data-raw "$(jq -n \
        --arg ch "$CHANNEL" \
        --arg txt "$msg" \
        '{channel: $ch, text: $txt, unfurl_links: false, unfurl_media: false}')" 2>/dev/null)

    if [ "$http_code" = "200" ]; then
      echo "  ✓ posted: $id" >&2
      NEW_COUNT=$((NEW_COUNT + 1))
    else
      echo "  ✗ FAILED ($http_code): $id" >&2
    fi

    # Respect rate limits (1 msg/sec for burst, but we're well under)
    sleep 0.3
  fi
done < <(echo "$CURRENT" | jq -c '.[]')

# ── Update state file ────────────────────────────────────────────────────────
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "$CURRENT" | jq -c '[.[] | "\(.repository.nameWithOwner)#\(.number)"]' > /tmp/prs-slack-new.json
jq -n --arg now "$NOW" --slurpfile new /tmp/prs-slack-new.json \
  '{seen_prs: $new[0], last_check: $now}' > "$STATE_FILE"
rm -f /tmp/prs-slack-new.json

# ── Log summary (to stderr so stdout stays clean) ────────────────────────────
if [ "$NEW_COUNT" -gt 0 ]; then
  echo "pr-slack-notifier: posted ${NEW_COUNT} new PR(s) — $(date '+%H:%M')" >&2
else
  echo "pr-slack-notifier: no new PRs — $(date '+%H:%M')" >&2
fi
