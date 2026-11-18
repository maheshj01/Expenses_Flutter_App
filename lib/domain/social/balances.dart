import 'settlement.dart';
import 'shared_bill.dart';

/// Who owes whom, from the point of view of one person.
///
/// Amounts are per currency. Positive means the other person owes you,
/// negative means you owe them.
class Balances {
  Balances._(this._byPerson);

  /// Works out balances for [me] from every bill and settlement they see.
  factory Balances.of(String me, Iterable<SharedBill> bills, Iterable<Settlement> settlements) {
    final byPerson = <String, Map<String, int>>{};
    void add(String person, String currency, int cents) {
      if (cents == 0 || person == me) return;
      final balance = byPerson.putIfAbsent(person, () => {});
      balance.update(currency, (v) => v + cents, ifAbsent: () => cents);
    }

    for (final bill in bills) {
      if (bill.deleted || !bill.members.contains(me)) continue;
      if (bill.createdBy == me) {
        for (final member in bill.members) {
          add(member, bill.currencyCode, bill.owedBy(member));
        }
      } else {
        add(bill.createdBy, bill.currencyCode, -bill.owedBy(me));
      }
    }
    for (final s in settlements) {
      if (s.from == me) add(s.to, s.currencyCode, s.amountCents);
      if (s.to == me) add(s.from, s.currencyCode, -s.amountCents);
    }
    for (final balance in byPerson.values) {
      balance.removeWhere((_, cents) => cents == 0);
    }
    return Balances._(byPerson);
  }

  static final empty = Balances._(const {});

  final Map<String, Map<String, int>> _byPerson;

  /// Balance with [person] per currency. Empty when settled up.
  Map<String, int> withPerson(String person) => _byPerson[person] ?? const {};

  /// Balance with [person] in [currency].
  int net(String person, String currency) => withPerson(person)[currency] ?? 0;

  /// Everyone you have a non-zero balance with.
  Iterable<String> get people => _byPerson.keys.where((p) => _byPerson[p]!.isNotEmpty);

  /// Total others owe you in [currency].
  int owedToMe(String currency) => _sum(currency, (c) => c > 0);

  /// Total you owe others in [currency], as a positive number.
  int iOwe(String currency) => -_sum(currency, (c) => c < 0);

  /// Currencies with any open balance.
  Set<String> get currencies => {for (final b in _byPerson.values) ...b.keys};

  int _sum(String currency, bool Function(int) test) {
    var total = 0;
    for (final b in _byPerson.values) {
      final c = b[currency] ?? 0;
      if (test(c)) total += c;
    }
    return total;
  }
}
