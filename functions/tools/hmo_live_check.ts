/**
 * Live check of the HMO adapters against the real portals, without Firebase.
 * Credentials come from env vars only (never put them in this repo):
 *
 *   THT_USER=... THT_PASSWORD=... PHML_EMAIL=... PHML_PASSWORD=... \
 *     node lib/tools/hmo_live_check.js tht AF1234567890_1
 *
 * Prints counts and statuses only (no patient names) unless --show is passed.
 */
import { lookup } from "../src/hmo/registry";

const CREDS: Record<string, [string, string]> = {
  tht: ["THT_USER", "THT_PASSWORD"],
  phml: ["PHML_EMAIL", "PHML_PASSWORD"],
};

async function main() {
  const [hmo, ...rest] = process.argv.slice(2).filter((a) => a !== "--show");
  const show = process.argv.includes("--show");
  const query = rest.join(" ");
  if (!hmo || !query || !CREDS[hmo]) {
    console.error("Usage: node lib/tools/hmo_live_check.js <tht|phml> <query> [--show]");
    process.exit(2);
  }
  const [u, p] = CREDS[hmo];
  const user = process.env[u];
  const password = process.env[p];
  if (!user || !password) throw new Error(`Set ${u} and ${p}`);

  const t0 = Date.now();
  const r = await lookup(hmo, query, { user, password });
  const t1 = Date.now();
  await lookup(hmo, query, { user, password }); // second call reuses the cached login
  const t2 = Date.now();

  console.log(JSON.stringify({
    hmo,
    count: r.records.length,
    total: r.total ?? r.records.length,
    statuses: r.records.map((x) => x.status),
    relationships: r.records.map((x) => x.relationship),
    memberIds: [...new Set(r.records.map((x) => x.memberId))],
    coverEnds: r.records.map((x) => x.coverEnds),
    fieldsPresent: r.records[0] ? Object.keys(r.records[0]) : [],
    firstCallMs: t1 - t0,
    cachedCallMs: t2 - t1,
  }, null, 2));
  if (show) console.log(JSON.stringify(r.records, null, 2));
}

main().catch((e) => {
  console.error(`${(e as Error).name}: ${(e as Error).message}`);
  process.exit(1);
});
