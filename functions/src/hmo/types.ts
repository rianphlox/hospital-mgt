/**
 * Common shapes for HMO lookups. Every HMO adapter returns HmoRecord rows so
 * the app can render THT, PHML and future HMOs the same way.
 */

export type HmoStatus = "eligible" | "not eligible" | "on list";

export interface HmoRecord {
  hmo: string;
  /** The ID staff would quote back to the HMO (THT legacy code, PHML NHIS number). */
  memberId: string;
  name: string;
  sex: string | null;
  /** dd/mm/yyyy, or null when the portal does not give one. */
  dateOfBirth: string | null;
  /** Principal, Spouse, Son, Child 1, ... */
  relationship: string | null;
  plan: string | null;
  status: HmoStatus;
  /** dd/mm/yyyy, or null when unknown. */
  coverEnds: string | null;
  notes: string | null;
}

export interface HmoSearchResult {
  records: HmoRecord[];
  /** Total matches on the portal, when it is larger than what we returned. */
  total?: number;
  /** A short line the app shows above the results (e.g. what the list means). */
  notice?: string;
}

export interface HmoCredentials {
  user: string;
  password: string;
}

/**
 * One adapter per HMO. `login` returns an opaque logged-in session; `search`
 * runs the lookup with it and throws SessionExpiredError if the portal has
 * logged us out, so the caller can log in again and retry once.
 */
export interface HmoAdapter<S = unknown> {
  id: string;
  label: string;
  /** What the query box accepts, shown in error messages. */
  queryHint: string;
  login(creds: HmoCredentials): Promise<S>;
  search(session: S, query: string): Promise<HmoSearchResult>;
}

/** Wrong username/password, or the portal refused the login. */
export class HmoLoginError extends Error {
  constructor(hmo: string, detail?: string) {
    super(`${hmo} login failed${detail ? `: ${detail}` : ""}`);
    this.name = "HmoLoginError";
  }
}

/** The portal answered like a logged-out user; log in again and retry. */
export class SessionExpiredError extends Error {
  constructor(hmo: string) {
    super(`${hmo} session expired`);
    this.name = "SessionExpiredError";
  }
}

/** The portal is down or answered with something we cannot read. */
export class HmoPortalError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "HmoPortalError";
  }
}
