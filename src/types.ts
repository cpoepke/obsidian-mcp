import { z } from "zod";

export const CreateNoteSchema = z.object({
  path: z.string().describe("Path to the note (e.g. 'folder/note.md')"),
  content: z.string().describe("Markdown content for the note"),
});

export const ReadNoteSchema = z.object({
  path: z.string().describe("Path to the note to read"),
});

export const UpdateNoteSchema = z.object({
  path: z.string().describe("Path to the note to update"),
  content: z.string().describe("New markdown content for the note"),
});

export const DeleteNoteSchema = z.object({
  path: z.string().describe("Path to the note to delete"),
});

export const SearchSchema = z.object({
  query: z.string().describe("Search query string"),
});

export const DataviewSchema = z.object({
  query: z.string().describe("Dataview DQL query string"),
});

export const ExecuteCommandSchema = z.object({
  commandId: z.string().describe("ID of the Obsidian command to execute"),
});
