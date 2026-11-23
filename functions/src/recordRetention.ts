/**
 * How long a deleted record's tombstone is kept, kept free of Firebase so
 * it can be tested directly. See recordPurge.ts for where it is applied.
 *
 * Three Bucks has no "Recently deleted" screen, so nothing here is about
 * undoing. A tombstone exists only so a delete reaches every phone backed
 * up to the account: each one pulls it on its next sync and drops its own
 * copy. 90 days (three times Epoch's 30) leaves room for a phone that sits
 * in a drawer for a while; one offline for longer than this never hears of
 * the delete and keeps a ghost copy of the record.
 */
export const RECORD_RETENTION_DAYS = 90;

/** The synced collections with tombstones: users/{uid}/{collection}/{id}. */
export const RECORD_COLLECTIONS = ["entries", "categories", "entry_edits"] as const;

/**
 * Tombstones stamped before this moment are purged. The app stores
 * updatedAt as milliseconds since the epoch, and a deleted record's
 * updatedAt is when it was deleted (see lib/data/remote/firebase/
 * firebase_remote_store.dart).
 * @param {Date} now The current time.
 * @return {number} The cutoff, in milliseconds since the epoch.
 */
export function purgeBefore(now: Date): number {
  return now.getTime() - RECORD_RETENTION_DAYS * 24 * 60 * 60 * 1000;
}
