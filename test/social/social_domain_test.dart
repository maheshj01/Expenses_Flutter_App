import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/domain/social/account.dart';
import 'package:three_bucks/domain/social/balances.dart';
import 'package:three_bucks/domain/social/connection.dart';
import 'package:three_bucks/domain/social/inbox.dart';
import 'package:three_bucks/domain/social/settlement.dart';
import 'package:three_bucks/domain/social/shared_bill.dart';

const me = 'me', sam = 'sam', ana = 'ana';
final _day = DateTime(2026, 11, 10);

SharedBill bill(
  String id, {
  String by = me,
  List<String> members = const [me, sam],
  int cents = 9000,
  int guests = 0,
  Map<String, BillFlag> flags = const {},
  bool deleted = false,
  DateTime? created,
  DateTime? edited,
}) => SharedBill(
  id: id,
  createdBy: by,
  members: members,
  people: {for (final m in members) m: Profile(uid: m, handle: m, name: m.toUpperCase())},
  guests: guests,
  amountCents: cents,
  currencyCode: 'USD',
  date: _day,
  categoryId: 'food',
  flags: flags,
  createdAt: created ?? _day,
  editedAt: edited ?? created ?? _day,
  deleted: deleted,
);

Settlement paid(String from, String to, int cents, {String by = me, DateTime? at}) => Settlement(
  id: '$from-$to-$cents',
  from: from,
  to: to,
  amountCents: cents,
  currencyCode: 'USD',
  date: _day,
  createdBy: by,
  createdAt: at ?? _day,
);

final flag = BillFlag(reason: FlagReason.wrongAmount, at: DateTime(2026, 11, 12));

void main() {
  group('SharedBill', () {
    test('splits equally between members and guests', () {
      final b = bill('a', members: [me, sam, ana], guests: 1, cents: 10000);
      expect(b.ways, 4);
      expect(b.shareCents, 2500);
      expect(b.owedBy(sam), 2500);
      expect(b.owedBy(me), 0, reason: 'the payer owes nothing');
      expect(b.owedBy('stranger'), 0);
    });

    test('a flagged share is owed by nobody', () {
      final b = bill('a', flags: {sam: flag});
      expect(b.owedBy(sam), 0);
      expect(b.isDisputed, isTrue);
    });
  });

  group('Balances', () {
    test('adds up what each person owes, from my side', () {
      final balances = Balances.of(me, [
        bill('a'), // sam owes me 45
        bill('b', by: sam, cents: 3000), // I owe sam 15
        bill('c', members: [me, sam, ana], cents: 6000), // sam and ana owe me 20 each
      ], const []);
      expect(balances.net(sam, 'USD'), 4500 - 1500 + 2000);
      expect(balances.net(ana, 'USD'), 2000);
      expect(balances.owedToMe('USD'), 7000);
      expect(balances.iOwe('USD'), 0);
    });

    test('settlements, flags and deleted bills are taken into account', () {
      final balances = Balances.of(
        me,
        [
          bill('a'),
          bill('b', flags: {sam: flag}),
          bill('c', deleted: true),
          bill('d', by: sam, cents: 2000),
        ],
        [paid(sam, me, 4500, by: sam), paid(me, sam, 500)],
      );
      // +4500 (a) -1000 (d) -4500 (sam paid me) +500 (I paid sam)
      expect(balances.net(sam, 'USD'), -500);
      expect(balances.iOwe('USD'), 500);
    });

    test('a settled balance disappears', () {
      final balances = Balances.of(me, [bill('a')], [paid(sam, me, 4500, by: sam)]);
      expect(balances.withPerson(sam), isEmpty);
      expect(balances.people, isEmpty);
    });

    test('bills between other people do not affect me', () {
      final balances = Balances.of(me, [
        bill('a', by: sam, members: [sam, ana]),
      ], const []);
      expect(balances.people, isEmpty);
    });
  });

  group('Handle', () {
    test('normalizes input', () {
      expect(Handle.normalize('  @Maya Rao '), 'mayarao');
    });

    test('validates', () {
      expect(Handle.validate('maya'), isNull);
      expect(Handle.validate('ma'), isNotNull);
      expect(Handle.validate('1maya'), isNotNull);
      expect(Handle.validate('maya!'), isNotNull);
      expect(Handle.validate('maya.'), isNotNull);
      expect(Handle.validate('a' * 21), isNotNull);
    });

    test('suggests one from a name', () {
      expect(Handle.suggest('Maya Rao'), 'mayarao');
      expect(Handle.suggest('42 José'), 'jos');
    });
  });

  test('pair ids are the same from both sides', () {
    expect(Connection.pairId('a', 'b'), Connection.pairId('b', 'a'));
  });

  group('Inbox', () {
    Connection conn(String uid, {bool accepted = true, bool mine = false}) => Connection(
      id: Connection.pairId(me, uid),
      other: Profile(uid: uid, handle: uid, name: uid),
      status: accepted ? ConnectionStatus.accepted : ConnectionStatus.pending,
      requestedByMe: mine,
      createdAt: DateTime(2026, 11, 14),
    );

    test('collects requests, flags, new bills and payments, newest first', () {
      final inbox = Inbox.build(
        me: me,
        connections: [
          conn(sam),
          conn(ana, accepted: false),
          conn('zoe', accepted: false, mine: true),
        ],
        bills: [
          bill('mine', flags: {sam: flag}),
          bill('new', by: sam, created: DateTime(2026, 11, 13)),
          bill('edited', by: sam, created: DateTime(2026, 11, 1), edited: DateTime(2026, 11, 15)),
          bill('stranger', by: 'stranger', members: [me, 'stranger']),
        ],
        settlements: [paid(sam, me, 100, by: sam, at: DateTime(2026, 11, 16))],
        now: DateTime(2026, 11, 17),
      );
      expect(inbox.items.map((i) => i.kind), [
        InboxKind.settlement,
        InboxKind.billUpdated,
        InboxKind.request,
        InboxKind.newBill,
        InboxKind.flag,
      ]);
      expect(inbox.unread(DateTime(2026, 11, 14, 12)), 4, reason: 'two news items + two actions');
    });
  });
}
