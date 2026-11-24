/**
 * PHML (Premier Health Management), on its Laravel provider ERP.
 *
 * Login: GET /hospital/auth for a fresh CSRF `_token`, then an AJAX POST to
 * /hospital/login that answers {status, message}. The search is the
 * DataTables feed behind the "Enrollees" page: the lives assigned to this
 * hospital, searchable by NHIS number or name. It does NOT say whether cover
 * is active, so rows come back with status "on list". A family (principal,
 * spouse, children) shares one NHIS number.
 */
import { CookieSession, parseJson } from "./http";
import { toDdMmYyyy, titleCase } from "./dates";
import { HmoAdapter, HmoLoginError, HmoPortalError, HmoRecord, SessionExpiredError } from "./types";

export const PHML_BASE = "https://erp.phmlnigeria.com";
const ID = "phml";
const LABEL = "PHML";
const LIMIT = 50;
const COLS = ["nhis_no", "firstname", "surname", "sex", "date_of_birth", "dependant_type"];

export const PHML_NOTICE = "PHML enrollees assigned to this hospital. PHML's list does not show whether cover is active.";

const str = (v: unknown): string => (v === null || v === undefined ? "" : String(v).trim());

export function phmlRowToRecord(row: Record<string, unknown>): HmoRecord {
  return {
    hmo: ID,
    memberId: str(row.nhis_no),
    name: titleCase([row.firstname, row.surname].map(str).filter(Boolean).join(" ")),
    sex: str(row.sex) || null,
    dateOfBirth: toDdMmYyyy(row.date_of_birth),
    relationship: str(row.dependant_type) || null,
    plan: null,
    status: "on list",
    coverEnds: null,
    notes: null,
  };
}

export function phmlQuery(text: string): Record<string, string | number> {
  const p: Record<string, string | number> = {
    draw: 1,
    start: 0,
    length: LIMIT,
    "search[value]": text,
    "search[regex]": "false",
    "order[0][column]": 2,
    "order[0][dir]": "asc",
  };
  COLS.forEach((c, i) => {
    p[`columns[${i}][data]`] = c;
    p[`columns[${i}][name]`] = c;
    p[`columns[${i}][searchable]`] = "true";
    p[`columns[${i}][orderable]`] = "true";
    p[`columns[${i}][search][value]`] = "";
    p[`columns[${i}][search][regex]`] = "false";
  });
  return p;
}

interface PhmlSession {
  http: CookieSession;
  token: string;
}

export const phmlAdapter: HmoAdapter<PhmlSession> = {
  id: ID,
  label: LABEL,
  queryHint: "NHIS number or name",

  async login({ user, password }) {
    const http = new CookieSession();
    const page = await http.request("GET", `${PHML_BASE}/hospital/auth`);
    if (page.status >= 400) throw new HmoPortalError(`PHML portal error (${page.status}) on the login page`);
    const token = /name="_token"\s+value="([^"]+)"/.exec(page.text)?.[1];
    if (!token) throw new HmoPortalError("PHML login page changed: no _token field found");

    const r = await http.request("POST", `${PHML_BASE}/hospital/login`, {
      form: { _token: token, email: user, password },
      headers: { "X-Requested-With": "XMLHttpRequest", Accept: "application/json" },
    });
    const data = parseJson(r.text) as { status?: unknown; message?: unknown } | undefined;
    if (!data) throw new HmoPortalError(`PHML portal sent an unreadable login answer (${r.status})`);
    if (!data.status) throw new HmoLoginError(LABEL, str(data.message) || "the portal rejected the email or password");
    return { http, token };
  },

  async search({ http, token }, query) {
    const r = await http.request("GET", `${PHML_BASE}/hospital/dashboard/enrollees/datatables`, {
      query: { ...phmlQuery(query), _: Date.now() },
      headers: { "X-Requested-With": "XMLHttpRequest", "X-CSRF-TOKEN": token, Accept: "application/json" },
    });
    if (r.status === 401 || r.status === 419 || r.redirects.length) throw new SessionExpiredError(LABEL);
    if (r.status >= 400) throw new HmoPortalError(`PHML portal error (${r.status})`);
    const data = parseJson(r.text) as { data?: unknown; recordsFiltered?: unknown } | undefined;
    if (!data || !Array.isArray(data.data)) {
      if (/<html/i.test(r.text)) throw new SessionExpiredError(LABEL);
      throw new HmoPortalError("PHML portal sent an unreadable answer");
    }
    const records = (data.data as Record<string, unknown>[]).map(phmlRowToRecord);
    const total = Number(data.recordsFiltered);
    return {
      records,
      total: Number.isFinite(total) && total > records.length ? total : undefined,
      notice: PHML_NOTICE,
    };
  },
};
