/**
 * hmoLookup: checks a patient against an HMO provider portal (THT, PHML, ...)
 * so front-desk staff don't have to open each HMO's website.
 *
 * The portal logins are Secret Manager secrets and never reach the app.
 * Logs carry the HMO, the caller and a result count only, never the query or
 * patient details.
 */
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { z } from "zod";

import { ADAPTERS, HMO_IDS, lookup } from "./hmo/registry";
import { HmoCredentials, HmoLoginError, HmoPortalError } from "./hmo/types";

const THT_USER = defineSecret("THT_USER");
const THT_PASSWORD = defineSecret("THT_PASSWORD");
const PHML_EMAIL = defineSecret("PHML_EMAIL");
const PHML_PASSWORD = defineSecret("PHML_PASSWORD");

/** Add new HMO secrets here and in `secrets` below. */
function getCredentials(hmo: string): HmoCredentials {
  switch (hmo) {
    case "tht":
      return { user: THT_USER.value(), password: THT_PASSWORD.value() };
    case "phml":
      return { user: PHML_EMAIL.value(), password: PHML_PASSWORD.value() };
    default:
      throw new HttpsError("invalid-argument", `Unknown HMO: ${hmo}`);
  }
}

const RequestSchema = z.object({
  hmo: z.string().trim().toLowerCase(),
  query: z.string().trim().min(2, "Enter at least 2 characters.").max(80),
});

export const hmoLookup = onCall(
  {
    region: "europe-west1", // Must match HmoService.region in the app.
    secrets: [THT_USER, THT_PASSWORD, PHML_EMAIL, PHML_PASSWORD],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (req: CallableRequest<unknown>) => {
    if (!req.auth) throw new HttpsError("unauthenticated", "Sign in first.");

    const parsed = RequestSchema.safeParse(req.data);
    if (!parsed.success) {
      throw new HttpsError("invalid-argument", parsed.error.issues[0]?.message ?? "Invalid request.");
    }
    const { hmo, query } = parsed.data;
    const adapter = ADAPTERS[hmo];
    if (!adapter) throw new HttpsError("invalid-argument", `Unknown HMO "${hmo}". Use one of: ${HMO_IDS.join(", ")}.`);

    const creds = getCredentials(hmo);
    if (!creds.user || !creds.password) {
      throw new HttpsError("failed-precondition", `${adapter.label} login is not set up on the server yet.`);
    }

    const started = Date.now();
    try {
      const result = await lookup(hmo, query, creds);
      logger.info("hmo.lookup", { uid: req.auth.uid, hmo, n: result.records.length, ms: Date.now() - started });
      return {
        hmo,
        label: adapter.label,
        results: result.records,
        total: result.total ?? result.records.length,
        notice: result.notice ?? null,
        message: result.records.length ? null : `No ${adapter.label} enrollee found for "${query}". Check the ${adapter.queryHint}.`,
      };
    } catch (e) {
      logger.warn("hmo.lookup_failed", { uid: req.auth.uid, hmo, error: (e as Error).name, detail: (e as Error).message });
      if (e instanceof HmoLoginError) {
        throw new HttpsError("failed-precondition", `Could not sign in to ${adapter.label}. The saved ${adapter.label} login may have changed.`);
      }
      if (e instanceof HmoPortalError) throw new HttpsError("unavailable", `${adapter.label}: ${e.message}`);
      throw new HttpsError("unavailable", `Could not reach the ${adapter.label} portal. Try again shortly.`);
    }
  },
);
