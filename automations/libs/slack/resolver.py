"""Channel/user resolver helpers for Slack."""
import re
from slack_sdk import WebClient


def resolve_channel(client: WebClient, name: str) -> str:
    """Resolve a channel name (with or without leading #) to its ID.

    Raises ValueError if the channel is not found.
    """
    name = name.lstrip("#")
    cursor = None
    while True:
        kwargs: dict = {"types": "public_channel,private_channel", "limit": 200}
        if cursor:
            kwargs["cursor"] = cursor
        resp = client.conversations_list(**kwargs)
        for ch in resp.get("channels", []):
            if ch.get("name") == name:
                return ch["id"]
        meta = resp.get("response_metadata", {})
        cursor = meta.get("next_cursor")
        if not cursor:
            break
    raise ValueError(f"Channel '{name}' not found.")


def resolve_user(client: WebClient, handle: str) -> str:
    """Resolve a user handle (with or without leading @) to a user ID.

    Raises ValueError if the user is not found.
    """
    handle = handle.lstrip("@").lower()
    cursor = None
    while True:
        kwargs: dict = {"limit": 200}
        if cursor:
            kwargs["cursor"] = cursor
        resp = client.users_list(**kwargs)
        for member in resp.get("members", []):
            if member.get("name", "").lower() == handle:
                return member["id"]
        meta = resp.get("response_metadata", {})
        cursor = meta.get("next_cursor")
        if not cursor:
            break
    raise ValueError(f"User '{handle}' not found.")


def open_dm(client: WebClient, user_id: str) -> str:
    """Open (or retrieve) a DM channel with *user_id* and return the channel ID."""
    resp = client.conversations_open(users=[user_id])
    return resp["channel"]["id"]


def resolve_mentions(text: str, client: WebClient) -> str:
    """Convert @handle mentions in text to <@USER_ID> Slack syntax.

    Unresolvable handles are left as-is with a warning to stderr.
    """
    import sys

    pattern = r'(?<!\w)@([a-zA-Z0-9._-]+)'

    def replace_match(match: re.Match) -> str:
        handle = match.group(1)
        try:
            user_id = resolve_user(client, handle)
            return f'<@{user_id}>'
        except ValueError:
            print(f"Warning: user '@{handle}' not found, leaving as plain text.", file=sys.stderr)
            return match.group(0)  # leave as-is

    return re.sub(pattern, replace_match, text)
