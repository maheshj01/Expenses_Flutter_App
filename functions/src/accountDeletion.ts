import {getAuth} from "firebase-admin/auth";
import {DocumentReference, FieldValue, QueryDocumentSnapshot, Timestamp, getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import type {DeletionReason} from "./accountEmails";
import {sendAccountEmail, resendKey} from "./accountMail";
import {decideDeletion, purgeAfter} from "./deletionPolicy";
import {cameBack, lastActive} from "./inactivity";

/**
 * Account deletion, done on the server so the clock, the grace period and
 * the recursive delete cannot be bent by a client.
 *
 *   users/{uid}.deletion = {requestedAt, purgeAfter, reason}
 *
 * reason is "requested" (the person asked) or "inactive" (the janitor's
 * inactiveAccounts chore). The app cancels an "inactive" mark by itself
 * when it is opened; a requested one waits for the person to restore it.
 *
 * In Three Bucks users/{uid} usually has no fields of its own, only the
 * synced subcollections, so the marker is written with merge and may be
 * what creates the document.
 *
 * While that field is set, firestore.rules refuse every client write under
 * users/{uid}, so a second phone still signed in cannot refill the account.
 * The purge removes the Auth user and the sharing data first and the tree
 * last, so a run that stops halfway leaves the marker in place and the next
 * run finishes it.
 *
 * Deploy: firebase deploy --only functions:requestAccountDeletion,functions:restoreAccount,functions:janitor
 */

/** Accounts purged per page of the daily sweep. */
const PURGE_PAGE = 100;

const db = () => getFirestore();
const userDoc = (uid: string) => db().collection("users").doc(uid);

// Three Bucks has no App Check yet. Once it is added, turn enforceAppCheck
// on for both callables (Epoch uses `!inEmulator`, with
// inEmulator = process.env.FUNCTIONS_EMULATOR === "true").
const enforceAppCheck = false;

/**
 * Anonymous: erased now. Linked: marked for deletion in GRACE_DAYS days;
 * asking again keeps the original date rather than pushing it back.
 * Returns {erased: true} or {purgeAfter: <ms since epoch>}.
 */
export const requestAccountDeletion = onCall(
    {enforceAppCheck, timeoutSeconds: 120, secrets: [resendKey]},
    async (request) => {
      const auth = request.auth;
      if (!auth) throw new HttpsError("unauthenticated", "sign in first");
      const uid = auth.uid;

      const user = await getAuth().getUser(uid);
      if (decideDeletion(user.providerData.length === 0) === "erase") {
        await eraseAccount(uid);
        logger.info("anonymous account erased", {uid});
        return {erased: true};
      }

      const {purgeAfter: when, marked} = await scheduleDeletion(uid, "requested");
      logger.info("account scheduled for deletion", {uid, purgeAfter: when.toDate().toISOString()});
      if (marked) {
        await sendAccountEmail(uid, {kind: "paused", purgeAfter: when.toDate(), reason: "requested"});
      }
      return {purgeAfter: when.toMillis()};
    },
);

/**
 * Marks an account for deletion GRACE_DAYS from now, or keeps the date it
 * already has. A person asking to leave takes over a mark left for being
 * inactive, so opening the app no longer cancels it on its own.
 * @param {string} uid The account.
 * @param {DeletionReason} reason Why: asked for, or left inactive.
 * @return {Promise<object>} The purge date, and whether this call set it.
 */
export async function scheduleDeletion(uid: string, reason: DeletionReason):
    Promise<{purgeAfter: Timestamp; marked: boolean}> {
  const ref = userDoc(uid);
  return db().runTransaction(async (tx) => {
    const existing = (await tx.get(ref)).get("deletion") as
      {purgeAfter: Timestamp; reason?: DeletionReason} | undefined;
    if (existing) {
      if (reason === "requested" && existing.reason === "inactive") {
        tx.update(ref, {"deletion.reason": reason});
      }
      return {purgeAfter: existing.purgeAfter, marked: false};
    }
    const at = Timestamp.fromDate(purgeAfter(new Date()));
    tx.set(ref, {deletion: {
      requestedAt: FieldValue.serverTimestamp(),
      purgeAfter: at,
      reason,
    }}, {merge: true});
    return {purgeAfter: at, marked: true};
  });
}

/** Cancels a pending deletion for the signed-in account. */
export const restoreAccount = onCall(
    {enforceAppCheck, secrets: [resendKey]},
    async (request) => {
      const auth = request.auth;
      if (!auth) throw new HttpsError("unauthenticated", "sign in first");
      const ref = userDoc(auth.uid);
      const wasPending = await db().runTransaction(async (tx) => {
        const pending = (await tx.get(ref)).get("deletion") != null;
        if (pending) tx.set(ref, {deletion: FieldValue.delete()}, {merge: true});
        return pending;
      });
      logger.info("account restored", {uid: auth.uid, wasPending});
      if (wasPending) await sendAccountEmail(auth.uid, {kind: "restored"});
      return {restored: true};
    },
);

/**
 * Deletes every account whose grace period has run out. One of the
 * janitor's nightly chores (see janitor.ts).
 * @return {Promise<number>} How many accounts were purged.
 */
export async function purgeDeletedAccounts(): Promise<number> {
  let purged = 0;
  for (;;) {
    const due = await db().collection("users")
        .where("deletion.purgeAfter", "<=", Timestamp.now())
        .limit(PURGE_PAGE)
        .get();
    if (due.empty) break;
    let failed = 0;
    for (const doc of due.docs) {
      try {
        if (await usedSinceMarkedInactive(doc)) {
          await doc.ref.update({deletion: FieldValue.delete()});
          logger.info("inactive mark lifted: account was used", {uid: doc.id});
          await sendAccountEmail(doc.id, {kind: "restored"});
          continue;
        }
        await eraseAccount(doc.id);
        purged++;
      } catch (error) {
        failed++;
        logger.error("purge failed", {uid: doc.id, error: String(error)});
      }
    }
    // A failure would come straight back in the next page; leave the
    // rest for tomorrow's run rather than spin on it.
    if (failed > 0) break;
  }
  return purged;
}

/**
 * An account marked for being inactive that was opened afterwards is not
 * purged, even if the app's own call to clear the mark failed.
 * @param {QueryDocumentSnapshot} doc The users/{uid} doc.
 * @return {Promise<boolean>} True when the mark should be lifted instead.
 */
async function usedSinceMarkedInactive(
    doc: QueryDocumentSnapshot): Promise<boolean> {
  const deletion = doc.get("deletion") as
    {reason?: DeletionReason; requestedAt?: Timestamp} | undefined;
  if (deletion?.reason !== "inactive" || !deletion.requestedAt) return false;
  try {
    const user = await getAuth().getUser(doc.id);
    return cameBack(deletion.requestedAt.toDate(), lastActive(user.metadata));
  } catch (error) {
    if ((error as {code?: string}).code === "auth/user-not-found") return false;
    throw error;
  }
}

/**
 * Deletes the Auth user, then the person's sharing data, then users/{uid}
 * with everything beneath it (entries, categories, entry edits). Safe to
 * repeat: anything already gone is not an error.
 *
 * users/{uid} goes last on purpose: it holds the deletion marker, so if any
 * step before it fails, the marker stays and tomorrow's run tries again.
 *
 * Kept on purpose: bills/ (with bills/{id}/edits) and settlements/ belong
 * to the other people on them as much as to this person, and reports/ are
 * kept for moderation.
 * @param {string} uid The account to erase.
 */
export async function eraseAccount(uid: string): Promise<void> {
  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    if ((error as {code?: string}).code !== "auth/user-not-found") throw error;
  }
  await eraseSharing(uid);
  await db().recursiveDelete(userDoc(uid));
}

/**
 * Deletes what the person shared to be found and connected: profiles/{uid},
 * their handles/{handle} (only while it still names them, since a freed
 * handle may have been claimed by someone else), every connection they are
 * a member of, and every block they made or received. Others' blocks hold
 * a copy of the blocked person's name, so they go too.
 * @param {string} uid The account.
 */
async function eraseSharing(uid: string): Promise<void> {
  const store = db();
  const writer = store.bulkWriter();
  // A failed delete rejects its own promise, not close(); collect them so
  // the erase fails, the marker stays, and tomorrow's run tries again.
  const failures: unknown[] = [];
  const remove = (ref: DocumentReference) => {
    writer.delete(ref).catch((error) => failures.push(error));
  };

  const profile = await store.collection("profiles").doc(uid).get();
  const handle = profile.get("handle") as string | undefined;
  if (handle) {
    const handleRef = store.collection("handles").doc(handle);
    const owner = await handleRef.get();
    if (owner.get("uid") === uid) remove(handleRef);
  }
  remove(profile.ref);

  const queries = [
    store.collection("connections").where("members", "array-contains", uid),
    store.collection("blocks").where("blocker", "==", uid),
    store.collection("blocks").where("blocked", "==", uid),
  ];
  for (const query of queries) {
    for (const doc of (await query.get()).docs) remove(doc.ref);
  }
  await writer.close();
  if (failures.length > 0) {
    throw new Error(`sharing data not erased (${failures.length} failed): ${String(failures[0])}`);
  }
}
