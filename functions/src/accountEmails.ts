/**
 * The emails sent when an account is paused for deletion or brought back,
 * kept free of Firebase so they can be previewed and tested directly.
 *
 * They speak in dots like the app's deletion screens: one dot per day of
 * grace, today in green, the last day an empty ring. Colours are the app's
 * light theme (lib/app/theme.dart). Inline styles and tables only, since
 * that is all email clients agree on; the system sans throughout.
 */

export type DeletionReason = "requested" | "inactive";

export interface Email {
  subject: string;
  text: string;
  html: string;
}

const INK = "#15171A";
const MUTED = "#73777C";
const GREEN = "#1D7A52";
const SURFACE = "#FAF9F6";
const CARD = "#FFFFFF";
const HAIRLINE = "#E6E2DA";
const FONT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
/** Three Bucks' page, with links to the stores. */
const APP_URL = "https://www.widgetmedialabs.com/three-bucks";

const DAY = 24 * 60 * 60 * 1000;

/**
 * Whether we can write to this address. Apple's "Hide My Email" relay
 * drops mail from senders not registered with Apple, so it is skipped
 * until one is.
 * @param {string | undefined} email The account's email.
 * @return {boolean} True when an email would arrive.
 */
export function canEmail(email: string | undefined): email is string {
  return !!email && !email.toLowerCase().endsWith("@privaterelay.appleid.com");
}

/**
 * "4 November 2026", in UTC so the date matches the purge.
 * @param {Date} date The day to name.
 * @return {string} The date in words.
 */
function longDate(date: Date): string {
  return date.toLocaleDateString("en-GB", {day: "numeric", month: "long", year: "numeric", timeZone: "UTC"});
}

/**
 * Escapes text placed in HTML.
 * @param {string} s Raw text.
 * @return {string} Safe HTML.
 */
function esc(s: string): string {
  return s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

type Dot = "today" | "ahead" | "last" | "kept";

/**
 * A row of dots, wrapped in rows of ten.
 * @param {Dot[]} dots What each dot is.
 * @return {string} The dots as an HTML table.
 */
function dotRows(dots: Dot[]): string {
  const style: Record<Dot, string> = {
    today: `background:${GREEN};border:2px solid ${GREEN};`,
    ahead: `background:${HAIRLINE};border:2px solid ${HAIRLINE};`,
    last: `background:transparent;border:2px solid ${GREEN};`,
    kept: `background:${INK};border:2px solid ${INK};`,
  };
  const rows: string[] = [];
  for (let i = 0; i < dots.length; i += 10) {
    const cells = dots.slice(i, i + 10).map((d) =>
      `<td style="padding:5px;"><div style="width:10px;height:10px;border-radius:50%;${style[d]}"></div></td>`,
    );
    rows.push(`<tr>${cells.join("")}</tr>`);
  }
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">${rows.join("")}</table>`;
}

/**
 * The wordmark: three small green bars of rising height, then the name.
 * @return {string} The wordmark as inline HTML.
 */
function wordmark(): string {
  const bar = (height: number, gap: number) =>
    `<span style="display:inline-block;width:4px;height:${height}px;background:${GREEN};` +
    `border-radius:1px;margin-right:${gap}px;vertical-align:baseline;"></span>`;
  return `${bar(7, 2)}${bar(11, 2)}${bar(15, 8)}Three Bucks`;
}

/**
 * The shared frame: warm off-white page, one white card, a quiet footer.
 * @param {object} p The parts of the message.
 * @return {string} The full HTML document.
 */
function frame(p: {preheader: string; title: string; body: string[]; dots: string; caption: string;
  button: string; to: string}): string {
  const paragraphs = p.body.map((t) =>
    `<p style="margin:0 0 14px;font-size:15px;line-height:1.6;color:${INK};">${t}</p>`).join("");
  return `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light only"><title>${esc(p.title)}</title></head>
<body style="margin:0;padding:0;background:${SURFACE};font-family:${FONT};">
<div style="display:none;max-height:0;overflow:hidden;">${esc(p.preheader)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${SURFACE};">
<tr><td align="center" style="padding:40px 16px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;">
  <tr><td style="padding:0 8px 20px;font-size:18px;font-weight:600;letter-spacing:-0.3px;color:${INK};">
    ${wordmark()}
  </td></tr>
  <tr><td style="background:${CARD};border:1.5px solid ${HAIRLINE};border-radius:20px;padding:32px 28px;">
    <h1 style="margin:0 0 16px;font-size:24px;font-weight:600;letter-spacing:-0.5px;line-height:1.25;color:${INK};">${esc(p.title)}</h1>
    ${paragraphs}
    <div style="padding:18px 0 6px;">${p.dots}</div>
    <p style="margin:0 0 24px;text-align:center;font-size:12.5px;color:${MUTED};">${p.caption}</p>
    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;"><tr>
      <td style="background:${INK};border-radius:999px;">
        <a href="${APP_URL}" style="display:inline-block;padding:12px 26px;font-size:14.5px;font-weight:600;color:${CARD};text-decoration:none;">${p.button}</a>
      </td></tr></table>
  </td></tr>
  <tr><td style="padding:20px 8px 0;font-size:12px;line-height:1.6;color:${MUTED};text-align:center;">
    Sent to ${esc(p.to)} about your Three Bucks account.<br>Widget Media Labs
  </td></tr>
  </table>
</td></tr></table>
</body></html>`;
}

/**
 * The email for an account just marked for deletion.
 * @param {object} p Who it's for, when the account goes, and why.
 * @return {Email} The message.
 */
export function pausedEmail(p: {to: string; purgeAfter: Date; reason: DeletionReason; now?: Date}): Email {
  const now = p.now ?? new Date();
  const daysLeft = Math.max(1, Math.ceil((p.purgeAfter.getTime() - now.getTime()) / DAY));
  const date = longDate(p.purgeAfter);
  const dots: Dot[] = Array.from({length: daysLeft}, (_, i) =>
    i === 0 ? "today" : i === daysLeft - 1 ? "last" : "ahead");

  const inactive = p.reason === "inactive";
  const title = inactive ? "We've missed you" : "Your account is paused";
  const body = inactive ?
    [
      "Three Bucks hasn't been opened in two years, so we've set your account to be deleted.",
      `Open Three Bucks before <strong>${date}</strong> and your entries, categories and backup all stay, ` +
        "just as you left them. Nothing else to do.",
    ] :
    [
      `Your account will be deleted on <strong>${date}</strong>, with your entries, categories and backup. ` +
        "Until then nothing is lost, only paused.",
      "Changed your mind? Sign in to Three Bucks with this account before then to bring everything back.",
    ];
  const caption = `${daysLeft} days. The ring is ${date}.`;
  const text = [
    title, "",
    ...body.map((t) => t.replace(/<\/?strong>/g, "")), "",
    APP_URL,
  ].join("\n");

  return {
    subject: inactive ? "Your Three Bucks account will be deleted soon" : "Your Three Bucks account is paused",
    text,
    html: frame({
      preheader: `Your account will be deleted on ${date}.`,
      title, body, dots: dotRows(dots), caption,
      button: inactive ? "Keep my account" : "Bring it back",
      to: p.to,
    }),
  };
}

/**
 * The email for an account brought back from a pending deletion.
 * @param {object} p Who it's for.
 * @return {Email} The message.
 */
export function restoredEmail(p: {to: string}): Email {
  const title = "Welcome back";
  const body = [
    "Your account is no longer set to be deleted.",
    "Every entry, every category and your backup are where you left them.",
  ];
  const dots: Dot[] = Array.from({length: 30}, (_, i) => i === 29 ? "today" : "kept");
  return {
    subject: "Your Three Bucks account is back",
    text: [title, "", ...body, "", APP_URL].join("\n"),
    html: frame({
      preheader: "Your account is no longer set to be deleted.",
      title, body, dots: dotRows(dots), caption: "Nothing missing. On we go.",
      button: "Open Three Bucks",
      to: p.to,
    }),
  };
}
