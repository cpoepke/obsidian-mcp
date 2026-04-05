# =============================================================================
# MCP Server for Obsidian REST API
# Bridges Obsidian REST API into the MCP protocol
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --include=dev

COPY tsconfig.json ./
COPY src/ ./src/
RUN node node_modules/typescript/bin/tsc

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
FROM node:20-alpine

LABEL org.opencontainers.image.title="obsidian-mcp"
LABEL org.opencontainers.image.description="MCP server for the Obsidian REST API"
LABEL org.opencontainers.image.source="https://github.com/cpoepke/obsidian-mcp"

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist/ ./dist/

ENV MCP_TRANSPORT=http
ENV MCP_PORT=3001
ENV OBSIDIAN_API_URL=http://obsidian:27123

EXPOSE 3001

USER node
CMD ["node", "dist/index.js"]
