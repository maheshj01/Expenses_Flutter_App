import {getAuth} from "firebase-admin/auth";
import * as logger from "firebase-functions/logger";
import {defineSecret} from "firebase-functions/params";
import {Resend} from "resend";
import {DeletionReason, canEmail, pausedEmail, restoredEmail} from "./accountEmails";

/** Resend's API key. Functions that send email list it in `secrets`. */
export const resendKey = defineSecret("RESEND_API_KEY");

/** What happened to the account, and for "paused", when it goes and why. */
export type AccountNews =
  | {kind: "paused"; purgeAfter: Date; reason: DeletionReason}
  | {kind: "restored"};

/**
 * Emails the person when their account is marked for deletion (asked for,
 * or left inactive) and when it's brought back. Called by the code that
 * makes those changes (accountDeletion.ts, inactiveAccounts.ts) rather
 * than from a Firestore trigger: one function fewer, and no Eventarc.
 *
 * Never throws: a missing address or a failed send is logged, and the
 * deletion or restore it reports on still stands.
 * @param {string} uid The account.
 * @param {AccountNews} news What to tell them.
 */
export async function sendAccountEmail(uid: string, news: AccountNews): Promise<void> {
  try {
    const email = (await getAuth().getUser(uid)).email;
    if (!canEmail(email)) {
      logger.info("account email skipped: no reachable address", {uid, kind: news.kind});
      return;
    }
    const mail = news.kind === "paused" ?
      pausedEmail({to: email, purgeAfter: news.purgeAfter, reason: news.reason}) :
      restoredEmail({to: email});
    const {data, error} = await new Resend(resendKey.value()).emails.send({
      from: "Three Bucks <support@widgetmedialabs.com>",
      to: email,
      ...mail,
    });
    if (error) {
      logger.error("account email failed", {uid, kind: news.kind, error: error.message});
      return;
    }
    logger.info("account email sent", {uid, kind: news.kind, resendId: data?.id});
  } catch (error) {
    logger.error("account email failed", {uid, kind: news.kind, error: String(error)});
  }
}
