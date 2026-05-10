#!/usr/bin/env python3
"""slack-cli — send, read, and reply to Slack messages from the terminal."""
import argparse
import sys
import time
from datetime import datetime, timedelta, timezone
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
    dt = datetime.fromtimestamp(ts, tz=timezone.utc).astimezone()
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

def cmd_send(args: argparse.Namespace) -> None:
    client = SlackClient()
    channel_id = resolve_channel(client.api, args.channel)
    args.message = resolve_mentions(args.message, client.api)
    client.post_message(channel_id, args.message)
    print(f"Message sent to #{args.channel.lstrip('#')}.")


def cmd_dm(args: argparse.Namespace) -> None:
    client = SlackClient()
    user_id = resolve_user(client.api, args.handle)
    dm_channel = open_dm(client.api, user_id)
    args.message = resolve_mentions(args.message, client.api)
    client.post_message(dm_channel, args.message)
    print(f"DM sent to @{args.handle.lstrip('@')}.")


def cmd_read(args: argparse.Namespace) -> None:
    client = SlackClient()
    channel_id = resolve_channel(client.api, args.channel)
    if args.since:
        since_dt = datetime.strptime(args.since, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    else:
        since_dt = datetime.now(tz=timezone.utc) - timedelta(hours=24)
    oldest_ts = since_dt.timestamp()
    messages = client.get_history(channel_id, oldest_ts)
    _print_messages(messages)


def cmd_thread(args: argparse.Namespace) -> None:
    client = SlackClient()
    channel_id = resolve_channel(client.api, args.channel)
    replies = client.get_replies(channel_id, args.ts)
    _print_messages(replies)


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="slack-cli",
        description="Send, read, and reply to Slack messages from the terminal.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # send
    p_send = sub.add_parser("send", help="Post a message to a channel.")
    p_send.add_argument("channel", help="Channel name (with or without #)")
    p_send.add_argument("message", help="Message text")
    p_send.set_defaults(func=cmd_send)

    # dm
    p_dm = sub.add_parser("dm", help="Send a direct message to a user.")
    p_dm.add_argument("handle", help="Slack username (with or without @)")
    p_dm.add_argument("message", help="Message text")
    p_dm.set_defaults(func=cmd_dm)

    # read
    p_read = sub.add_parser("read", help="Read recent messages from a channel.")
    p_read.add_argument("channel", help="Channel name (with or without #)")
    p_read.add_argument(
        "--since",
        metavar="YYYY-MM-DD",
        default=None,
        help="Show messages since this date (default: 24 h ago)",
    )
    p_read.set_defaults(func=cmd_read)

    # thread
    p_thread = sub.add_parser("thread", help="Read replies in a message thread.")
    p_thread.add_argument("channel", help="Channel name (with or without #)")
    p_thread.add_argument("--ts", required=True, help="Thread timestamp (e.g. 1234567890.123456)")
    p_thread.set_defaults(func=cmd_thread)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
