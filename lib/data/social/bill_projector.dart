import 'dart:async';

import '../../domain/entities/ledger_entry.dart';
import '../../domain/repositories/entry_repository.dart';
import '../../domain/social/shared_bill.dart';

/// Keeps your share of every shared bill in your own ledger, so totals,
/// budgets and history treat it like any other entry.
///
/// Each bill becomes one entry with the bill's id. Your category choice is
/// kept when the bill changes. The entry is removed while you have the bill
/// flagged, when it is deleted, and when you are taken off it.
class BillProjector {
  BillProjector(this._entries);

  final EntryRepository _entries;
  Future<void> _queue = Future.value();

  /// Brings the ledger in line with [snapshot]. Calls run one at a time.
  ///
  /// Bills from people you aren't connected with are ignored unless they
  /// are already in your ledger, so strangers can't add to your spending.
  Future<void> apply({
    required String me,
    required BillsSnapshot snapshot,
    required Set<String> connected,
    required Set<String> categoryIds,
    String fallbackCategoryId = 'misc',
  }) {
    final run = _queue.then(
      (_) => _apply(me, snapshot, connected, categoryIds, fallbackCategoryId),
    );
    _queue = run.catchError((Object _) {});
    return run;
  }

  Future<void> _apply(
    String me,
    BillsSnapshot snapshot,
    Set<String> connected,
    Set<String> categoryIds,
    String fallback,
  ) async {
    final existing = {for (final e in await _entries.sharedEntries()) e.billId!: e};
    final known = {for (final b in snapshot.bills) b.id: b};

    for (final bill in snapshot.bills) {
      final current = existing[bill.id];
      final trusted = bill.createdBy == me || connected.contains(bill.createdBy) || current != null;
      final mine = !bill.deleted && bill.members.contains(me) && !bill.isFlaggedBy(me);
      if (!trusted || !mine) continue;

      final desired = LedgerEntry(
        id: bill.id,
        amountCents: bill.amountCents,
        categoryId:
            current?.categoryId ??
            (categoryIds.contains(bill.categoryId) ? bill.categoryId : fallback),
        date: bill.date,
        note: bill.note,
        splitWays: bill.ways,
        guestNames: bill.guestNames,
        billId: bill.id,
        createdAt: current?.createdAt ?? bill.createdAt,
      );
      if (desired != current) await _entries.save(desired);
    }

    for (final entry in existing.values) {
      final bill = known[entry.billId];
      final gone = bill == null
          ? snapshot.complete
          : bill.deleted || !bill.members.contains(me) || bill.isFlaggedBy(me);
      if (gone) await _entries.delete(entry.id);
    }
  }
}
