# obsidian-mcp

MCP server that exposes an Obsidian vault as 9 MCP tools via the Obsidian REST API.

## Architecture

- **Runtime**: Node 22 Alpine
- **Transport**: HTTP (Express + StreamableHTTPServerTransport) or stdio
- **Auth**: Bearer token for MCP clients (`MCP_API_KEY`), separate key for Obsidian REST API (`OBSIDIAN_API_KEY`)
- **Sessions**: One McpServer instance per session (required by SDK), 30-min TTL with cleanup

### Security

- **Path traversal protection**: All note paths validated (rejects `..` and absolute paths)
- **Timing-safe auth**: Bearer token compared with `crypto.timingSafeEqual`
- **Error sanitization**: HTTP status codes only, no vault content in error messages
- **Required env vars**: Both `OBSIDIAN_API_KEY` and `MCP_API_KEY` (HTTP) are mandatory

## 9 MCP tools

`create_note`, `read_note`, `update_note`, `delete_note`, `list_notes`, `search`, `search_dataview`, `list_commands`, `execute_command`

## Required environment variables

- `OBSIDIAN_API_KEY` — Key for the Obsidian REST API (must match obsidian-docker's `LOCAL_REST_API_KEY`)
- `MCP_API_KEY` — Key for MCP client authentication (HTTP transport only)

## Build, lint, and test

```bash
npm install
npm run check   # tsc --noEmit
npm run lint     # knip (unused code detection)
npm run build    # tsc → dist/

# Integration tests (requires running obsidian-docker container)
OBSIDIAN_API_KEY=<key> MCP_API_KEY=<key> docker compose up -d --build
./tests/seed-vault.sh
./tests/run-tests.sh http://127.0.0.1:3001 <mcp-key>
OBSIDIAN_API_KEY=x MCP_API_KEY=x docker compose down -v
```

## Key files

- `src/index.ts` — Express server, session management, transport setup
- `src/server.ts` — MCP tool definitions (9 tools)
- `src/obsidian-client.ts` — HTTP client for Obsidian REST API with path validation
- `src/auth.ts` — Timing-safe Bearer token middleware
- `src/types.ts` — Zod schemas for tool arguments
- `docker-compose.yml` — Pulls obsidian-docker from GHCR + builds MCP server locally
- `tests/run-tests.sh` — 37 MCP protocol integration tests

## Dependencies

- `@modelcontextprotocol/sdk` — MCP protocol implementation
- `express` — HTTP server (v5)
- `zod` — Schema validation (v4)
- `knip` — Unused code detection (dev)
- `typescript` — v6 (dev)

## Sister repo

[obsidian-docker](https://github.com/cpoepke/obsidian-docker) — Headless Obsidian Docker image that provides the REST API this server connects to.
