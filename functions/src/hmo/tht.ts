/**
 * Total Health Trust (THT), on the Tangerine "Medicloud" provider portal.
 *
 * Login is a plain form POST to /portal/Main/Login; the portal then keeps us
 * signed in with the ASP.NET_SessionId cookie. A failed login sends the login
 * form back. Eligibility is a JSON GET by enrollee ID (e.g. AF1234567890_1).
 */
import { CookieSession, parseJson } from "./http";
import { toDdMmYyyy, titleCase } from "./dates";
import { HmoAdapter, HmoLoginError, HmoPortalError, HmoRecord, SessionExpiredError } from "./types";

export const THT_BASE = "https://totalhealthtrust.tangerine.africa/portal";
const ID = "tht";
const LABEL = "THT";

type ThtRow = Record<string, unknown>;

const str = (v: unknown): string => (v === null || v === undefined ? "" : String(v).trim());

export function thtRowToRecord(row: ThtRow): HmoRecord {
  const eligible = str(row.EligibilityStatus).toUpperCase() === "ELIGIBLE";
  const name = titleCase([row.FirstName, row.OtherName, row.LastName].map(str).filter(Boolean).join(" "));
  const notes = [
    str(row.IneligibilityReason),
    str(row.ProviderName) && `Provider: ${str(row.ProviderName)}`,
    str(row.GroupName) && `Group: ${str(row.GroupName)}`,
  ].filter(Boolean);
  return {
    hmo: ID,
    memberId: str(row.LegacyCode) || str(row.InsuredID),
    name,
    sex: str(row.Gender) || null,
    dateOfBirth: toDdMmYyyy(row.DateOfBirth),
    relationship: str(row.DependantType) || null,
    plan: str(row.PlanName) || null,
    status: eligible ? "eligible" : "not eligible",
    coverEnds: toDdMmYyyy(row.MemberTermDate) ?? toDdMmYyyy(row.GroupTermDate),
    notes: notes.length ? notes.join(" · ") : null,
  };
}

export const thtAdapter: HmoAdapter<CookieSession> = {
  id: ID,
  label: LABEL,
  queryHint: "THT enrollee ID, e.g. AF1234567890_1",

  async login({ user, password }) {
    const s = new CookieSession();
    await s.request("GET", `${THT_BASE}/`);
    const r = await s.request("POST", `${THT_BASE}/Main/Login`, { form: { loginUser: user, loginPassword: password } });
    if (r.status >= 500) throw new HmoPortalError(`THT portal error (${r.status}) during login`);
    if (r.text.includes('id="loginForm"')) throw new HmoLoginError(LABEL, "the portal rejected the username or password");
    return s;
  },

  async search(s, query) {
    const r = await s.request("GET", `${THT_BASE}/api/AccountLogin/GetEligibilityIID`, {
      query: { iid: query },
      headers: { Accept: "application/json" },
    });
    if (r.status === 401 || r.status === 403 || r.redirects.length) throw new SessionExpiredError(LABEL);
    if (r.status >= 400) throw new HmoPortalError(`THT portal error (${r.status})`);
    const data = parseJson(r.text);
    if (data === undefined) {
      // An HTML page instead of JSON means we were bounced to the login page.
      if (/<html/i.test(r.text)) throw new SessionExpiredError(LABEL);
      throw new HmoPortalError("THT portal sent an unreadable answer");
    }
    const rows: ThtRow[] = Array.isArray(data) ? data : data && typeof data === "object" ? [data as ThtRow] : [];
    return { records: rows.filter((r) => r && (r.FirstName || r.LastName || r.LegacyCode)).map(thtRowToRecord) };
  },
};
