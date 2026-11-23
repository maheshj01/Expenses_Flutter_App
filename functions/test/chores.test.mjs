import assert from "node:assert/strict";
import {test} from "node:test";
import {runChores} from "../lib/chores.js";

test("every chore runs in order and reports what it removed", async () => {
  const order = [];
  const results = await runChores([
    {name: "a", run: async () => (order.push("a"), 2)},
    {name: "b", run: async () => (order.push("b"), 0)},
  ]);
  assert.deepEqual(order, ["a", "b"]);
  assert.deepEqual(results, [{name: "a", done: 2}, {name: "b", done: 0}]);
});

test("a failing chore is recorded and the rest still run", async () => {
  let ranAfter = false;
  const results = await runChores([
    {name: "accounts", run: async () => {
      throw new Error("quota");
    }},
    {name: "records", run: async () => {
      ranAfter = true;
      return 5;
    }},
  ]);
  assert.equal(ranAfter, true);
  assert.equal(results[0].name, "accounts");
  assert.match(results[0].error, /quota/);
  assert.deepEqual(results[1], {name: "records", done: 5});
});
