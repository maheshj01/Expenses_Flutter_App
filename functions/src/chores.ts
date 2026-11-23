/**
 * Runs the janitor's chores one after another, kept free of Firebase so it
 * can be tested directly. A chore that throws is recorded and the rest still
 * run: one failure must never leave the other clean-ups undone.
 */
export interface Chore {
  name: string;
  run: () => Promise<number>;
}

export interface ChoreResult {
  name: string;
  /** How many items the chore removed, when it finished. */
  done?: number;
  /** Why it stopped, when it failed. */
  error?: string;
}

/**
 * Runs every chore in order, whatever happens to the ones before it.
 * @param {Chore[]} chores The chores, in the order to run them.
 * @return {Promise<ChoreResult[]>} One result per chore, in the same order.
 */
export async function runChores(chores: Chore[]): Promise<ChoreResult[]> {
  const results: ChoreResult[] = [];
  for (const chore of chores) {
    try {
      results.push({name: chore.name, done: await chore.run()});
    } catch (error) {
      results.push({name: chore.name, error: String(error)});
    }
  }
  return results;
}
