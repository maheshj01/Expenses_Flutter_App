import 'package:expense_manager/constants/strings.dart';
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
