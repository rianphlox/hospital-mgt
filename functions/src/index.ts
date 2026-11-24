/**
 * CrownLog Cloud Functions.
 *
 * - hmoLookup: checks a patient against an HMO provider portal (THT, PHML).
 */
import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";

initializeApp();

setGlobalOptions({ region: "europe-west1", maxInstances: 5 });

export { hmoLookup } from "./hmoLookup";
