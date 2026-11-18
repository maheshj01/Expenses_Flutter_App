/// Helpers for storing a calendar date (no time, no time zone) as an
/// integer of the form `yyyymmdd`. This keeps date-range queries simple and
/// immune to time-zone and daylight-saving shifts.
abstract final class DayKey {
  static int fromDate(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  static DateTime toDate(int key) => DateTime(key ~/ 10000, (key ~/ 100) % 100, key % 100);

  static int startOfMonth(int year, int month) => year * 10000 + month * 100 + 1;

  static int endOfMonth(int year, int month) => year * 10000 + month * 100 + 31;

  static int startOfYear(int year) => year * 10000 + 101;

  static int endOfYear(int year) => year * 10000 + 1231;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
