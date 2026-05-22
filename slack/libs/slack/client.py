"""SlackClient — thin wrapper around slack_sdk.WebClient."""
from __future__ import annotations
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

_ENV_PATH = Path("~/.hermes/.env").expanduser()


class SlackClient:
    """Authenticated Slack web client with convenience methods."""

    def __init__(self) -> None:
        load_dotenv(dotenv_path=_ENV_PATH, override=False)
        token = os.environ.get("SLACK_BOT_TOKEN")
        if not token:
            print(
                "Error: SLACK_BOT_TOKEN not set. "
                f"Add it to {_ENV_PATH} or export it as an environment variable.",
                file=sys.stderr,
            )
            sys.exit(1)
        self._client = WebClient(token=token)

    @property
    def api(self) -> WebClient:
        """Expose underlying WebClient for use in resolver helpers."""
        return self._client

    # ------------------------------------------------------------------
    # Core API methods
    # ------------------------------------------------------------------

    def post_message(self, channel_id: str, text: str) -> dict:
        """Post a message to a channel (or DM channel) by ID."""
        try:
            resp = self._client.chat_postMessage(channel=channel_id, text=text)
            return resp.data
        except SlackApiError as exc:
            print(f"Slack error (chat.postMessage): {exc.response['error']}", file=sys.stderr)
            sys.exit(1)

    def get_history(self, channel_id: str, oldest_ts: float, limit: int = 100) -> list[dict]:
        """Return up to *limit* messages in *channel_id* since *oldest_ts*."""
        try:
            resp = self._client.conversations_history(
                channel=channel_id,
                oldest=str(oldest_ts),
                limit=limit,
            )
            return resp.get("messages", [])
        except SlackApiError as exc:
            print(f"Slack error (conversations.history): {exc.response['error']}", file=sys.stderr)
            sys.exit(1)

    def get_replies(self, channel_id: str, thread_ts: str, oldest_ts: float | None = None) -> list[dict]:
        """Return all replies in a thread identified by *thread_ts*."""
        try:
            kwargs: dict = dict(channel=channel_id, ts=thread_ts)
            if oldest_ts is not None:
                kwargs["oldest"] = str(oldest_ts)
            resp = self._client.conversations_replies(**kwargs)
            return resp.get("messages", [])
        except SlackApiError as exc:
            print(f"Slack error (conversations.replies): {exc.response['error']}", file=sys.stderr)
            sys.exit(1)

    def upload_file(
        self,
        channel_id: str,
        file_path: str,
        filename: str | None = None,
        title: str | None = None,
        initial_comment: str | None = None,
        snippet_type: str | None = None,
    ) -> dict:
        """Upload a file to a channel/DM and optionally post an initial comment."""
        try:
            resp = self._client.files_upload_v2(
                channel=channel_id,
                file=file_path,
                filename=filename,
                title=title,
                initial_comment=initial_comment,
                snippet_type=snippet_type,
            )
            return resp.data
        except SlackApiError as exc:
            print(f"Slack error (files.upload): {exc.response['error']}", file=sys.stderr)
            sys.exit(1)
