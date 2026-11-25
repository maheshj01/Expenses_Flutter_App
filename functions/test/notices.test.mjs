import assert from "node:assert/strict";
import {test} from "node:test";
import {billNotices, connectionNotice, displayName, isDeadDevice, money} from "../lib/notices.js";

const people = {a: {handle: "maya", name: "Maya Patel"}, b: {handle: "sam", name: ""}};
const request = {members: ["a", "b"], requestedBy: "a", status: "pending", people};

test("a new request notifies the person asked", () => {
  const n = connectionNotice("a_b", undefined, request);
  assert.equal(n.to, "b");
  assert.equal(n.title, "New request");
  assert.equal(n.body, "Maya Patel wants to split bills with you on Three Bucks.");
  assert.deepEqual(n.data, {topic: "request", id: "a_b"});
});

test("accepting notifies the person who asked, by the accepter's name", () => {
  const n = connectionNotice("a_b", request, {...request, status: "accepted"});
  assert.equal(n.to, "a");
  assert.equal(n.body, "@sam accepted your request. You can split bills now.");
  assert.equal(n.data.topic, "accepted");
});

test("removals, declines, re-saves and odd documents notify no one", () => {
  assert.equal(connectionNotice("a_b", request, undefined), null);
  assert.equal(connectionNotice("a_b", request, request), null);
  const accepted = {...request, status: "accepted"};
  assert.equal(connectionNotice("a_b", accepted, accepted), null);
  assert.equal(connectionNotice("a_b", undefined, accepted), null, "created already accepted");
  assert.equal(connectionNotice("x", undefined, {members: ["a"], requestedBy: "a", status: "pending"}), null);
  assert.equal(connectionNotice("x", undefined, {members: ["a", "b"], requestedBy: "c", status: "pending"}), null);
});

const bill = {
  createdBy: "a", members: ["a", "b", "c"], guests: 1, people,
  amountCents: 10000, currencyCode: "USD", note: "Dinner", deleted: false,
};
const all = () => true;

test("a new bill notifies every connected member but the payer, with their share", () => {
  const ns = billNotices("bill1", undefined, bill, all);
  assert.deepEqual(ns.map((n) => n.to), ["b", "c"]);
  assert.equal(ns[0].title, "New split bill");
  assert.equal(ns[0].body, "Maya Patel added you to “Dinner”. Your share is $25.00.");
  assert.deepEqual(ns[0].data, {topic: "newBill", id: "bill1"});
});

test("only people connected with the payer hear about a bill", () => {
  assert.deepEqual(billNotices("bill1", undefined, bill, (u) => u === "c").map((n) => n.to), ["c"]);
});

test("an edit notifies only the people it added", () => {
  const before = {...bill, members: ["a", "b"]};
  assert.deepEqual(billNotices("bill1", before, bill, all).map((n) => n.to), ["c"]);
  assert.deepEqual(billNotices("bill1", bill, {...bill, amountCents: 9000}, all), []);
  assert.deepEqual(billNotices("bill1", bill, {...bill, members: ["a", "b"]}, all), [], "removed");
});

test("deleted bills notify no one; restoring one notifies everyone again", () => {
  assert.deepEqual(billNotices("bill1", bill, {...bill, deleted: true}, all), []);
  assert.deepEqual(billNotices("bill1", undefined, {...bill, deleted: true}, all), []);
  assert.equal(billNotices("bill1", {...bill, deleted: true}, bill, all).length, 2);
});

test("a bill without a note says how much it is", () => {
  const [n] = billNotices("bill1", undefined, {...bill, note: "  ", members: ["a", "b"], guests: 0}, all);
  assert.equal(n.body, "Maya Patel added you to a $100.00 bill. Your share is $50.00.");
});

test("names fall back to the handle, then Someone; money follows the currency", () => {
  assert.equal(displayName(people, "b"), "@sam");
  assert.equal(displayName(people, "z"), "Someone");
  assert.equal(displayName(undefined, "a"), "Someone");
  assert.equal(money(2550, "EUR"), "€25.50");
  assert.equal(money(2550, "NOPE"), "25.50 NOPE");
});

test("only devices FCM no longer knows are forgotten", () => {
  assert.equal(isDeadDevice("messaging/installation-id-not-registered"), true);
  assert.equal(isDeadDevice("messaging/registration-token-not-registered"), true);
  assert.equal(isDeadDevice("messaging/invalid-registration-token"), true);
  assert.equal(isDeadDevice("messaging/internal-error"), false);
  assert.equal(isDeadDevice(undefined), false);
});
