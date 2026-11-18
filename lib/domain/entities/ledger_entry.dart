/// A single money movement: a purchase, an investment, income, or money
/// coming back (a refund or a roommate paying their share).
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.amountCents,
    required this.categoryId,
    required this.date,
    this.note = '',
    this.splitWays = 1,
    this.createdAt,
  }) : assert(splitWays >= 1);

  final String id;

  /// Full amount in cents. Negative means money came back to you.
  final int amountCents;
  final String categoryId;

  /// Calendar date (time is ignored).
  final DateTime date;
  final String note;

  /// How many people share this bill. Only your share counts toward
  /// your totals: a $46 bill split 2 ways counts as $23.
  final int splitWays;
  final DateTime? createdAt;

  bool get isSplit => splitWays > 1;

  bool get isMoneyBack => amountCents < 0;

  /// The part of [amountCents] that is yours.
  int get shareCents => (amountCents / splitWays).round();

  LedgerEntry copyWith({
    int? amountCents,
    String? categoryId,
    DateTime? date,
    String? note,
    int? splitWays,
  }) {
    return LedgerEntry(
      id: id,
      amountCents: amountCents ?? this.amountCents,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: note ?? this.note,
      splitWays: splitWays ?? this.splitWays,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LedgerEntry &&
      other.id == id &&
      other.amountCents == amountCents &&
      other.categoryId == categoryId &&
      other.date == date &&
      other.note == note &&
      other.splitWays == splitWays;

  @override
  int get hashCode => Object.hash(id, amountCents, categoryId, date, note, splitWays);

  @override
  String toString() => 'LedgerEntry($amountCents, $categoryId, $date, "$note")';
}
