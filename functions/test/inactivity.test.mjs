import assert from "node:assert/strict";
import {test} from "node:test";
import {INACTIVE_DAYS, cameBack, isInactive, lastActive} from "../lib/inactivity.js";

const DAY = 24 * 60 * 60 * 1000;
const now = new Date("2026-10-04T03:00:00Z");

test("an account is left behind after two years without a visit", () => {
  assert.equal(INACTIVE_DAYS, 730);
  assert.equal(isInactive(new Date(now.getTime() - 730 * DAY), now), true);
  assert.equal(isInactive(new Date(now.getTime() - 729 * DAY), now), false);
});

test("the last token refresh is the last visit, then sign-in, then creation", () => {
  const m = {
    lastRefreshTime: "2026-09-01T00:00:00Z",
    lastSignInTime: "2025-01-01T00:00:00Z",
    creationTime: "2024-01-01T00:00:00Z",
  };
  assert.equal(lastActive(m).toISOString(), "2026-09-01T00:00:00.000Z");
  assert.equal(lastActive({...m, lastRefreshTime: null}).toISOString(), "2025-01-01T00:00:00.000Z");
  assert.equal(lastActive({creationTime: m.creationTime}).toISOString(), "2024-01-01T00:00:00.000Z");
});

test("an inactive account used after it was marked came back", () => {
  const marked = new Date("2026-10-01T03:00:00Z");
  assert.equal(cameBack(marked, new Date("2026-10-02T00:00:00Z")), true);
  assert.equal(cameBack(marked, new Date("2024-01-01T00:00:00Z")), false);
  assert.equal(cameBack(marked, marked), false);
});
