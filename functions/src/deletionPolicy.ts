/**
 * The rules for deleting an account, kept free of Firebase so they can be
 * tested directly. See accountDeletion.ts for where they are applied.
 */

/** Days a linked account can be restored after asking for deletion. */
export const GRACE_DAYS = 30;

/**
 * What a deletion request does:
 *  - "erase": an anonymous account has no identity to come back with, so a
 *    grace period would only keep data nobody can reach. Delete it now.
 *  - "schedule": a linked account is marked, restorable for GRACE_DAYS.
 *    Being undoable is what makes a fresh sign-in unnecessary here.
 */
export type DeletionDecision = "erase" | "schedule";

/**
 * Decides what a deletion request from this sign-in should do.
 * @param {boolean} isAnonymous The account has no linked identity. Read
 *   from the Auth user record, not the token: a token issued before linking
 *   still names "anonymous" as its sign-in provider.
 * @return {DeletionDecision} What to do with the request.
 */
export function decideDeletion(isAnonymous: boolean): DeletionDecision {
  return isAnonymous ? "erase" : "schedule";
}

/**
 * When a request is purged for good.
 * @param {Date} requestedAt When deletion was asked for.
 * @return {Date} The end of the grace period.
 */
export function purgeAfter(requestedAt: Date): Date {
  return new Date(requestedAt.getTime() + GRACE_DAYS * 24 * 60 * 60 * 1000);
}
