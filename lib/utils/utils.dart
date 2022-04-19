import 'package:expense_manager/model/expense.dart';

List<Expense> showExpenseFor(String filter, List<Expense> expenses) {
  final now = DateTime.now();
  DateTime startDay = DateTime.now();
  DateTime endDay = DateTime.now();
  if (filter == 'Monthly') {
    startDay = DateTime(now.year, now.month, 1);
    endDay = DateTime(now.year, now.month + 1, 1);
  } else if (filter == 'Yearly') {
    startDay = DateTime(now.year, 1, 1);
    endDay = DateTime(now.year + 1, 1, 1);
  } else if (filter == 'Weekly') {
    int currentDay = now.weekday;
    startDay = now.subtract(Duration(days: currentDay));
    endDay = startDay.add(Duration(days: 6));
  } else {
    /// Daily expenses
    return expenses;
  }
  return expenses
      .where((expense) =>
          expense.dateTime!.isAfter(startDay) &&
          expense.dateTime!.isBefore(endDay))
      .toList();
}
