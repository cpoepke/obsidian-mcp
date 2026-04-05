import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express from "express";
import { randomUUID } from "node:crypto";
import { createMcpServer } from "./server.js";
import { createAuthMiddleware } from "./auth.js";

const OBSIDIAN_API_URL = process.env.OBSIDIAN_API_URL || "http://localhost:27123";
const OBSIDIAN_API_KEY = process.env.OBSIDIAN_API_KEY;
const MCP_TRANSPORT = process.env.MCP_TRANSPORT || "http";
const MCP_PORT = parseInt(process.env.MCP_PORT || "3001", 10);
const MCP_API_KEY = process.env.MCP_API_KEY;

async function main() {
  if (MCP_TRANSPORT === "stdio") {
    const mcpServer = createMcpServer(OBSIDIAN_API_URL, OBSIDIAN_API_KEY);
    const transport = new StdioServerTransport();
    await mcpServer.connect(transport);
    console.error("MCP server running on stdio");
    return;
  }

  // HTTP transport
  if (!MCP_API_KEY) {
    console.error("ERROR: MCP_API_KEY is required for HTTP transport");
    process.exit(1);
  }

  const app = express();

  // Health endpoint (unauthenticated)
  app.get("/health", (_req, res) => {
    res.json({ status: "ok" });
  });

  const authMiddleware = createAuthMiddleware(MCP_API_KEY);

  // Map of active transports by session ID
  const transports = new Map<string, StreamableHTTPServerTransport>();

  // MCP endpoint (authenticated)
  app.post("/mcp", authMiddleware, async (req, res) => {
    const sessionId = req.headers["mcp-session-id"] as string | undefined;
    let transport: StreamableHTTPServerTransport;

    if (sessionId && transports.has(sessionId)) {
      transport = transports.get(sessionId)!;
    } else if (!sessionId) {
      // New session — create a fresh server and transport per session
      // (McpServer only supports one transport connection at a time)
      const mcpServer = createMcpServer(OBSIDIAN_API_URL, OBSIDIAN_API_KEY);
      transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => randomUUID(),
      });
      transport.onclose = () => {
        if (transport.sessionId) transports.delete(transport.sessionId);
      };
      await mcpServer.connect(transport);
    } else {
      res.status(404).json({ error: "Session not found" });
      return;
    }

    await transport.handleRequest(req, res);

    // Store session after handleRequest (sessionId is assigned during request handling)
    if (transport.sessionId && !transports.has(transport.sessionId)) {
      transports.set(transport.sessionId, transport);
    }
  });

  app.get("/mcp", authMiddleware, async (req, res) => {
    const sessionId = req.headers["mcp-session-id"] as string | undefined;
    if (!sessionId || !transports.has(sessionId)) {
      res.status(400).json({ error: "Missing or invalid session ID" });
      return;
    }
    const transport = transports.get(sessionId)!;
    await transport.handleRequest(req, res);
  });

  app.delete("/mcp", authMiddleware, async (req, res) => {
    const sessionId = req.headers["mcp-session-id"] as string | undefined;
    if (!sessionId || !transports.has(sessionId)) {
      res.status(400).json({ error: "Missing or invalid session ID" });
      return;
    }
    const transport = transports.get(sessionId)!;
    await transport.handleRequest(req, res);
  });

  app.listen(MCP_PORT, () => {
    console.log(`MCP server listening on port ${MCP_PORT} (HTTP transport)`);
    console.log(`Obsidian API: ${OBSIDIAN_API_URL}`);
  });
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
