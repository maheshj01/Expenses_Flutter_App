import {setGlobalOptions} from "firebase-functions/v2";

/**
 * Settings for every function, kept small so the bill stays near zero.
 * Imported first by index.ts: options set after a function is defined
 * don't apply to it.
 *
 * - One region, next to Firestore's nam5 (US), so nothing pays for
 *   cross-region traffic.
 * - 256 MiB: the work is a few Firestore and Auth calls, not computing.
 * - At most two instances of any function, so a burst of calls (the
 *   callables accept anyone signed in, even anonymously, until App Check
 *   is added) queues instead of scaling up the bill.
 * - No minimum instances: nothing runs, or is billed, between calls.
 */
setGlobalOptions({
  region: "us-central1",
  memory: "256MiB",
  maxInstances: 2,
  minInstances: 0,
});
