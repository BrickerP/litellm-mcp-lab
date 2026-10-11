#!/usr/bin/env python3
"""Minimal stdio MCP server for the lab.

Exposes one tool (`echo`) so you can verify an MCP client (Cursor, Claude Code,
or a custom agent) can talk to a local server without depending on cloud APIs.

This is a teaching stub — not a production MCP server.

Requires: pip install mcp
Run:      python mcp_servers/echo_mcp.py
"""

from __future__ import annotations

import asyncio

try:
    from mcp.server import Server
    from mcp.server.stdio import stdio_server
    from mcp.types import TextContent, Tool
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "Missing dependency: pip install 'mcp>=1.0'\n"
        "Or: uv pip install mcp"
    ) from exc


server = Server("lab-echo")


@server.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="echo",
            description="Return the input text unchanged. Lab smoke-test tool.",
            inputSchema={
                "type": "object",
                "properties": {
                    "text": {"type": "string", "description": "Text to echo back"},
                },
                "required": ["text"],
            },
        )
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    if name != "echo":
        raise ValueError(f"Unknown tool: {name}")
    text = arguments.get("text", "")
    return [TextContent(type="text", text=f"echo: {text}")]


async def main() -> None:
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
