import 'connection.dart';
import 'settlement.dart';
import 'shared_bill.dart';

enum InboxKind {
  /// Someone wants to connect. Needs an answer.
  request,

  /// Someone flagged their share of a bill you created. Needs resolving.
  flag,

  /// Someone added you to a bill.
  newBill,

  /// The payer changed a bill you're on.
  billUpdated,

  /// Someone recorded a payment with you.
  settlement,
}

class InboxItem {
  const InboxItem({
    required this.kind,
    required this.at,
    required this.who,
    this.connection,
    this.bill,
    this.flag,
    this.settlement,
  });

  final InboxKind kind;
  final DateTime at;

  /// The other person's uid.
  final String who;
  final Connection? connection;
  final SharedBill? bill;
  final BillFlag? flag;
  final Settlement? settlement;

  /// Stays in the inbox until acted on.
  bool get needsAction => kind == InboxKind.request || kind == InboxKind.flag;

  String get key => '${kind.name}:${connection?.id ?? bill?.id ?? settlement?.id}:$who';
}

/// What's new with the people you share bills with, newest first.
class Inbox {
  const Inbox(this.items);

  static const empty = Inbox([]);

  /// How far back non-actionable news goes.
  static const window = Duration(days: 45);

  factory Inbox.build({
    required String me,
    required List<Connection> connections,
    required List<SharedBill> bills,
    required List<Settlement> settlements,
    required DateTime now,
  }) {
    final since = now.subtract(window);
    final connected = {for (final c in connections.where((c) => c.isAccepted)) c.other.uid};
    final items = <InboxItem>[
      for (final c in connections.where((c) => c.isIncomingRequest))
        InboxItem(kind: InboxKind.request, at: c.createdAt, who: c.other.uid, connection: c),
      for (final b in bills.where((b) => !b.deleted && b.createdBy == me))
        for (final MapEntry(key: uid, value: flag) in b.flags.entries)
          InboxItem(kind: InboxKind.flag, at: flag.at, who: uid, bill: b, flag: flag),
      for (final b in bills)
        if (!b.deleted &&
            b.createdBy != me &&
            b.members.contains(me) &&
            connected.contains(b.createdBy) &&
            b.editedAt.isAfter(since))
          InboxItem(
            kind: b.editedAt.difference(b.createdAt) > const Duration(minutes: 1)
                ? InboxKind.billUpdated
                : InboxKind.newBill,
            at: b.editedAt,
            who: b.createdBy,
            bill: b,
          ),
      for (final s in settlements)
        if (s.createdBy != me && s.createdAt.isAfter(since))
          InboxItem(kind: InboxKind.settlement, at: s.createdAt, who: s.other(me), settlement: s),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return Inbox(items);
  }

  final List<InboxItem> items;

  bool get isEmpty => items.isEmpty;

  /// Items needing action plus news newer than [seenAt].
  int unread(DateTime seenAt) =>
      items.where((i) => i.needsAction || i.at.isAfter(seenAt)).length;
}
