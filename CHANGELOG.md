# Changelog

All notable changes to Three Bucks are listed here, newest first, written for the people who use
the app. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions
match `version:` in `pubspec.yaml`.

New changes go under **Unreleased**. When a version ships, that section becomes the version's
heading with its release date, and a new empty Unreleased section starts above it.

## [Unreleased]

Three Bucks 0.1.0, the first release of the app rebuilt from scratch in November 2026.

### Added

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
- **Safety.** Block and report people. Strangers can't add bills to your spending.
- **Sign in with Apple or Google**, only needed to split bills with people.
- **Account deletion.** Delete your account and all its data. You have 30 days to change
  your mind before it's erased for good.
- **Import and export.** Bring in .xlsx or .csv spreadsheets (and undo an import), and export any
  year, or everything, as .xlsx.
- **Works offline.** Everything is saved on the phone first and backed up when you're online.
- **First-run setup** for your income, budget and goals.
- Branded launch screen on iOS and Android, and animations throughout the app.

### Fixed

- Sync problems are explained in plain words, such as "Backup isn't set up for this app yet.",
  instead of a raw error code.
- The year screen says "Average spent / month".
- A report is sent only once, however many times you tap.

## Before 0.1.0

From 2019 to 2022, this repository held an earlier, simpler expense app (Expenses Flutter App):
a list of expenses stored with sqflite, with date filters, themes and a currency setting.
Three Bucks replaced it entirely.
