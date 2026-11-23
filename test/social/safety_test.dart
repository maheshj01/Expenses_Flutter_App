import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/domain/social/account.dart';
import 'package:three_bucks/domain/social/connection.dart';
import 'package:three_bucks/domain/social/safety.dart';

import '../support/fake_social.dart';

void main() {
  late FakeSocialServer server;
  late Profile maya;
  late Profile sam;
  late FakeSocialBackend mayasPhone;
  late FakeSocialBackend samsPhone;

  setUp(() {
    server = FakeSocialServer();
    maya = server.addPerson('maya', 'maya', 'Maya');
    sam = server.addPerson('sam', 'sam', 'Sam');
    mayasPhone = FakeSocialBackend(
      server,
      signInAs: const Account(uid: 'maya', method: SignInMethod.apple),
      signedIn: true,
    );
    samsPhone = FakeSocialBackend(
      server,
      signInAs: const Account(uid: 'sam', method: SignInMethod.google),
      signedIn: true,
    );
  });

  tearDown(() => server.dispose());

  test('blocking disconnects and stops lookups and requests', () async {
    server.connect(maya, sam);
    await mayasPhone.block(sam);

    expect(server.connections, isEmpty);
    expect(await samsPhone.findByHandle('maya'), isNull, reason: 'Maya is hidden from Sam');
    await samsPhone.requestConnection(sam, maya);
    expect(server.connections, isEmpty, reason: 'Sam can’t ask again');
    await mayasPhone.requestConnection(maya, sam);
    expect(server.connections, isEmpty, reason: 'nor can Maya while Sam is blocked');

    final blocked = await mayasPhone.watchBlocked().first;
    expect(blocked.single.profile, sam);
    expect(await samsPhone.watchBlocked().first, isEmpty, reason: 'only the blocker sees it');
  });

  test('unblocking lets them connect again', () async {
    await mayasPhone.block(sam);
    await mayasPhone.unblock('sam');

    expect(await samsPhone.findByHandle('maya'), maya);
    await samsPhone.requestConnection(sam, maya);
    expect(server.connections[Connection.pairId('maya', 'sam')], isNotNull);
  });

  test('reports reach the moderators with the reporter', () async {
    await mayasPhone.report(
      Report(
        id: 'r1',
        reported: sam,
        reason: ReportReason.offensive,
        note: 'Rude bill note',
        billId: 'b1',
        at: DateTime(2026, 11, 23),
      ),
    );

    final (reporter, report) = server.reports.single;
    expect(reporter, 'maya');
    expect(report.reported, sam);
    expect(report.reason, ReportReason.offensive);
    expect(report.billId, 'b1');
  });
}
