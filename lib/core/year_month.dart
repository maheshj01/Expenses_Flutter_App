/// A calendar month, used as the main unit for browsing entries.
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month) : assert(month >= 1 && month <= 12);

  factory YearMonth.of(DateTime date) => YearMonth(date.year, date.month);

  factory YearMonth.now() => YearMonth.of(DateTime.now());

  final int year;
  final int month;

  DateTime get firstDay => DateTime(year, month);

  DateTime get lastDay => DateTime(year, month + 1, 0);

  int get dayCount => lastDay.day;

  YearMonth get next => month == 12 ? YearMonth(year + 1, 1) : YearMonth(year, month + 1);

  YearMonth get previous => month == 1 ? YearMonth(year - 1, 12) : YearMonth(year, month - 1);

  @override
  int compareTo(YearMonth other) =>
      year != other.year ? year.compareTo(other.year) : month.compareTo(other.month);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}
