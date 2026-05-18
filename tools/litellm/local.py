"""Bridge LiteLLM's config-relative loader to the installed ACP router package."""

from litellm_acp_router.router import router_handler

__all__ = ["router_handler"]