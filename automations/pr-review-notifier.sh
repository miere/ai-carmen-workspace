#!/bin/bash
set -euo pipefail

# PR Review Notifier — checks for new PR review requests, posts to Discord
# Runs as Hermes no_agent cron job; posts directly to Discord API

CARMEN_AUTOMATIONS="$HOME/Development/Carmen/automations"
STATE_DIR="$CARMEN_AUTOMATIONS/tmp"
STATE_FILE="$STATE_DIR/prs-review-state.json"
CHANNEL="1502954289977495613"

# ── Load Discord token ────────────────────────────────────────────────────────
source ~/.hermes/.env 2>/dev/null || true
DISCORD_TOKEN="${DISCORD_BOT_TOKEN:-}"

if [[ -z "$DISCORD_TOKEN" ]]; then
  echo "ERROR: DISCORD_BOT_TOKEN not found" >&2
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

    # Only notify if directly assigned (not just via a team)
    direct=$(gh pr view "$url" --json reviewRequests --jq \
      '[.reviewRequests[] | select(.__typename == "User" and .login == "miere")] | length' 2>/dev/null || echo "ERR")
    if [ "$direct" = "ERR" ]; then
      echo "  ⚠ API error for $id — posting as fallback" >&2
    elif [ "$direct" = "0" ]; then
      echo "  ⊘ indirect (team only): $id" >&2
      continue
    fi

    # Post to Discord as an embed
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "https://discord.com/api/v10/channels/${CHANNEL}/messages" \
      -H "Authorization: Bot ${DISCORD_TOKEN}" \
      -H "Content-Type: application/json; charset=utf-8" \
      --data-raw "$(jq -n \
        --arg title "$title" \
        --arg author "$author" \
        --arg url "$url" \
        --arg repo "$repo" \
        --arg num "$num" \
        '{
          embeds: [{
            title: $title,
            url: $url,
            color: 5814783,
            author: { name: $author },
            footer: { text: "\($repo)#\($num)" },
            timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
          }]
        }')" 2>/dev/null)

    if [ "$http_code" = "200" ]; then
      echo "  ✓ posted: $id" >&2
      NEW_COUNT=$((NEW_COUNT + 1))
    else
      echo "  ✗ FAILED ($http_code): $id" >&2
    fi

    sleep 0.3
  fi
done < <(echo "$CURRENT" | jq -c '.[]')

# ── Update state file ────────────────────────────────────────────────────────
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "$CURRENT" | jq -c '[.[] | .repository.nameWithOwner + "#" + (.number|tostring)]' > /tmp/prs-review-new.json
jq -n --arg now "$NOW" --slurpfile new /tmp/prs-review-new.json \
  '{seen_prs: $new[0], last_check: $now}' > "$STATE_FILE"
rm -f /tmp/prs-review-new.json

# ── Log summary ──────────────────────────────────────────────────────────────
if [ "$NEW_COUNT" -gt 0 ]; then
  echo "pr-review-notifier: posted ${NEW_COUNT} new PR(s) — $(date '+%H:%M')" >&2
else
  echo "pr-review-notifier: no new PRs — $(date '+%H:%M')" >&2
fi
