import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/domain/entities/app_settings.dart';
import 'package:three_bucks/domain/services/monthly_plan.dart';

void main() {
  test('pay frequencies convert to an average month', () {
    expect(PayFrequency.monthly.toMonthly(360000), 360000);
    expect(PayFrequency.semimonthly.toMonthly(180000), 360000);
    expect(PayFrequency.biweekly.toMonthly(180000), 390000); // 26 paychecks a year
    expect(PayFrequency.weekly.toMonthly(100000), 433333);
  });

  test('plan shows what is left and flags over-commitment', () {
    const plan = MonthlyPlan(incomeCents: 720000, spendingCents: 150000, savingsCents: 500000);
    expect(plan.unplannedCents, 70000);
    expect(plan.isOverCommitted, isFalse);
    expect(plan.dailySpendCents, 5000);

    const tight = MonthlyPlan(incomeCents: 300000, spendingCents: 250000, savingsCents: 100000);
    expect(tight.isOverCommitted, isTrue);
  });

  test('suggestions are rounded to tidy amounts', () {
    expect(MonthlyPlan.suggestSpending(720000, 0.6), 432000);
    expect(MonthlyPlan.suggestSpending(390123, 0.5), 195000);
    expect(MonthlyPlan.suggestSavings(720000, 150000), 570000);
    expect(MonthlyPlan.suggestSavings(500000, 0), 100000);
    expect(MonthlyPlan.suggestSavings(100000, 120000), 0);
  });

  test('set aside counts investing, or the earnings gap if bigger', () {
    expect(MonthlyPlan.setAside(earned: 360500, lived: 73967, invested: 641616), 641616);
    expect(MonthlyPlan.setAside(earned: 700000, lived: 150000, invested: 100000), 550000);
    expect(MonthlyPlan.setAside(earned: 0, lived: 50000, invested: 0), 0);
  });
}
