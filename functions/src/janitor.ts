import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {purgeDeletedAccounts} from "./accountDeletion";
import {runChores} from "./chores";
import {markInactiveAccounts} from "./inactiveAccounts";
import {purgeDeletedRecords} from "./recordPurge";

/**
 * Every nightly clean-up in one scheduled function: one Cloud Scheduler job,
 * one cold start, one log line to read. Chores run in order and on their
 * own, so one failing never stops the others; the run is reported as failed
 * only after all of them have had their turn.
 *
 * Add a new nightly chore here rather than as its own scheduled function.
 */
export const janitor = onSchedule(
    {schedule: "every day 03:00", timeZone: "UTC", timeoutSeconds: 540},
    async () => {
      const results = await runChores([
        // Accounts first: erasing one takes its records with it. Inactive
        // linked ones are only marked, so they get 30 days like anyone else.
        {name: "inactiveAccounts", run: markInactiveAccounts},
        {name: "deletedAccounts", run: purgeDeletedAccounts},
        {name: "deletedRecords", run: purgeDeletedRecords},
      ]);
      logger.info("janitor finished", {results});
      const failed = results.filter((r) => r.error);
      if (failed.length > 0) {
        throw new Error(`janitor: ${failed.map((r) => `${r.name}: ${r.error}`).join("; ")}`);
      }
    },
);
