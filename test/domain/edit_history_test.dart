import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/core/day.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/data/local/drift_entry_edit_sync.dart';
import 'package:three_bucks/data/local/drift_entry_repository.dart';
import 'package:three_bucks/data/sync/local_sync_source.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';
import 'package:three_bucks/domain/history/edit.dart';
import 'package:three_bucks/domain/social/account.dart';

import '../social/social_domain_test.dart' show ana, bill, me, sam;
import '../support/fake_social.dart';

LedgerEntry entry({
  int cents = 4000,
  String category = 'food',
  String note = 'Costco',
  DateTime? date,
  int split = 1,
  String? billId,
}) => LedgerEntry(
  id: 'e1',
  amountCents: cents,
  categoryId: category,
  date: date ?? DateTime(2026, 11, 20),
  note: note,
  splitWays: split,
  billId: billId,
  createdAt: DateTime(2026, 11, 20, 9),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('changes', () {
    test('an entry edit lists only the fields that changed', () {
      final changes = entryChanges(
        entry(),
        entry(cents: 4600, category: 'groceries', date: DateTime(2026, 11, 21)),
      );
      expect(changes, {
        EditField.amount: const FieldChange(4000, 4600),
        EditField.category: const FieldChange('food', 'groceries'),
        EditField.date: const FieldChange(20261120, 20261121),
      });
      expect(entryChanges(entry(), entry(note: ' Costco ')), isEmpty, reason: 'whitespace');
    });

    test('a bill edit names the people added or removed, and ignores flags', () {
      final before = bill('b');
      final after = bill('b', members: [me, sam, ana], cents: 12000);
      final changes = billChanges(before, after);
      expect(changes[EditField.amount], const FieldChange(9000, 12000));
      expect(changes[EditField.people], const FieldChange(['ME', 'SAM'], ['ME', 'SAM', 'ANA']));
      expect(billChanges(before, bill('b', members: [sam, me])), isEmpty, reason: 'same people');
      expect(billChanges(before, before.copyWith(deleted: true)), {
        EditField.deleted: const FieldChange(false, true),
      });
    });

    test('survive a round trip through JSON', () {
      final changes = {
        EditField.amount: const FieldChange(1, 2),
        EditField.people: const FieldChange(['A'], ['A', 'B']),
      };
      expect(Edit.changesFromJson(Edit.changesToJson(changes)), changes);
      expect(Edit.changesFromJson({'unknown': {}}), isEmpty, reason: 'newer fields are skipped');
    });
  });

  group('entry history on the device', () {
    late AppDatabase db;
    late DriftEntryRepository entries;
    var now = DateTime(2026, 11, 20, 10);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      entries = DriftEntryRepository(db, LocalChanges(), clock: () => now);
    });

    tearDown(() => db.close());

    test('records each edit, not the first save', () async {
      await entries.save(entry());
      expect(await entries.watchEdits('e1').first, isEmpty);

      now = DateTime(2026, 11, 20, 11);
      await entries.save(entry(cents: 4600));
      await entries.save(entry(cents: 4600)); // no change, nothing recorded
      now = DateTime(2026, 11, 21, 8);
      await entries.save(entry(cents: 4600, split: 2));

      final edits = await entries.watchEdits('e1').first;
      expect(edits.map((e) => e.changes.keys.single), [EditField.split, EditField.amount]);
      expect(edits.last.at, DateTime(2026, 11, 20, 11));
      expect(edits.last.changes[EditField.amount], const FieldChange(4000, 4600));
    });

    test('leaves shares of bills to the bill’s own history', () async {
      await entries.save(entry(billId: 'b1'));
      await entries.save(entry(billId: 'b1', cents: 5000));
      expect(await entries.watchEdits('e1').first, isEmpty);
    });

    test('syncs to another device', () async {
      await entries.save(entry());
      await entries.save(entry(note: 'Costco run'));
      final sync = DriftEntryEditSync(db);
      final pending = await sync.pendingChanges();
      expect(pending.single.data['entryId'], 'e1');

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await DriftEntryEditSync(other).applyRemote(pending);
      final there = await DriftEntryRepository(other, LocalChanges()).watchEdits('e1').first;
      expect(there.single.changes, {EditField.note: const FieldChange('Costco', 'Costco run')});
      expect(DayKey.fromDate(there.single.at), DayKey.fromDate(now));

      await sync.markSynced(pending);
      expect(await sync.pendingChanges(), isEmpty);
    });
  });

  group('shared bill history', () {
    test('every member sees the payer’s edits, newest first', () async {
      final server = FakeSocialServer();
      addTearDown(server.dispose);
      final payer = FakeSocialBackend(
        server,
        signInAs: const Account(uid: me, method: SignInMethod.apple),
        signedIn: true,
      );
      final member = FakeSocialBackend(
        server,
        signInAs: const Account(uid: sam, method: SignInMethod.google),
        signedIn: true,
      );
      final b = bill('b');
      await payer.saveBill(b);
      await payer.saveBill(b.copyWith(amountCents: 9600, editedAt: DateTime(2026, 11, 11)));
      await payer.saveBill(b.copyWith(amountCents: 9600, note: 'Dinner'));

      final edits = await member.watchBillEdits('b').first;
      expect(edits.map((e) => e.changes.keys.toList()), [
        [EditField.note],
        [EditField.amount],
      ]);
      expect(edits.every((e) => e.by == me), isTrue);
      expect(
        await FakeSocialBackend(
          server,
          signInAs: const Account(uid: ana, method: SignInMethod.apple),
          signedIn: true,
        ).watchBillEdits('b').first,
        isEmpty,
        reason: 'not a member',
      );
    });
  });
}
