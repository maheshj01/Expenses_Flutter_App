# TODO

Things left open, roughly in the order they matter.

## Before release

- [x] **Delete account should erase the backup.** Works like Epoch: server-side, frozen for
      30 days, then purged by the nightly `janitor` (`functions/`).
- [ ] **Deploy the functions** (Blaze plan): `firebase functions:secrets:set RESEND_API_KEY`,
      then `firebase deploy --only firestore:rules,firestore:indexes,functions`. Check the
      janitor's first runs in `firebase functions:log`.
- [ ] Register `support@widgetmedialabs.com` with Apple's private email relay, so deletion
      emails reach people who hid their email with Sign in with Apple (skipped until then).
- [ ] Add App Check, then turn on `enforceAppCheck` for the two deletion callables.
- [ ] Privacy policy (`wmlabs/src/routes/three-bucks/privacy/ThreeBucksPrivacy.tsx`): drop
      the "email us" deletion line; say accounts are deleted 30 days after the request and
      after two years unopened; mention Resend emails, reports, blocks and edit history.
- [x] Fill in the support email and privacy policy URL in `lib/app/support.dart`.
- [ ] Check reports (Firestore → `reports`) daily once live.
- [ ] Multiple device login should keep data consistent across devices. Or We should allow Single Sign In?
- [ ] **Delete-account web page** at `/three-bucks/delete-account` on the wmlabs site, like
      Epoch's. Google Play requires one outside the app.
- [x] **Backups from abandoned installs.** The janitor erases anonymous accounts unopened for
      two years, and marks signed-in ones for deletion (with a warning email).
- [ ] **Notifications:** create an APNs key and upload it to Firebase (Cloud Messaging), deploy
      the functions, then test on two real phones (simulators can't be trusted for pushes).
- [ ] **Firebase console setup for sharing**
  - [ ] Authentication → enable Apple and Google sign-in
  - [ ] Xcode → Runner → Signing & Capabilities → add Sign in with Apple (paid team)
  - [ ] Android: add SHA-1 and SHA-256 fingerprints, re-download `google-services.json`
  - [x] `firebase deploy --only firestore:rules`
- [ ] **Test real sync and sharing** on two devices against Firebase (only tested with the
      in-memory backends so far).
- [ ] **Check the Android icon** (adaptive and themed) on a device or emulator.

## Store listings

- [ ] App Store and Play listings: privacy policy URL `/three-bucks/privacy`, Play Data safety form.
- [ ] Once published, add the store links to `wmlabs/src/routes/three-bucks/stores.ts`; the
      page switches from "Coming soon" to store buttons.
- [ ] Android screenshots for the product page (it only has iPhone ones; Epoch has a
      platform switch).
- [ ] Commit the wmlabs changes on a branch (they're uncommitted on `main`).

## Sharing, later

- [ ] Enforce "only split with connections" in `firestore.rules` too (today only the app
      ignores bills from strangers, in the ledger and in balances).
- [ ] Groups (a saved set of people)
- [ ] Uneven splits (exact amounts, percentages, shares)
- [ ] Comments on a bill, if flag notes turn out not to be enough
- [ ] Universal links (`https://…`) for invites, so they're tappable in every messaging app
- [x] Push notifications for requests (new and accepted) and new bills
- [ ] Push notifications for flags, bill edits and settlements

## App, later

- [ ] Currency app icons (€, £, ₹, ¥, ₩) as alternate icons, picked from the setup currency,
      plus an App icon picker in Settings
- [ ] iOS dark and tinted icon variants
- [ ] Import past years from the Excel sheet
- [ ] Bank sync (Plaid / SimpleFIN) feeding a "to review" inbox
- [ ] Subscriptions view and price history from notes
