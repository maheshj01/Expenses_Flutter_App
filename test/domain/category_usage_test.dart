import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/domain/entities/category.dart';
import 'package:three_bucks/domain/entities/ledger_entry.dart';
import 'package:three_bucks/domain/services/category_usage.dart';

void main() {
  Category cat(String id, int order) =>
      Category(id: id, name: id, emoji: '📦', color: 1, sortOrder: order);
  final categories = [cat('food', 0), cat('fuel', 1), cat('rent', 2), cat('gifts', 3)];

  LedgerEntry entry(String categoryId) =>
      LedgerEntry(id: categoryId, amountCents: 100, categoryId: categoryId, date: DateTime(2026));

  List<String> order(List<String> newestFirst) =>
      CategoryUsage.of([for (final id in newestFirst) entry(id)])
          .order(categories)
          .map((c) => c.id)
          .toList();

  test('the last used category comes first, then the most used', () {
    // Food is used most, but rent was added last.
    expect(order(['rent', 'food', 'food', 'fuel', 'food']), ['rent', 'food', 'fuel', 'gifts']);
  });

  test('when the last used is also the most used it simply leads', () {
    expect(order(['food', 'fuel', 'food']), ['food', 'fuel', 'rent', 'gifts']);
  });

  test('with no entries yet, the user’s own order', () {
    expect(order([]), ['food', 'fuel', 'rent', 'gifts']);
  });
}
