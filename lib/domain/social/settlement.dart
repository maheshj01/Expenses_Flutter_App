/// A record that [from] paid [to] outside the app, e.g. by bank transfer.
/// No money moves through Three Bucks.
class Settlement {
  const Settlement({
    required this.id,
    required this.from,
    required this.to,
    required this.amountCents,
    required this.currencyCode,
    required this.date,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String from;
  final String to;
  final int amountCents;
  final String currencyCode;
  final DateTime date;

  /// Who recorded it. Only they can undo it.
  final String createdBy;
  final DateTime createdAt;

  List<String> get members => [from, to];

  String other(String me) => from == me ? to : from;
}
