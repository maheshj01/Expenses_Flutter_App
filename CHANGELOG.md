### v0.1.0+4 Unreleased

**Changed**

- **Backup needs you to sign in.** Your entries back up only once you sign in with Apple or
  Google. Until then everything still works, just on this phone. Settings says "Not backed up"
  and offers to sign in, and signing in backs up everything you've tracked so far.
- **Signing out clears this phone.** Anything not yet backed up gets one last try first.
  Then the app starts fresh, and your data comes back when you sign in again. If some changes
  still haven't backed up, you're warned before signing out.
- **One email, one account.** If you made your account with Apple and later continue with
  Google using the same email (or the other way round), the app asks you to confirm with the
  first one once. After that, both open the same account.
- **Google sign-in uses the phone's own account picker** instead of a browser page.
- **Plainer wording.** Settings says "Backed up" instead of naming the service behind it, and
  sign-in problems explain what to do instead of showing technical error text.

**Fixed**

- Setting or removing the monthly budget no longer shows an error as the dialog closes.
- Backup no longer fails when the app opens after a sync that reached the end of your data.

### v0.1.0+3 Nov 25, 2026

- **Two-tap entry.** Type something like `costco 46 split` and the app fills in the amount, the
  category and the split. The amount uses the phone's own number pad.
- **Spent, Saved and Earned.** Every category is spending, saving or income, so putting money
  away never counts as spending. Includes a Savings starter category.
- **Monthly dashboard.** What you've spent against your budget, what's safe to spend today, and
  progress towards your goals.
- **Activity.** Every entry in a month, searchable (including amounts, like `> 100`) and
  filterable by Spending, Saving, Income, Split, Money back and Deleted.
- **History.** Each year's totals and a monthly chart. Tap a month to see its entries.
- **Edit history.** Every edit of an entry or shared bill is kept, with what changed.
- **Deleted items stay visible.** Deleted expenses, and shared bills their payer deleted, stay
  in Activity, faded and left out of the totals. You can restore your own with one tap.
- **Your own categories.** Add, edit, recolour, archive and restore them.
- **Split bills and money back.** Log the full bill and only your share counts. Name the people
  you split with, even if they aren't on the app.
- **Split with people on the app.** Add friends by username and split bills with them. Each
  person can flag a share they disagree with, see balances, and settle up. You settle up before
  removing a friend.
- **Notifications.** Get notified when someone sends you a request, accepts yours, or adds you
  to a split bill. Turn them on from People or Settings.
- **Bill update notifications.** When the payer edits a shared bill, everyone else on it hears
  what changed, e.g. "Sam changed the amount and title of “Team dinner”. Your share is now
  $30.00." It's sent 5 minutes after the first edit, so a quick run of edits sends one
  notification. Tapping it opens the bill, whose history shows each change.
- **Safety.** Block and report people. Strangers can't add bills to your spending.
- **Sign in with Apple or Google**, only needed to split bills with people.
- **Account deletion.** Delete your account and all its data. You have 30 days to change
  your mind before it's erased for good.
- **Import and export.** Bring in .xlsx or .csv spreadsheets (and undo an import), and export any
  year, or everything, as .xlsx.
- **Works offline.** Everything is saved on the phone first and backed up when you're online.
- **First-run setup** for your income, budget and goals.
- Branded launch screen on iOS and Android, and animations throughout the app.

**Fixed**

- Sync problems are explained in plain words, such as "Backup isn't set up for this app yet.",
  instead of a raw error code.
- The year screen says "Average spent / month".
- A report is sent only once, however many times you tap.

### v0.1.0 Nov 20, 2026

- Initial release.

## Before Initial release

From 2019 to 2022, this repository held an earlier, simpler expense app (Expenses Flutter App):
a list of expenses stored with sqflite, with date filters, themes and a currency setting.
Three Bucks replaced it entirely.
