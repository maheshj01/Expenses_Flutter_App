import '../entities/category.dart';
import '../entities/ledger_entry.dart';

/// How categories were used lately, to order the picker for quick entry.
class CategoryUsage {
  const CategoryUsage({this.counts = const {}, this.lastUsed});

  /// [newestFirst]: recent entries, the last one added first.
  factory CategoryUsage.of(List<LedgerEntry> newestFirst) {
    final counts = <String, int>{};
    for (final e in newestFirst) {
      counts.update(e.categoryId, (v) => v + 1, ifAbsent: () => 1);
    }
    return CategoryUsage(
      counts: counts,
      lastUsed: newestFirst.isEmpty ? null : newestFirst.first.categoryId,
    );
  }

  static const none = CategoryUsage();

  /// Entries per category id.
  final Map<String, int> counts;

  /// Category of the entry added last.
  final String? lastUsed;

  /// The last used category first, then the most used, then the user's own
  /// order.
  List<Category> order(Iterable<Category> categories) => [...categories]
    ..sort((a, b) {
      if (a.id == lastUsed || b.id == lastUsed) {
        return a.id == lastUsed ? (b.id == lastUsed ? 0 : -1) : 1;
      }
      final byUse = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
      return byUse != 0 ? byUse : a.sortOrder.compareTo(b.sortOrder);
    });
}
