import '../entities/ledger_entry.dart';
import '../history/edit.dart';

/// An entry that was deleted, and when.
typedef DeletedEntry = ({LedgerEntry entry, DateTime deletedAt});

abstract interface class EntryRepository {
  /// Entries whose date is within [from]..[to] (inclusive), newest first.
  Stream<List<LedgerEntry>> watchBetween(DateTime from, DateTime to);

  /// Every year that has at least one entry, newest first.
  Stream<List<int>> watchYears();

  /// The most recent entries, used to learn how the user categorises notes.
  Future<List<LedgerEntry>> recent({int limit = 500});

  /// The entry with [id], unless it doesn't exist or was deleted.
  Future<LedgerEntry?> byId(String id);

  /// How many entries there are, shares of bills included.
  Future<int> count();

  /// Every entry that is a share of a bill split with people on the app.
  Future<List<LedgerEntry>> sharedEntries();

  /// Ids of the shared bills that have an entry in the ledger, kept up to
  /// date.
  Stream<Set<String>> watchSharedBillIds();

  /// Inserts or updates [entry]. Updating one of your own entries (not a
  /// share of a bill) records what changed, and saving a deleted one
  /// restores it; see [watchEdits].
  Future<void> save(LedgerEntry entry);

  /// Every recorded edit of the entry with [entryId], newest first.
  Stream<List<Edit>> watchEdits(String entryId);

  /// Inserts or updates many entries at once, e.g. from an import.
  Future<void> saveAll(List<LedgerEntry> entries);

  /// Deletes one entry. Your own entries record the deletion in their
  /// history and stay listed by [watchDeletedBetween].
  Future<void> delete(String id);

  /// Deleted entries dated within [from]..[to], newest first: your own
  /// entries you deleted one at a time, and every share of a bill that left
  /// the ledger (callers keep those whose bill was deleted).
  Stream<List<DeletedEntry>> watchDeletedBetween(DateTime from, DateTime to);

  /// Deletes many entries at once without recording it, e.g. to undo an
  /// import.
  Future<void> deleteAll(List<String> ids);
}
