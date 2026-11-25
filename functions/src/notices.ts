/**
 * What to tell whom when sharing changes: a connection request arrives, a
 * request is accepted, someone adds you to a split bill, or the payer
 * edits a bill you're on. Kept free of
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
   * `topic` is "request", "accepted", "newBill" or "billUpdated"; `id` is
   * the connection or bill id.
   */
  data: {topic: "request" | "accepted" | "newBill" | "billUpdated"; id: string};
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
  memo?: unknown;
  day?: unknown;
  categoryId?: unknown;
  guestNames?: unknown;
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
 * The parts of a bill an edit can change, each with how a notice names it.
 * Flags aren't edits (each person flags their own share), and deleting has
 * its own path, so neither is here.
 */
const editable: Array<[keyof BillData, string]> = [
  ["amountCents", "amount"],
  ["note", "title"],
  ["day", "date"],
  ["categoryId", "category"],
  ["members", "people"],
  ["guests", "people"],
  ["guestNames", "people"],
  ["memo", "message"],
  ["currencyCode", "currency"],
];

const same = (a: unknown, b: unknown, key: keyof BillData): boolean => {
  if (key === "members") return [...strings(a)].sort().join("\n") === [...strings(b)].sort().join("\n");
  if (key === "guestNames") return strings(a).join("\n") === strings(b).join("\n");
  if (key === "note" || key === "memo") {
    return (typeof a === "string" ? a.trim() : "") === (typeof b === "string" ? b.trim() : "");
  }
  return a === b;
};

/**
 * What an edit changed, by name ("amount", "title", "people", …), in a
 * fixed order and without repeats. Empty when nothing a person would call
 * an edit changed.
 * @param {BillData} before The bill before.
 * @param {BillData} after The bill after.
 * @return {string[]} The names of what changed.
 */
export function billChanges(before: BillData, after: BillData): string[] {
  const names: string[] = [];
  for (const [key, name] of editable) {
    if (!same(before[key], after[key], key) && !names.includes(name)) names.push(name);
  }
  return names;
}

/**
 * Whether a write to a bill is the payer editing it: the bill existed
 * before, isn't deleted on either side, and something people see changed.
 * Creating, deleting, restoring and flagging aren't edits.
 * @param {BillData | undefined} before The bill before (undefined when created).
 * @param {BillData | undefined} after The bill after (undefined when deleted).
 * @return {boolean} True for an edit.
 */
export function isBillEdit(before: BillData | undefined, after: BillData | undefined): boolean {
  if (!before || !after || before.deleted === true || after.deleted === true) return false;
  return billChanges(before, after).length > 0;
}

/** How long after an edit its notice goes out, so a burst of edits sends one. */
export const updateDelaySeconds = 5 * 60;

/**
 * "amount", "amount and title", "amount, title and date".
 * @param {string[]} items What to list.
 * @return {string} The list in words.
 */
function inWords(items: string[]): string {
  if (items.length <= 1) return items.join("");
  return `${items.slice(0, -1).join(", ")} and ${items[items.length - 1]}`;
}

/**
 * Notices for an edited bill, sent a while after the first edit: [before]
 * is the bill as it was then and [after] is the bill now, so several edits
 * become one notice, and edits that undo each other send none. Everyone who
 * was on the bill then and still is hears about it, except the payer (who
 * made the edits) and anyone not connected with them. People added in the
 * meantime already got "New split bill".
 * @param {string} id The bill id.
 * @param {BillData} before The bill before the first edit.
 * @param {BillData | undefined} after The bill now (undefined when deleted).
 * @param {(uid: string) => boolean} connected Whether uid is connected with the payer.
 * @return {Notice[]} One per person to tell.
 */
export function billUpdateNotices(
    id: string,
    before: BillData,
    after: BillData | undefined,
    connected: (uid: string) => boolean,
): Notice[] {
  if (!after || after.deleted === true) return [];
  const payer = typeof after.createdBy === "string" ? after.createdBy : "";
  if (!payer) return [];
  const changes = billChanges(before, after);
  if (changes.length === 0) return [];
  const was = new Set(strings(before.members));
  const to = strings(after.members).filter((m) => m !== payer && was.has(m) && connected(m));
  if (to.length === 0) return [];

  const amount = typeof after.amountCents === "number" ? after.amountCents : 0;
  const currency = typeof after.currencyCode === "string" ? after.currencyCode : "USD";
  const ways = strings(after.members).length + (typeof after.guests === "number" ? after.guests : 0);
  const share = money(Math.round(amount / Math.max(1, ways)), currency);
  const note = typeof after.note === "string" ? after.note.trim() : "";
  const what = note ? `“${note}”` : `a ${money(amount, currency)} bill`;
  const who = displayName(after.people, payer);
  const shareChanged = changes.some((c) => c === "amount" || c === "people" || c === "currency");
  const body = `${who} changed the ${inWords(changes)} of ${what}.` +
    (shareChanged ? ` Your share is now ${share}.` : "");
  return to.map((uid) => ({
    to: uid,
    title: "Bill updated",
    body,
    data: {topic: "billUpdated", id},
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
