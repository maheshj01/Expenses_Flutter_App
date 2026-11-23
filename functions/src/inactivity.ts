/**
 * When an account counts as left behind, kept free of Firebase so it can be
 * tested directly. See inactiveAccounts.ts for where it is applied.
 */

/** Two years: long enough for someone who opens Three Bucks once a year. */
export const INACTIVE_DAYS = 730;

/** The parts of an Auth user's metadata that say when it was last used. */
export interface UsageMetadata {
  lastRefreshTime?: string | null;
  lastSignInTime?: string;
  creationTime?: string;
}

/**
 * When the account was last used. The app refreshes its sign-in token
 * about hourly while open and online, so the last refresh is the best
 * record of the last visit; older accounts may only have a sign-in time.
 * @param {UsageMetadata} m The Auth user's metadata.
 * @return {Date} The last sign of life.
 */
export function lastActive(m: UsageMetadata): Date {
  return new Date(m.lastRefreshTime ?? m.lastSignInTime ?? m.creationTime ?? 0);
}

/**
 * Whether an account last used at [last] has been left behind.
 * @param {Date} last When it was last used.
 * @param {Date} now The current time.
 * @return {boolean} True when it has been quiet for INACTIVE_DAYS or more.
 */
export function isInactive(last: Date, now: Date): boolean {
  return now.getTime() - last.getTime() >= INACTIVE_DAYS * 24 * 60 * 60 * 1000;
}

/**
 * Whether an account marked for being inactive came back after the mark,
 * so its purge should be called off. The app clears the mark itself when
 * opened; this covers the times that call never landed.
 * @param {Date} markedAt When the account was marked.
 * @param {Date} last When it was last used.
 * @return {boolean} True when it has been used since it was marked.
 */
export function cameBack(markedAt: Date, last: Date): boolean {
  return last.getTime() > markedAt.getTime();
}
