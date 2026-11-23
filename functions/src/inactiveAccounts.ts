import {getAuth} from "firebase-admin/auth";
import * as logger from "firebase-functions/logger";
import {eraseAccount, scheduleDeletion} from "./accountDeletion";
import {sendAccountEmail} from "./accountMail";
import {isInactive, lastActive} from "./inactivity";

/** Accounts handled per run, so a backlog spreads over nights, not one timeout. */
const MAX_PER_RUN = 500;

/**
 * Lets go of accounts nobody has opened in INACTIVE_DAYS. One of the
 * janitor's nightly chores (see janitor.ts).
 *  - Anonymous: erased now. There is no one to tell, and the phone keeps
 *    its own copy; opening the app again starts a fresh account.
 *  - Linked: marked for deletion like a request, with reason "inactive",
 *    which emails a warning. Opening the app cancels it.
 * @return {Promise<number>} How many accounts were erased or marked.
 */
export async function markInactiveAccounts(): Promise<number> {
  const now = new Date();
  let done = 0;
  let pageToken: string | undefined;
  do {
    const page = await getAuth().listUsers(1000, pageToken);
    for (const user of page.users) {
      if (done >= MAX_PER_RUN) return done;
      if (!isInactive(lastActive(user.metadata), now)) continue;
      try {
        if (user.providerData.length === 0) {
          await eraseAccount(user.uid);
          done++;
        } else {
          const {purgeAfter, marked} = await scheduleDeletion(user.uid, "inactive");
          if (marked) {
            await sendAccountEmail(user.uid, {kind: "paused", purgeAfter: purgeAfter.toDate(), reason: "inactive"});
            done++;
          }
        }
      } catch (error) {
        logger.error("inactive account not handled", {uid: user.uid, error: String(error)});
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);
  return done;
}
