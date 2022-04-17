import 'package:expense_manager/constants/strings.dart';
import 'package:expense_manager/model/model.dart';
import 'package:intl/intl.dart';

extension Capitalize on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${this.substring(1)}';
  }
}

extension DateHelper on DateTime {
  String formatDate() {
    final now = DateTime.now();
    final differenceInDays = getDifferenceInDaysWithNow();

    if (this.isSameDate(now)) {
      return 'Today';
    } else if (differenceInDays == 1) {
      return 'Yesterday';
    } else {
      final formatter = DateFormat(dateFormatter);
      return formatter.format(this);
    }
  }

  bool isSameDate(DateTime other) {
    return this.year == other.year &&
        this.month == other.month &&
        this.day == other.day;
  }

  int getDifferenceInDaysWithNow() {
    final now = DateTime.now();
    return now.difference(this).inDays;
  }
}

extension ListContainsObject<T> on List {
  bool containsObject(T object) {
    for (var item in this) {
      if (object == item) {
        return true;
      }
    }
    return false;
  }
}

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
          expense.datetime!.isAfter(startDay) &&
          expense.datetime!.isBefore(endDay))
      .toList();
}
