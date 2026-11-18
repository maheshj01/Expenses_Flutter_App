import 'account.dart';

/// Why someone disputes their share of a bill.
enum FlagReason {
  wrongAmount('Wrong amount'),
  notPartOfThis('I wasn’t part of this'),
  alreadyPaid('Already paid');

  const FlagReason(this.label);

  final String label;

  static FlagReason parse(String? value) =>
      FlagReason.values.firstWhere((r) => r.name == value, orElse: () => FlagReason.wrongAmount);
}

/// A dispute on one person's share. While it exists that share counts for
/// nothing: not in balances, not in the flagger's spending.
class BillFlag {
  const BillFlag({required this.reason, this.note = '', required this.at});

  final FlagReason reason;
  final String note;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'reason': reason.name,
    'note': note,
    'at': at.millisecondsSinceEpoch,
  };

  static BillFlag fromJson(Map<String, Object?> json) => BillFlag(
    reason: FlagReason.parse(json['reason'] as String?),
    note: json['note'] as String? ?? '',
    at: DateTime.fromMillisecondsSinceEpoch((json['at'] as num?)?.toInt() ?? 0),
  );

  @override
  bool operator ==(Object other) =>
      other is BillFlag && other.reason == reason && other.note == note && other.at == at;

  @override
  int get hashCode => Object.hash(reason, note, at);
}

/// A bill paid by [createdBy] and split equally between [members] (people on
/// the app, the payer included) and [guests] (people who aren't).
///
/// Only the creator edits it. Everyone else can only flag their own share.
class SharedBill {
  const SharedBill({
    required this.id,
    required this.createdBy,
    required this.members,
    required this.people,
    this.guests = 0,
    required this.amountCents,
    required this.currencyCode,
    required this.date,
    this.note = '',
    this.memo = '',
    required this.categoryId,
    this.flags = const {},
    required this.createdAt,
    required this.editedAt,
    this.deleted = false,
  }) : assert(guests >= 0);

  final String id;

  /// Who paid and who may edit.
  final String createdBy;

  /// Everyone on the app sharing it, the payer included.
  final List<String> members;

  /// Names and handles of [members] when the bill was saved, so it can be
  /// shown even to people who aren't connected with every member.
  final Map<String, Profile> people;

  /// People sharing the bill who aren't on the app.
  final int guests;

  /// Full amount, always positive.
  final int amountCents;
  final String currencyCode;
  final DateTime date;

  /// Short title, e.g. "Costco".
  final String note;

  /// Optional context from the payer, e.g. "I covered the tip".
  final String memo;

  /// The payer's category. Others map it to one of theirs.
  final String categoryId;

  /// Open disputes by member uid.
  final Map<String, BillFlag> flags;
  final DateTime createdAt;

  /// Last time the payer changed it. Any edit clears all flags.
  final DateTime editedAt;
  final bool deleted;

  int get ways => members.length + guests;

  /// Each person's equal share.
  int get shareCents => (amountCents / ways).round();

  bool isFlaggedBy(String uid) => flags.containsKey(uid);

  bool get isDisputed => flags.isNotEmpty;

  String nameOf(String uid) => people[uid]?.displayName ?? 'Someone';

  /// What [debtor] owes the payer for this bill. Zero for the payer, for
  /// non-members and while the share is flagged.
  int owedBy(String debtor) {
    if (deleted || debtor == createdBy || !members.contains(debtor)) return 0;
    return isFlaggedBy(debtor) ? 0 : shareCents;
  }

  SharedBill copyWith({
    List<String>? members,
    Map<String, Profile>? people,
    int? guests,
    int? amountCents,
    String? currencyCode,
    DateTime? date,
    String? note,
    String? memo,
    String? categoryId,
    Map<String, BillFlag>? flags,
    DateTime? editedAt,
    bool? deleted,
  }) {
    return SharedBill(
      id: id,
      createdBy: createdBy,
      members: members ?? this.members,
      people: people ?? this.people,
      guests: guests ?? this.guests,
      amountCents: amountCents ?? this.amountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      date: date ?? this.date,
      note: note ?? this.note,
      memo: memo ?? this.memo,
      categoryId: categoryId ?? this.categoryId,
      flags: flags ?? this.flags,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  /// The payer's edit: resolves every open flag.
  SharedBill edited({
    required List<String> members,
    required Map<String, Profile> people,
    required int guests,
    required int amountCents,
    required String currencyCode,
    required DateTime date,
    required String note,
    required String memo,
    required String categoryId,
    required DateTime at,
  }) => copyWith(
    members: members,
    people: people,
    guests: guests,
    amountCents: amountCents,
    currencyCode: currencyCode,
    date: date,
    note: note,
    memo: memo,
    categoryId: categoryId,
    flags: const {},
    editedAt: at,
  );

  @override
  String toString() => 'SharedBill($id, $amountCents/$ways, by $createdBy)';
}

/// The bills the current account can see.
class BillsSnapshot {
  const BillsSnapshot(this.bills, {required this.complete});

  static const empty = BillsSnapshot([], complete: false);

  final List<SharedBill> bills;

  /// True when this is the server's full answer. Only then does a missing
  /// bill mean "you were removed from it" rather than "not loaded yet".
  final bool complete;
}
