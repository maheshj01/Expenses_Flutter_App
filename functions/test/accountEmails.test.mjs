import assert from "node:assert/strict";
import {test} from "node:test";
import {canEmail, deletionChange, pausedEmail, restoredEmail} from "../lib/accountEmails.js";

const marker = {purgeAfter: "x"};

test("a new mark pauses, a cleared one restores, a purge says nothing", () => {
  assert.equal(deletionChange(undefined, marker, true), "paused");
  assert.equal(deletionChange(marker, undefined, true), "restored");
  assert.equal(deletionChange(marker, undefined, false), null);
  assert.equal(deletionChange(marker, marker, true), null);
  assert.equal(deletionChange(undefined, undefined, true), null);
});

test("Apple's hidden relay addresses and missing emails are skipped", () => {
  assert.equal(canEmail("a@example.com"), true);
  assert.equal(canEmail("abc@PrivateRelay.AppleID.com"), false);
  assert.equal(canEmail(undefined), false);
});

test("the paused email names the date and shows one dot per day left", () => {
  const now = new Date("2026-10-04T12:00:00Z");
  const purgeAfter = new Date("2026-11-03T12:00:00Z");
  const mail = pausedEmail({to: "a@example.com", purgeAfter, reason: "requested", now});
  assert.equal(mail.subject, "Your Three Bucks account is paused");
  assert.match(mail.text, /3 November 2026/);
  assert.match(mail.text, /entries, categories and backup/);
  assert.equal(mail.html.match(/border-radius:50%;background:/g).length, 30);
});

test("the inactive email says why, and offers to keep it", () => {
  const mail = pausedEmail({
    to: "a@example.com", purgeAfter: new Date("2026-11-03T12:00:00Z"), reason: "inactive",
    now: new Date("2026-10-04T12:00:00Z"),
  });
  assert.match(mail.text, /hasn't been opened in two years/);
  assert.match(mail.html, /Keep my account/);
});

test("the emails are branded Three Bucks, in the app's green", () => {
  const mail = restoredEmail({to: "a@example.com"});
  assert.match(mail.html, /Three Bucks/);
  assert.match(mail.html, /#1D7A52/);
  assert.doesNotMatch(mail.html, /epoch|#EF5B25|Poppins/i);
  assert.match(mail.text, /https:\/\/www\.widgetmedialabs\.com\/three-bucks/);
});

test("the address is escaped in the footer", () => {
  assert.match(restoredEmail({to: "<b>@x.com"}).html, /&#60;b&#62;@x.com/);
});
