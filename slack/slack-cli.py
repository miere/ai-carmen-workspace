#!/usr/bin/env python3
"""slack-cli — send messages and fetch messages from Slack."""
import argparse
import sys
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from pathlib import Path

# Ensure libs/ is on the path regardless of CWD
_LIBS = Path(__file__).parent / "libs"
if str(_LIBS) not in sys.path:
    sys.path.insert(0, str(_LIBS))

from slack.client import SlackClient  # noqa: E402
from slack.resolver import open_dm, resolve_channel, resolve_mentions, resolve_user  # noqa: E402


# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

def _format_message(msg: dict) -> str:
    """Format a Slack message dict as '[HH:MM] @user: text'."""
    ts = float(msg.get("ts", 0))
    dt = datetime.fromtimestamp(ts, tz=ZoneInfo("Australia/Sydney"))
    time_str = dt.strftime("%H:%M")
    user = msg.get("username") or msg.get("user") or "unknown"
    text = msg.get("text", "")
    return f"[{time_str}] @{user}: {text}"


def _print_messages(messages: list[dict]) -> None:
    for msg in reversed(messages):  # oldest first
        print(_format_message(msg))


# ---------------------------------------------------------------------------
# Subcommand handlers
# ---------------------------------------------------------------------------

def cmd_send_msg(args: argparse.Namespace) -> None:
    client = SlackClient()

    # Resolve target: #channel or @user
    to = args.to
    if to.startswith("#"):
        channel_id = resolve_channel(client.api, to)
    elif to.startswith("@"):
        user_id = resolve_user(client.api, to)
        channel_id = open_dm(client.api, user_id)
    else:
        print("Error: --to must start with # (channel) or @ (user).", file=sys.stderr)
        sys.exit(1)

    # Resolve @handle mentions in body so Slack tags users properly
    body = resolve_mentions(args.body, client.api)

    # Send with or without file attachment
    if args.attachment:
        attachment_path = Path(args.attachment)
        if not attachment_path.exists():
            print(f"Error: attachment not found: {args.attachment}", file=sys.stderr)
            sys.exit(1)

        client.upload_file(
            channel_id=channel_id,
            file_path=str(attachment_path),
            filename=attachment_path.name,
            title=attachment_path.name,
            initial_comment=body,
            snippet_type=args.attachment_type,
        )
    else:
        client.post_message(channel_id, body)

    print(f"Message sent to {to}.")


def cmd_fetch_msgs(args: argparse.Namespace) -> None:
    client = SlackClient()
    channel_id = resolve_channel(client.api, args.channel)

    # Parse --since (Sydney time). Default: 24 hours ago.
    if args.since:
        try:
            since_dt = datetime.strptime(args.since, "%Y-%m-%d %H:%M:%S").replace(
                tzinfo=ZoneInfo("Australia/Sydney")
            )
        except ValueError:
            print(
                "Error: --since must be in format 'YYYY-MM-DD HH:mm:ss' (Sydney time).",
                file=sys.stderr,
            )
            sys.exit(1)
    else:
        since_dt = datetime.now(tz=ZoneInfo("Australia/Sydney")) - timedelta(hours=24)
    oldest_ts = since_dt.timestamp()

    if args.thread:
        messages = client.get_replies(channel_id, args.thread, oldest_ts=oldest_ts)
    else:
        messages = client.get_history(channel_id, oldest_ts)

    _print_messages(messages)


def cmd_fetch_reactions(args: argparse.Namespace) -> None:
    client = SlackClient()
    channel_id = resolve_channel(client.api, args.channel)
    user_id = resolve_user(client.api, getattr(args, "from"))

    # Parse --since (Sydney time). Default: 24 hours ago.
    if args.since:
        try:
            since_dt = datetime.strptime(args.since, "%Y-%m-%d %H:%M:%S").replace(
                tzinfo=ZoneInfo("Australia/Sydney")
            )
        except ValueError:
            print(
                "Error: --since must be in format 'YYYY-MM-DD HH:mm:ss' (Sydney time).",
                file=sys.stderr,
            )
            sys.exit(1)
    else:
        since_dt = datetime.now(tz=ZoneInfo("Australia/Sydney")) - timedelta(hours=24)
    oldest_ts = since_dt.timestamp()

    messages = client.get_history(channel_id, oldest_ts)
    filtered = [m for m in messages if any(r.get("name") == args.emoji.strip(":") and user_id in r.get("users", []) for r in m.get("reactions", []))]
    _print_messages(filtered)

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="slack-cli",
        description="Send and fetch Slack messages from the terminal.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # send-msg
    p_send = sub.add_parser("send-msg", help="Send a message to a channel or user.")
    p_send.add_argument("--body", required=True, help="Message body text.")
    p_send.add_argument(
        "--to",
        required=True,
        help="Destination: #channel or @user.",
    )
    p_send.add_argument(
        "--attachment",
        default=None,
        help="Path to a file to attach to the message.",
    )
    p_send.add_argument(
        "--attachment-type",
        choices=["markdown"],
        default=None,
        help="Force Slack to treat the attachment as this type (e.g. markdown).",
    )
    p_send.set_defaults(func=cmd_send_msg)

    # fetch-msgs
    p_fetch = sub.add_parser("fetch-msgs", help="Fetch messages from a channel or thread.")
    p_fetch.add_argument(
        "--channel",
        required=True,
        help="Channel name (with or without #).",
    )
    p_fetch.add_argument(
        "--thread",
        default=None,
        metavar="TS",
        help="Thread timestamp (e.g. 1234567890.123456) to fetch replies from.",
    )
    p_fetch.add_argument(
        "--since",
        default=None,
        metavar="YYYY-MM-DD HH:mm:ss",
        help="Exclude messages sent before this Sydney datetime (default: 24h ago).",
    )
    p_fetch.set_defaults(func=cmd_fetch_msgs)

    # fetch-reactions
    p_rx = sub.add_parser("fetch-reactions", help="Fetch messages a specific user reacted to.")
    p_rx.add_argument(
        "--from",
        required=True,
        help="User handle (with or without @).",
    )
    p_rx.add_argument(
        "--emoji",
        required=True,
        help="Emoji name (e.g. thumbsup, with or without colons).",
    )
    p_rx.add_argument(
        "--channel",
        required=True,
        help="Channel name (with or without #).",
    )
    p_rx.add_argument(
        "--since",
        default=None,
        metavar="YYYY-MM-DD HH:mm:ss",
        help="Exclude messages sent before this Sydney datetime (default: 24h ago).",
    )
    p_rx.set_defaults(func=cmd_fetch_reactions)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
