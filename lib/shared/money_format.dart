import 'package:intl/intl.dart';

/// Formats integer cents in the user's currency.
class MoneyFormat {
  MoneyFormat(this.currencyCode)
    : _full = NumberFormat.simpleCurrency(name: currencyCode),
      _whole = NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 0),
      _compact = NumberFormat.compactSimpleCurrency(name: currencyCode);

  final String currencyCode;
  final NumberFormat _full;
  final NumberFormat _whole;
  final NumberFormat _compact;

  String get symbol => _full.currencySymbol;

  /// `$1,234.50`
  String call(int cents) => _full.format(cents / 100);

  /// `$1,235`
  String whole(int cents) => _whole.format(cents / 100);

  /// `$1.2K`
  String compact(int cents) => _compact.format(cents / 100);

  /// `+$500.00` for money coming in.
  String signed(int cents) => cents < 0 ? '+${call(-cents)}' : call(cents);
}
