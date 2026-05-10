"""Slack helpers — re-exported for convenience."""
from .client import SlackClient
from .resolver import resolve_channel, resolve_user, open_dm

__all__ = ["SlackClient", "resolve_channel", "resolve_user", "open_dm"]
