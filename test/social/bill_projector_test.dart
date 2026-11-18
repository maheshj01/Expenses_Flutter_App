import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/data/local/app_database.dart';
import 'package:three_bucks/data/local/drift_entry_repository.dart';
import 'package:three_bucks/data/social/bill_projector.dart';
import 'package:three_bucks/data/sync/local_sync_source.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';
import 'package:three_bucks/domain/social/shared_bill.dart';

import 'social_domain_test.dart' show bill, flag, me, sam;

void main() {
  late AppDatabase db;
  late DriftEntryRepository entries;
  late BillProjector projector;
  final changes = LocalChanges();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    entries = DriftEntryRepository(db, changes);
    projector = BillProjector(entries);
  });

  tearDown(() => db.close());

  Future<void> apply(
    List<SharedBill> bills, {
    bool complete = true,
    Set<String> connected = const {sam},
  }) => projector.apply(
    me: me,
    snapshot: BillsSnapshot(bills, complete: complete),
    connected: connected,
    categoryIds: {'food', 'misc'},
  );

  Future<List<LedgerEntry>> ledger() => entries.sharedEntries();

  test('adds my share of bills from connections', () async {
    await apply([bill('a', by: sam, cents: 9000)]);
    final [entry] = await ledger();
    expect(entry.id, 'a');
    expect(entry.billId, 'a');
    expect(entry.shareCents, 4500);
    expect(entry.categoryId, 'food');
  });

  test('ignores bills from strangers', () async {
    await apply([bill('a', by: 'stranger', members: [me, 'stranger'])]);
    expect(await ledger(), isEmpty);
  });

  test('keeps my category when the bill changes', () async {
    await apply([bill('a', by: sam)]);
    final entry = (await ledger()).single;
    await entries.save(entry.copyWith(categoryId: 'misc'));
    await apply([bill('a', by: sam, cents: 5000)]);
    final updated = (await ledger()).single;
    expect(updated.categoryId, 'misc');
    expect(updated.shareCents, 2500);
  });

  test('unknown categories fall back to misc', () async {
    final b = bill('a', by: sam);
    await apply([
      SharedBill(
        id: b.id,
        createdBy: b.createdBy,
        members: b.members,
        people: b.people,
        amountCents: b.amountCents,
        currencyCode: 'USD',
        date: b.date,
        categoryId: 'sams_own_category',
        createdAt: b.createdAt,
        editedAt: b.editedAt,
      ),
    ]);
    expect((await ledger()).single.categoryId, 'misc');
  });

  test('flagging removes my share and withdrawing brings it back', () async {
    await apply([bill('a', by: sam)]);
    await apply([bill('a', by: sam, flags: {me: flag})]);
    expect(await ledger(), isEmpty);
    await apply([bill('a', by: sam)]);
    expect(await ledger(), hasLength(1));
  });

  test('deleted bills and bills I was removed from are removed', () async {
    await apply([bill('a', by: sam), bill('b', by: sam)]);
    await apply([bill('a', by: sam, deleted: true), bill('b', by: sam)]);
    expect((await ledger()).map((e) => e.id), ['b']);

    // Not in the list any more: only trusted when the snapshot is complete.
    await apply(const [], complete: false);
    expect(await ledger(), hasLength(1));
    await apply(const []);
    expect(await ledger(), isEmpty);
  });

  test('bills already in my ledger stay after disconnecting', () async {
    await apply([bill('a', by: sam)]);
    await apply([bill('a', by: sam, cents: 2000)], connected: const {});
    expect((await ledger()).single.shareCents, 1000);
  });
}
