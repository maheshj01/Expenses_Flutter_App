import assert from "node:assert/strict";
import {test} from "node:test";
import {GRACE_DAYS, decideDeletion, purgeAfter} from "../lib/deletionPolicy.js";

test("anonymous accounts are erased at once; linked ones are scheduled", () => {
  assert.equal(decideDeletion(true), "erase");
  assert.equal(decideDeletion(false), "schedule");
});

test("the purge date is the grace period after the request", () => {
  const now = new Date("2026-09-29T12:00:00Z");
  assert.equal(GRACE_DAYS, 30);
  assert.equal(purgeAfter(now).toISOString(), "2026-10-29T12:00:00.000Z");
});
