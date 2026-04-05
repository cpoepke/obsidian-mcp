import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { ObsidianClient } from "./obsidian-client.js";
import {
  CreateNoteSchema,
  ReadNoteSchema,
  UpdateNoteSchema,
  DeleteNoteSchema,
  SearchSchema,
  DataviewSchema,
  ExecuteCommandSchema,
} from "./types.js";

export function createMcpServer(obsidianUrl: string, obsidianApiKey?: string): McpServer {
  const obsidian = new ObsidianClient(obsidianUrl, obsidianApiKey);

  const server = new McpServer({
    name: "obsidian-mcp",
    version: "1.0.0",
  });

  server.tool(
    "create_note",
    "Create a new note in the Obsidian vault",
    { path: CreateNoteSchema.shape.path, content: CreateNoteSchema.shape.content },
    async ({ path, content }) => {
      try {
        await obsidian.putNote(path, content);
        return { content: [{ type: "text", text: `Created note: ${path}` }] };
      } catch (e) {
        return { content: [{ type: "text", text: `Error: ${e}` }], isError: true };
      }
    }
  );

  server.tool(
    "read_note",
    "Read the content of a note from the vault",
    { path: ReadNoteSchema.shape.path },
    async ({ path }) => {
      try {
        const content = await obsidian.getNote(path);
        return { content: [{ type: "text", text: content }] };
      } catch (e) {
        return { content: [{ type: "text", text: `Error: ${e}` }], isError: true };
      }
    }
  );

  server.tool(
    "update_note",
    "Update (replace) the content of an existing note",
    { path: UpdateNoteSchema.shape.path, content: UpdateNoteSchema.shape.content },
    async ({ path, content }) => {
      try {
        await obsidian.putNote(path, content);
        return { content: [{ type: "text", text: `Updated note: ${path}` }] };
      } catch (e) {
        return { content: [{ type: "text", text: `Error: ${e}` }], isError: true };
      }
    }
  );

  server.tool(
    "delete_note",
    "Delete a note from the vault",
    { path: DeleteNoteSchema.shape.path },
    async ({ path }) => {
      try {
        await obsidian.deleteNote(path);
        return { content: [{ type: "text", text: `Deleted note: ${path}` }] };
      } catch (e) {
        return { content: [{ type: "text", text: `Error: ${e}` }], isError: true };
      }
    }
  );

  server.tool(
    "list_notes",
    "List all files in the Obsidian vault",
    async () => {
      try {
        const files = await obsidian.listNotes();
        return { content: [{ type: "text", text: JSON.stringify(files, null, 2) }] };
      } catch (e) {
        return { content: [{ type: "text", text: `Error: ${e}` }], isError: true };
      }
    }
  );

  server.tool(
    "search",
    "Full-text search across the vault",
    { query: SearchSchema.shape.query },
    async ({ query }) => {
      try {
        const results = await obsidian.searchSimple(query);
        return { content: [{ type: "text", text: JSON.stringify(results, null, 2) }] };
      } catch (e) {
        return { content: [{ type: "text", text: `Error: ${e}` }], isError: true };
      }
    }
  );

  server.tool(
    "search_dataview",
    "Run a Dataview DQL query against the vault",
    { query: DataviewSchema.shape.query },
    async ({ query }) => {
      try {
        const results = await obsidian.searchDataview(query);
        return { content: [{ type: "text", text: JSON.stringify(results, null, 2) }] };
      } catch (e) {
        return { content: [{ type: "text", text: `Error: ${e}` }], isError: true };
      }
    }
  );

  server.tool(
    "list_commands",
    "List all available Obsidian commands",
    async () => {
      try {
        const commands = await obsidian.listCommands();
        return { content: [{ type: "text", text: JSON.stringify(commands, null, 2) }] };
      } catch (e) {
        return { content: [{ type: "text", text: `Error: ${e}` }], isError: true };
      }
    }
  );

  server.tool(
    "execute_command",
    "Execute an Obsidian command by its ID",
    { commandId: ExecuteCommandSchema.shape.commandId },
    async ({ commandId }) => {
      try {
        const result = await obsidian.executeCommand(commandId);
        return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
      } catch (e) {
        return { content: [{ type: "text", text: `Error: ${e}` }], isError: true };
      }
    }
  );

  return server;
}
