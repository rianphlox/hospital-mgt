/**
 * HMO registry plus the per-instance session cache.
 *
 * To add an HMO: write an adapter (see tht.ts / phml.ts), add it to ADAPTERS,
 * and give it secrets in index.ts (getCredentials).
 */
import { HmoAdapter, HmoCredentials, HmoSearchResult, SessionExpiredError } from "./types";
import { thtAdapter } from "./tht";
import { phmlAdapter } from "./phml";

export const ADAPTERS: Record<string, HmoAdapter<any>> = {
  [thtAdapter.id]: thtAdapter,
  [phmlAdapter.id]: phmlAdapter,
};

export const HMO_IDS = Object.keys(ADAPTERS);

/** How long a portal login is reused before logging in again. */
export const SESSION_TTL_MS = 20 * 60 * 1000;

interface CachedSession {
  session: Promise<unknown>;
  expiresAt: number;
}

const sessions = new Map<string, CachedSession>();

function getSession(adapter: HmoAdapter<any>, creds: HmoCredentials, now: number): Promise<unknown> {
  const cached = sessions.get(adapter.id);
  if (cached && cached.expiresAt > now) return cached.session;
  // Store the promise so parallel requests share one login.
  const session = adapter.login(creds);
  sessions.set(adapter.id, { session, expiresAt: now + SESSION_TTL_MS });
  session.catch(() => {
    if (sessions.get(adapter.id)?.session === session) sessions.delete(adapter.id);
  });
  return session;
}

export function clearSessions() {
  sessions.clear();
}

/**
 * Runs a lookup with a cached login. If the portal has logged us out (or the
 * search fails in any way on a reused session), logs in again and retries once.
 */
export async function lookup(hmoId: string, query: string, creds: HmoCredentials): Promise<HmoSearchResult> {
  const adapter = ADAPTERS[hmoId];
  if (!adapter) throw new Error(`Unknown HMO: ${hmoId}`);
  const reused = sessions.has(adapter.id) && sessions.get(adapter.id)!.expiresAt > Date.now();
  try {
    return await adapter.search(await getSession(adapter, creds, Date.now()), query);
  } catch (e) {
    if (!(e instanceof SessionExpiredError) && !reused) throw e;
    sessions.delete(adapter.id);
    return await adapter.search(await getSession(adapter, creds, Date.now()), query);
  }
}
