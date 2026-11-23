import assert from "node:assert/strict";
import {test} from "node:test";
import {RECORD_COLLECTIONS, RECORD_RETENTION_DAYS, purgeBefore} from "../lib/recordRetention.js";

test("deleted records are kept for 90 days before the purge", () => {
  assert.equal(RECORD_RETENTION_DAYS, 90);
  const now = new Date("2026-10-04T12:00:00Z");
  assert.equal(new Date(purgeBefore(now)).toISOString(), "2026-07-06T12:00:00.000Z");
});

test("every synced collection with tombstones is purged", () => {
  assert.deepEqual([...RECORD_COLLECTIONS], ["entries", "categories", "entry_edits"]);
});
