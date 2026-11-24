const MONTHS = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];

const pad = (n: number) => String(n).padStart(2, "0");

/**
 * Turns the date formats the portals use into dd/mm/yyyy.
 *  - "2013-03-30T00:00:00" (THT, ISO)
 *  - "05 April, 1965" (PHML)
 * Returns null for empty input and for .NET's "no date" value (year 0001).
 */
export function toDdMmYyyy(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const s = raw.trim();
  if (!s) return null;

  const iso = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
  if (iso) {
    const [, y, m, d] = iso;
    if (Number(y) < 1900) return null;
    return `${d}/${m}/${y}`;
  }

  const words = /^(\d{1,2})\s+([A-Za-z]+),?\s+(\d{4})$/.exec(s);
  if (words) {
    const month = MONTHS.findIndex((m) => m.startsWith(words[2].toLowerCase().slice(0, 3)));
    if (month >= 0) return `${pad(Number(words[1]))}/${pad(month + 1)}/${words[3]}`;
  }

  const dmy = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(s);
  if (dmy) return `${pad(Number(dmy[1]))}/${pad(Number(dmy[2]))}/${dmy[3]}`;

  return s; // Unknown format: show what the portal gave rather than dropping it.
}

export function titleCase(s: string): string {
  return s.toLowerCase().replace(/\b([a-z])/g, (c) => c.toUpperCase());
}
