import {getAuth} from "firebase-admin/auth";
import {Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {defineSecret} from "firebase-functions/params";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {Resend} from "resend";
import {DeletionReason, canEmail, deletionChange, pausedEmail, restoredEmail} from "./accountEmails";

const resendKey = defineSecret("RESEND_API_KEY");

/**
 * Emails the person when their account is marked for deletion (asked for,
 * or left inactive) and when it is brought back. Watches the marker itself
 * rather than the callables, so every way in and out of a deletion is
 * covered. A purge removes the document and sends nothing.
 */
export const onAccountDeletionChanged = onDocumentWritten(
    {document: "users/{uid}", secrets: [resendKey]},
    async (event) => {
      const change = event.data;
      if (!change) return;
      const after = change.after.exists ? change.after.get("deletion") : undefined;
      const kind = deletionChange(change.before.get("deletion"), after, change.after.exists);
      if (!kind) return;

      const uid = event.params.uid;
      let email: string | undefined;
      try {
        email = (await getAuth().getUser(uid)).email;
      } catch (error) {
        logger.warn("no user to email", {uid, error: String(error)});
        return;
      }
      if (!canEmail(email)) {
        logger.info("account email skipped: no reachable address", {uid, kind});
        return;
      }

      const mail = kind === "paused" ?
        pausedEmail({
          to: email,
          purgeAfter: (after.purgeAfter as Timestamp).toDate(),
          reason: (after.reason as DeletionReason | undefined) ?? "requested",
        }) :
        restoredEmail({to: email});
      const {data, error} = await new Resend(resendKey.value()).emails.send({
        from: "Three Bucks <support@widgetmedialabs.com>",
        to: email,
        ...mail,
      });
      if (error) {
        logger.error("account email failed", {uid, kind, error: error.message});
        return;
      }
      logger.info("account email sent", {uid, kind, resendId: data?.id});
    },
);
