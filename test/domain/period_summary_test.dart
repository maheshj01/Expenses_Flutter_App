import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/domain/entities/category.dart';
import 'package:spendwise/domain/entities/ledger_entry.dart';
import 'package:spendwise/domain/services/period_summary.dart';

void main() {
  const cats = {
    'food': Category(id: 'food', name: 'Food', emoji: '🛒', color: 0),
    'housing': Category(id: 'housing', name: 'Housing', emoji: '🏠', color: 0),
    'invest': Category(
      id: 'invest',
      name: 'Investment',
      emoji: '📈',
      color: 0,
      kind: CategoryKind.investing,
    ),
    'salary': Category(
      id: 'salary',
      name: 'Salary',
      emoji: '💼',
      color: 0,
      kind: CategoryKind.income,
    ),
  };
  LedgerEntry e(int cents, String cat, {int split = 1}) => LedgerEntry(
    id: '$cents$cat',
    amountCents: cents,
    categoryId: cat,
    date: DateTime(2026, 11),
    splitWays: split,
  );

  test('separates lived, invested and earned and applies splits', () {
    final s = PeriodSummary.of([
      e(116600, 'housing'),
      e(-50000, 'housing'), // roommate paid their share
      e(4600, 'food', split: 2),
      e(125000, 'invest'),
      e(360500, 'salary'),
    ], cats);

    expect(s.livedCents, 66600 + 2300);
    expect(s.investedCents, 125000);
    expect(s.earnedCents, 360500);
    expect(s.keptCents, 360500 - 68900 - 125000);
    expect(s.byCategory['housing'], 66600);
    expect(s.ranked(cats, CategoryKind.spending).first.key, 'housing');
  });

  test('budget pace spreads what is left over the remaining days', () {
    final pace = BudgetPace.forMonth(
      budgetCents: 135000,
      livedCents: 73967,
      today: DateTime(2026, 11, 17),
      daysInMonth: 30,
    );
    expect(pace.daysLeft, 14);
    expect(pace.remainingCents, 61033);
    expect(pace.safePerDayCents, 4359);
    expect(pace.isOver, isFalse);
  });

  test('budget pace never suggests negative spending', () {
    final pace = BudgetPace.forMonth(
      budgetCents: 1000,
      livedCents: 2000,
      today: DateTime(2026, 11, 3),
      daysInMonth: 30,
    );
    expect(pace.isOver, isTrue);
    expect(pace.safePerDayCents, 0);
    expect(pace.usedFraction, 1);
  });
}
