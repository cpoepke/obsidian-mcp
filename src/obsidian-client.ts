export class ObsidianClient {
  constructor(private baseUrl: string, private apiKey?: string) {}

  private headers(extra?: Record<string, string>): Record<string, string> {
    const h: Record<string, string> = {};
    if (this.apiKey) h["Authorization"] = `Bearer ${this.apiKey}`;
    if (extra) Object.assign(h, extra);
    return h;
  }

  async getNote(path: string): Promise<string> {
    const res = await fetch(`${this.baseUrl}/vault/${encodeURIPath(path)}`, {
      headers: this.headers({ Accept: "text/markdown" }),
    });
    if (!res.ok) throw new Error(`GET /vault/${path} failed: ${res.status} ${await res.text()}`);
    return res.text();
  }

  async putNote(path: string, content: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/vault/${encodeURIPath(path)}`, {
      method: "PUT",
      headers: this.headers({ "Content-Type": "text/markdown" }),
      body: content,
    });
    if (!res.ok) throw new Error(`PUT /vault/${path} failed: ${res.status} ${await res.text()}`);
  }

  async deleteNote(path: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/vault/${encodeURIPath(path)}`, {
      method: "DELETE",
      headers: this.headers(),
    });
    if (!res.ok) throw new Error(`DELETE /vault/${path} failed: ${res.status} ${await res.text()}`);
  }

  async listNotes(): Promise<string[]> {
    const res = await fetch(`${this.baseUrl}/vault/`, {
      headers: this.headers(),
    });
    if (!res.ok) throw new Error(`GET /vault/ failed: ${res.status} ${await res.text()}`);
    return res.json() as Promise<string[]>;
  }

  async searchSimple(query: string): Promise<unknown> {
    const res = await fetch(
      `${this.baseUrl}/search/simple/?query=${encodeURIComponent(query)}`,
      { headers: this.headers() }
    );
    if (!res.ok) throw new Error(`Search failed: ${res.status} ${await res.text()}`);
    return res.json();
  }

  async searchDataview(dql: string): Promise<unknown> {
    const res = await fetch(`${this.baseUrl}/search/`, {
      method: "POST",
      headers: this.headers({ "Content-Type": "application/vnd.olrapi.dataview.dql+txt" }),
      body: dql,
    });
    if (!res.ok) throw new Error(`Dataview query failed: ${res.status} ${await res.text()}`);
    return res.json();
  }

  async listCommands(): Promise<unknown> {
    const res = await fetch(`${this.baseUrl}/commands/`, {
      headers: this.headers(),
    });
    if (!res.ok) throw new Error(`GET /commands/ failed: ${res.status} ${await res.text()}`);
    return res.json();
  }

  async executeCommand(commandId: string): Promise<unknown> {
    const res = await fetch(`${this.baseUrl}/commands/${encodeURIComponent(commandId)}`, {
      method: "POST",
      headers: this.headers(),
    });
    if (!res.ok) throw new Error(`POST /commands/${commandId} failed: ${res.status} ${await res.text()}`);
    return res.json();
  }
}

function encodeURIPath(path: string): string {
  return path.split("/").map(encodeURIComponent).join("/");
}
