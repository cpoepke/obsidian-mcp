export class ObsidianClient {
  constructor(private baseUrl: string, private apiKey?: string) {}

  private headers(extra?: Record<string, string>): Record<string, string> {
    const h: Record<string, string> = {};
    if (this.apiKey) h["Authorization"] = `Bearer ${this.apiKey}`;
    if (extra) Object.assign(h, extra);
    return h;
  }

  async getNote(path: string): Promise<string> {
    validatePath(path);
    const res = await fetch(`${this.baseUrl}/vault/${encodeURIPath(path)}`, {
      headers: this.headers({ Accept: "text/markdown" }),
    });
    if (!res.ok) throw new Error(`Failed to read note: HTTP ${res.status}`);
    return res.text();
  }

  async putNote(path: string, content: string): Promise<void> {
    validatePath(path);
    const res = await fetch(`${this.baseUrl}/vault/${encodeURIPath(path)}`, {
      method: "PUT",
      headers: this.headers({ "Content-Type": "text/markdown" }),
      body: content,
    });
    if (!res.ok) throw new Error(`Failed to write note: HTTP ${res.status}`);
  }

  async deleteNote(path: string): Promise<void> {
    validatePath(path);
    const res = await fetch(`${this.baseUrl}/vault/${encodeURIPath(path)}`, {
      method: "DELETE",
      headers: this.headers(),
    });
    if (!res.ok) throw new Error(`Failed to delete note: HTTP ${res.status}`);
  }

  async listNotes(): Promise<string[]> {
    const res = await fetch(`${this.baseUrl}/vault/`, {
      headers: this.headers(),
    });
    if (!res.ok) throw new Error(`Failed to list notes: HTTP ${res.status}`);
    return res.json() as Promise<string[]>;
  }

  async searchSimple(query: string): Promise<unknown> {
    const res = await fetch(
      `${this.baseUrl}/search/simple/?query=${encodeURIComponent(query)}`,
      { headers: this.headers() }
    );
    if (!res.ok) throw new Error(`Search failed: HTTP ${res.status}`);
    return res.json();
  }

  async searchDataview(dql: string): Promise<unknown> {
    const res = await fetch(`${this.baseUrl}/search/`, {
      method: "POST",
      headers: this.headers({ "Content-Type": "application/vnd.olrapi.dataview.dql+txt" }),
      body: dql,
    });
    if (!res.ok) throw new Error(`Dataview query failed: HTTP ${res.status}`);
    return res.json();
  }

  async listCommands(): Promise<unknown> {
    const res = await fetch(`${this.baseUrl}/commands/`, {
      headers: this.headers(),
    });
    if (!res.ok) throw new Error(`Failed to list commands: HTTP ${res.status}`);
    return res.json();
  }

  async executeCommand(commandId: string): Promise<unknown> {
    const res = await fetch(`${this.baseUrl}/commands/${encodeURIComponent(commandId)}`, {
      method: "POST",
      headers: this.headers(),
    });
    if (!res.ok) throw new Error(`Failed to execute command: HTTP ${res.status}`);
    return res.json();
  }
}

function validatePath(path: string): void {
  if (path.includes("..") || path.startsWith("/") || path.startsWith("\\")) {
    throw new Error("Invalid path: must be relative without traversal");
  }
}

function encodeURIPath(path: string): string {
  return path.split("/").map(encodeURIComponent).join("/");
}
