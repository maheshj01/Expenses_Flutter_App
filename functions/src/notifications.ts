import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {BillData, ConnectionData, Notice, billNotices, connectionNotice, isDeadDevice} from "./notices";

/**
 * Push notifications for sharing:
 *
 * - someone asks to connect with you, or accepts your request
 * - someone adds you to a split bill (when it's created, or by an edit)
 *
 * The app keeps one document per device that wants them at
 * users/{uid}/devices/{deviceId} = {fid, platform, updatedAt}, where fid
 * is the app's Firebase Installation ID that FCM delivers to. Turning
 * notifications off or signing out deletes it, and deleting the account
 * removes the whole users/{uid} tree. Devices FCM no longer knows are
 * forgotten here.
 *
 * The in-app inbox shows the same news, so a notice that can't be sent
 * (no devices, a stale one) loses nothing.
 */

export const notifyConnection = onDocumentWritten("connections/{id}", async (event) => {
  const before = event.data?.before.data() as ConnectionData | undefined;
  const after = event.data?.after.data() as ConnectionData | undefined;
  const notice = connectionNotice(event.params.id, before, after);
  if (notice) await send([notice]);
});

export const notifyBill = onDocumentWritten("bills/{id}", async (event) => {
  const before = event.data?.before.data() as BillData | undefined;
  const after = event.data?.after.data() as BillData | undefined;
  const payer = typeof after?.createdBy === "string" ? after.createdBy : "";
  if (!after || !payer) return;
  const connected = await connectionsOf(payer);
  await send(billNotices(event.params.id, before, after, (uid) => connected.has(uid)));
});

/**
 * Everyone with an accepted connection to [uid]. Blocking removes the
 * connection, so blocked people are never in it.
 * @param {string} uid The person.
 * @return {Promise<Set<string>>} Their connections' uids.
 */
async function connectionsOf(uid: string): Promise<Set<string>> {
  // Filtered here rather than in the query, which would need a composite
  // index; a person has few connections.
  const snap = await getFirestore().collection("connections")
      .where("members", "array-contains", uid)
      .get();
  const people = new Set<string>();
  for (const doc of snap.docs) {
    if (doc.get("status") !== "accepted") continue;
    for (const m of (doc.get("members") as string[] | undefined) ?? []) {
      if (m !== uid) people.add(m);
    }
  }
  return people;
}

/**
 * Sends each notice to every device of its person, skipping accounts that
 * are waiting to be deleted, and forgets devices FCM no longer knows.
 * @param {Notice[]} notices What to send.
 */
async function send(notices: Notice[]): Promise<void> {
  const db = getFirestore();
  for (const notice of notices) {
    const user = db.collection("users").doc(notice.to);
    const [account, devices] = await Promise.all([user.get(), user.collection("devices").get()]);
    if (account.get("deletion") != null) continue;
    const targets = devices.docs
        .map((d) => ({ref: d.ref, fid: d.get("fid") as unknown}))
        .filter((d): d is {ref: typeof d.ref; fid: string} => typeof d.fid === "string" && d.fid !== "");
    if (targets.length === 0) continue;

    const result = await getMessaging().sendEachForMulticast({
      fids: targets.map((t) => t.fid),
      notification: {title: notice.title, body: notice.body},
      data: notice.data,
      apns: {payload: {aps: {sound: "default"}}},
      android: {priority: "high", notification: {sound: "default"}},
    });
    const dead = result.responses
        .map((r, i) => (!r.success && isDeadDevice(r.error?.code) ? targets[i].ref : null))
        .filter((ref) => ref !== null);
    await Promise.all(dead.map((ref) => ref.delete()));
    logger.info("notified", {
      topic: notice.data.topic, sent: result.successCount, failed: result.failureCount, forgotten: dead.length,
    });
  }
}
