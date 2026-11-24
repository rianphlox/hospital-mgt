/**
 * Minimal fetch wrapper with a cookie jar. The HMO portals keep you logged in
 * with session cookies (ASP.NET_SessionId, laravel_session, ...) and set some
 * of them on redirect responses, so redirects are followed by hand to keep
 * every Set-Cookie.
 */

const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";
const MAX_REDIRECTS = 5;
const TIMEOUT_MS = 25_000;

export interface SessionResponse {
  status: number;
  url: string;
  /** Status codes of any redirects that were followed, in order. */
  redirects: number[];
  text: string;
  headers: Headers;
}

export class CookieSession {
  /** host -> cookie name -> value. Paths and expiry are ignored; fine for one portal per session. */
  private jar = new Map<string, Map<string, string>>();
  readonly defaultHeaders: Record<string, string> = { "User-Agent": UA };

  private store(url: URL, res: Response) {
    const lines = typeof res.headers.getSetCookie === "function" ? res.headers.getSetCookie() : [];
    if (!lines.length) return;
    let host = this.jar.get(url.host);
    if (!host) this.jar.set(url.host, (host = new Map()));
    for (const line of lines) {
      const [pair, ...attrs] = line.split(";");
      const eq = pair.indexOf("=");
      if (eq <= 0) continue;
      const name = pair.slice(0, eq).trim();
      const value = pair.slice(eq + 1).trim();
      const expired = attrs.some((a) => {
        const [k, v] = a.split("=").map((s) => s.trim().toLowerCase());
        return (k === "max-age" && Number(v) <= 0) || (k === "expires" && v !== undefined && Date.parse(v) < Date.now());
      });
      if (expired || value === "") host.delete(name);
      else host.set(name, value);
    }
  }

  cookieHeader(url: URL): string {
    const host = this.jar.get(url.host);
    return host ? [...host].map(([k, v]) => `${k}=${v}`).join("; ") : "";
  }

  hasCookie(host: string, name: string): boolean {
    return this.jar.get(host)?.has(name) ?? false;
  }

  async request(
    method: "GET" | "POST",
    url: string,
    opts: { query?: Record<string, string | number>; form?: Record<string, string>; headers?: Record<string, string> } = {},
  ): Promise<SessionResponse> {
    let target = new URL(url);
    if (opts.query) for (const [k, v] of Object.entries(opts.query)) target.searchParams.set(k, String(v));
    let body: string | undefined = opts.form ? new URLSearchParams(opts.form).toString() : undefined;
    const redirects: number[] = [];

    for (;;) {
      const headers: Record<string, string> = { ...this.defaultHeaders, ...(opts.headers ?? {}) };
      const cookie = this.cookieHeader(target);
      if (cookie) headers["Cookie"] = cookie;
      if (body !== undefined) headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8";

      let res: Response;
      try {
        res = await fetch(target, { method, headers, body, redirect: "manual", signal: AbortSignal.timeout(TIMEOUT_MS) });
      } catch (e) {
        throw new Error(`Could not reach ${target.host}: ${(e as Error).message}`);
      }
      this.store(target, res);

      const loc = res.headers.get("location");
      if (res.status >= 300 && res.status < 400 && loc && redirects.length < MAX_REDIRECTS) {
        redirects.push(res.status);
        await res.arrayBuffer().catch(() => undefined);
        target = new URL(loc, target);
        // Browsers switch to GET after 301/302/303.
        if (res.status !== 307 && res.status !== 308) {
          method = "GET";
          body = undefined;
        }
        continue;
      }
      return { status: res.status, url: target.toString(), redirects, text: await res.text(), headers: res.headers };
    }
  }
}

export function parseJson(text: string): unknown | undefined {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}
