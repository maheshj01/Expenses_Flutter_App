/**
 * What to tell whom when sharing changes: a connection request arrives, a
 * request is accepted, or someone adds you to a split bill. Kept free of
 * Firebase so it can be tested directly; notifications.ts sends them.
 *
 * The data shapes mirror what the app writes (see
 * lib/data/remote/firebase/firebase_social_backend.dart).
 */

/** One push notification for one person. */
export interface Notice {
  /** The uid to notify. */
  to: string;
  title: string;
  body: string;
  /**
   * Lets the app open the right place when the notice is tapped.
   * `topic` is "request", "accepted" or "newBill"; `id` is the connection
   * or bill id.
   */
  data: {topic: "request" | "accepted" | "newBill"; id: string};
}

interface PersonData {
  handle?: unknown;
  name?: unknown;
}

/** connections/{id}: "uidA_uidB", with uidA < uidB. */
export interface ConnectionData {
  members?: unknown;
  requestedBy?: unknown;
  status?: unknown;
  people?: unknown;
}

/** bills/{id}. */
export interface BillData {
  createdBy?: unknown;
  members?: unknown;
  people?: unknown;
  guests?: unknown;
  amountCents?: unknown;
  currencyCode?: unknown;
  note?: unknown;
  deleted?: unknown;
}

const strings = (v: unknown): string[] => Array.isArray(v) ? v.filter((s) => typeof s === "string") : [];

/**
 * How the app shows a person: their name, else @handle, else "Someone".
 * @param {unknown} people The document's people map.
 * @param {string} uid Whose name.
 * @return {string} The display name.
 */
export function displayName(people: unknown, uid: string): string {
  const person = (people && typeof people === "object" ? (people as Record<string, unknown>)[uid] : undefined) as
    PersonData | undefined;
  const name = typeof person?.name === "string" ? person.name.trim() : "";
  if (name) return name;
  const handle = typeof person?.handle === "string" ? person.handle : "";
  return handle ? `@${handle}` : "Someone";
}

/**
 * The notice for a change to a connection: the person asked hears about a
 * new request, and the person who asked hears when it's accepted. Nothing
 * for removals, declines or anything else.
 * @param {string} id The connection id.
 * @param {ConnectionData | undefined} before The document before (undefined when created).
 * @param {ConnectionData | undefined} after The document after (undefined when deleted).
 * @return {Notice | null} Who to tell, or null.
 */
export function connectionNotice(
    id: string, before: ConnectionData | undefined, after: ConnectionData | undefined,
): Notice | null {
  if (!after) return null;
  const members = strings(after.members);
  const requester = typeof after.requestedBy === "string" ? after.requestedBy : "";
  const asked = members.find((m) => m !== requester);
  if (members.length !== 2 || !requester || !asked || !members.includes(requester)) return null;

  if (!before && after.status === "pending") {
    const who = displayName(after.people, requester);
    return {
      to: asked,
      title: "New request",
      body: `${who} wants to split bills with you on Three Bucks.`,
      data: {topic: "request", id},
    };
  }
  if (before?.status === "pending" && after.status === "accepted") {
    const who = displayName(after.people, asked);
    return {
      to: requester,
      title: "Request accepted",
      body: `${who} accepted your request. You can split bills now.`,
      data: {topic: "accepted", id},
    };
  }
  return null;
}

/**
 * Money as the app shows it, e.g. "$25.00".
 * @param {number} cents The amount in cents.
 * @param {string} currency ISO currency code.
 * @return {string} The formatted amount.
 */
export function money(cents: number, currency: string): string {
  try {
    return new Intl.NumberFormat("en-US", {style: "currency", currency}).format(cents / 100);
  } catch {
    return `${(cents / 100).toFixed(2)} ${currency}`;
  }
}

/**
 * Notices for people newly added to a bill: everyone but the payer when
 * it's created, and anyone added by a later edit. Only people connected
 * with the payer hear about it, since the app ignores bills from anyone
 * else. Deleted bills notify no one.
 * @param {string} id The bill id.
 * @param {BillData | undefined} before The bill before (undefined when created).
 * @param {BillData | undefined} after The bill after (undefined when deleted).
 * @param {(uid: string) => boolean} connected Whether uid is connected with the payer.
 * @return {Notice[]} One per person to tell.
 */
export function billNotices(
    id: string,
    before: BillData | undefined,
    after: BillData | undefined,
    connected: (uid: string) => boolean,
): Notice[] {
  if (!after || after.deleted === true) return [];
  const payer = typeof after.createdBy === "string" ? after.createdBy : "";
  if (!payer) return [];
  // A bill restored from a soft delete is news again to everyone on it.
  const known = new Set(before && before.deleted !== true ? strings(before.members) : []);
  const added = strings(after.members).filter((m) => m !== payer && !known.has(m) && connected(m));
  if (added.length === 0) return [];

  const members = strings(after.members).length;
  const guests = typeof after.guests === "number" ? after.guests : 0;
  const amount = typeof after.amountCents === "number" ? after.amountCents : 0;
  const currency = typeof after.currencyCode === "string" ? after.currencyCode : "USD";
  const share = money(Math.round(amount / Math.max(1, members + guests)), currency);
  const note = typeof after.note === "string" ? after.note.trim() : "";
  const what = note ? `“${note}”` : `a ${money(amount, currency)} bill`;
  const who = displayName(after.people, payer);
  return added.map((to) => ({
    to,
    title: "New split bill",
    body: `${who} added you to ${what}. Your share is ${share}.`,
    data: {topic: "newBill", id},
  }));
}

/**
 * The FCM error codes that mean a device's address (its FID) will never
 * work again, so the device should be forgotten.
 * @param {string | undefined} code The error code from a failed send.
 * @return {boolean} True when the device is gone.
 */
export function isDeadDevice(code: string | undefined): boolean {
  return code === "messaging/installation-id-not-registered" ||
    code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token";
}
