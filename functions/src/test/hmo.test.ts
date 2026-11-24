import { test } from "node:test";
import assert from "node:assert/strict";
import { toDdMmYyyy } from "../hmo/dates";
import { thtRowToRecord } from "../hmo/tht";
import { phmlRowToRecord, phmlQuery } from "../hmo/phml";
import { lookup, clearSessions, ADAPTERS } from "../hmo/registry";
import { HmoAdapter, SessionExpiredError } from "../hmo/types";

test("portal dates become dd/mm/yyyy", () => {
  assert.equal(toDdMmYyyy("2013-03-30T00:00:00"), "30/03/2013");
  assert.equal(toDdMmYyyy("05 April, 1965"), "05/04/1965");
  assert.equal(toDdMmYyyy("19 November, 2008"), "19/11/2008");
  assert.equal(toDdMmYyyy("0001-01-01T00:00:00"), null);
  assert.equal(toDdMmYyyy(""), null);
  assert.equal(toDdMmYyyy(null), null);
});

test("THT row normalises", () => {
  const r = thtRowToRecord({
    EligibilityStatus: "ELIGIBLE", FirstName: "JOHN", OtherName: "", LastName: "DOE",
    DateOfBirth: "2013-03-30T00:00:00", MemberTermDate: "2026-11-30T00:00:00", PlanName: "FHIS Plan",
    DependantType: "Son", Gender: "Male", LegacyCode: "AF1_4", IneligibilityReason: "", ProviderName: "X Hospital",
  });
  assert.equal(r.status, "eligible");
  assert.equal(r.name, "John Doe");
  assert.equal(r.coverEnds, "30/11/2026");
  assert.equal(r.memberId, "AF1_4");
  assert.equal(thtRowToRecord({ EligibilityStatus: "INELIGIBLE", IneligibilityReason: "Expired" }).status, "not eligible");
});

test("PHML row normalises and query has DataTables params", () => {
  const r = phmlRowToRecord({ nhis_no: "123", firstname: "JANE", surname: "DOE", sex: "Female", date_of_birth: "13 May, 1983", dependant_type: "Spouse" });
  assert.equal(r.status, "on list");
  assert.equal(r.dateOfBirth, "13/05/1983");
  assert.equal(r.relationship, "Spouse");
  const q = phmlQuery("123");
  assert.equal(q["search[value]"], "123");
  assert.equal(q["columns[0][data]"], "nhis_no");
  assert.equal(q["columns[5][data]"], "dependant_type");
});

test("session is cached and re-login happens when it expires", async () => {
  clearSessions();
  let logins = 0;
  let expireNext = false;
  const fake: HmoAdapter<number> = {
    id: "fake", label: "Fake", queryHint: "id",
    async login() { return ++logins; },
    async search(session) {
      if (expireNext) { expireNext = false; throw new SessionExpiredError("Fake"); }
      return { records: [], notice: `session ${session}` };
    },
  };
  ADAPTERS.fake = fake;
  const creds = { user: "u", password: "p" };
  assert.equal((await lookup("fake", "x", creds)).notice, "session 1");
  assert.equal((await lookup("fake", "x", creds)).notice, "session 1");
  expireNext = true;
  assert.equal((await lookup("fake", "x", creds)).notice, "session 2");
  assert.equal(logins, 2);
  delete ADAPTERS.fake;
  clearSessions();
});
