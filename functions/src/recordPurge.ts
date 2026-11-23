import {getFirestore} from "firebase-admin/firestore";
import {RECORD_COLLECTIONS, purgeBefore} from "./recordRetention";

/** Deletes per batch; Firestore caps a batch at 500 writes. */
const PAGE = 400;

/**
 * Removes deleted records (tombstones) older than the retention window from
 * every account's backup: users/{uid}/{entries,categories,entry_edits}/{id}
 * with deleted == true and updatedAt before the cutoff. Until then they
 * stay, so a deletion reaches every phone. One of the janitor's nightly
 * chores (see janitor.ts).
 *
 * Needs the collection-group indexes in firestore.indexes.json at the repo
 * root (each collection: deleted ASC, updatedAt ASC).
 * @return {Promise<number>} How many deleted records were purged.
 */
export async function purgeDeletedRecords(): Promise<number> {
  const cutoff = purgeBefore(new Date());
  let purged = 0;
  for (const collection of RECORD_COLLECTIONS) {
    purged += await purgeCollection(collection, cutoff);
  }
  return purged;
}

/**
 * Purges one collection group's tombstones, a page at a time.
 * @param {string} collection The collection group, e.g. "entries".
 * @param {number} cutoff Tombstones with updatedAt before this go.
 * @return {Promise<number>} How many were purged.
 */
async function purgeCollection(collection: string, cutoff: number): Promise<number> {
  const db = getFirestore();
  let purged = 0;
  for (;;) {
    const due = await db.collectionGroup(collection)
        .where("deleted", "==", true)
        .where("updatedAt", "<", cutoff)
        .limit(PAGE)
        .get();
    if (due.empty) break;
    const batch = db.batch();
    due.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    purged += due.size;
    if (due.size < PAGE) break;
  }
  return purged;
}
