import '../entities/ledger_entry.dart';

abstract interface class EntryRepository {
  /// Entries whose date is within [from]..[to] (inclusive), newest first.
  Stream<List<LedgerEntry>> watchBetween(DateTime from, DateTime to);

  /// Every year that has at least one entry, newest first.
  Stream<List<int>> watchYears();

  /// The most recent entries, used to learn how the user categorises notes.
  Future<List<LedgerEntry>> recent({int limit = 500});

  /// The entry with [id], unless it doesn't exist or was deleted.
  Future<LedgerEntry?> byId(String id);

  /// Every entry that is a share of a bill split with people on the app.
  Future<List<LedgerEntry>> sharedEntries();

  /// Inserts or updates [entry].
  Future<void> save(LedgerEntry entry);

  /// Inserts or updates many entries at once, e.g. from an import.
  Future<void> saveAll(List<LedgerEntry> entries);

  Future<void> delete(String id);

  /// Deletes many entries at once, e.g. to undo an import.
  Future<void> deleteAll(List<String> ids);
}
