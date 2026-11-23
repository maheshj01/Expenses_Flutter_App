import '../../core/day.dart';
import '../entities/ledger_entry.dart';
import '../social/shared_bill.dart';

/// A field an edit can change. Stored by [name], so don't rename values.
enum EditField {
  amount,
  currency,
  category,
  date,
  note,
  memo,

  /// Names of the people on the app sharing a bill.
  people,

  /// How many people a bill is split with who aren't on the app.
  guests,

  /// Names of the people sharing it who aren't on the app.
  guestNames,

  /// How many ways your own entry is split.
  split,
  deleted;

  static EditField? parse(String name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// What one field was before and after an edit. Values are plain JSON
/// (int, String, bool or a list of strings): amounts in cents, dates as
/// [DayKey]s, categories by id.
class FieldChange {
  const FieldChange(this.from, this.to);

  final Object? from;
  final Object? to;

  Map<String, Object?> toJson() => {'from': from, 'to': to};

  static FieldChange fromJson(Object? json) {
    final map = json is Map ? json : const {};
    return FieldChange(_plain(map['from']), _plain(map['to']));
  }

  /// Lists come back from storage as `List<dynamic>`.
  static Object? _plain(Object? v) => v is List ? [for (final x in v) '$x'] : v;

  @override
  bool operator ==(Object other) =>
      other is FieldChange && _same(other.from, from) && _same(other.to, to);

  @override
  int get hashCode => Object.hash('$from', '$to');

  @override
  String toString() => '$from → $to';
}

/// One edit of an entry or shared bill: when, by whom and what changed.
///
/// Only edits are recorded, not the first save: the "from" side of the
/// oldest edit shows what it was created as.
class Edit {
  const Edit({
    required this.id,
    required this.subjectId,
    required this.at,
    this.by,
    required this.changes,
  });

  final String id;

  /// The entry or bill it changed.
  final String subjectId;
  final DateTime at;

  /// Who made it, for shared bills. Null for your own entries.
  final String? by;
  final Map<EditField, FieldChange> changes;

  static Map<String, Object?> changesToJson(Map<EditField, FieldChange> changes) => {
    for (final MapEntry(:key, :value) in changes.entries) key.name: value.toJson(),
  };

  static Map<EditField, FieldChange> changesFromJson(Object? json) {
    final map = json is Map ? json : const {};
    return {
      for (final MapEntry(:key, :value) in map.entries)
        ?EditField.parse('$key'): FieldChange.fromJson(value),
    };
  }

  @override
  String toString() => 'Edit($subjectId at $at: $changes)';
}

/// What changed between two versions of your own entry.
Map<EditField, FieldChange> entryChanges(LedgerEntry before, LedgerEntry after) {
  final changes = <EditField, FieldChange>{};
  void diff(EditField field, Object? from, Object? to) {
    if (!_same(from, to)) changes[field] = FieldChange(from, to);
  }

  diff(EditField.amount, before.amountCents, after.amountCents);
  diff(EditField.category, before.categoryId, after.categoryId);
  diff(EditField.date, DayKey.fromDate(before.date), DayKey.fromDate(after.date));
  diff(EditField.note, before.note.trim(), after.note.trim());
  diff(EditField.split, before.splitWays, after.splitWays);
  diff(EditField.guestNames, before.guestNames, after.guestNames);
  return changes;
}

/// What the payer changed between two versions of a shared bill. Flags
/// aren't edits (they're shown on the bill), so they're left out.
Map<EditField, FieldChange> billChanges(SharedBill before, SharedBill after) {
  final changes = <EditField, FieldChange>{};
  void diff(EditField field, Object? from, Object? to) {
    if (!_same(from, to)) changes[field] = FieldChange(from, to);
  }

  List<String> names(SharedBill b) => [for (final uid in b.members) b.nameOf(uid)];

  diff(EditField.amount, before.amountCents, after.amountCents);
  diff(EditField.currency, before.currencyCode, after.currencyCode);
  diff(EditField.category, before.categoryId, after.categoryId);
  diff(EditField.date, DayKey.fromDate(before.date), DayKey.fromDate(after.date));
  diff(EditField.note, before.note.trim(), after.note.trim());
  diff(EditField.memo, before.memo.trim(), after.memo.trim());
  if (!_same({...before.members}.toList()..sort(), {...after.members}.toList()..sort())) {
    changes[EditField.people] = FieldChange(names(before), names(after));
  }
  diff(EditField.guests, before.guests, after.guests);
  diff(EditField.guestNames, before.guestNames, after.guestNames);
  diff(EditField.deleted, before.deleted, after.deleted);
  return changes;
}

bool _same(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  return a == b;
}
