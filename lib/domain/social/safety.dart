import 'account.dart';

/// Why someone reports another person.
enum ReportReason {
  spam('Spam or scam'),
  harassment('Harassment or bullying'),
  offensive('Offensive name or note'),
  impersonation('Pretending to be someone else'),
  other('Something else');

  const ReportReason(this.label);

  final String label;
}

/// A report about another person, sent to the app's moderators. [billId]
/// points at the bill whose note or name prompted it, if any.
class Report {
  const Report({
    required this.id,
    required this.reported,
    required this.reason,
    this.note = '',
    this.billId,
    required this.at,
  });

  /// Longest note a report can carry; `firestore.rules` checks it too.
  static const maxNote = 500;

  final String id;
  final Profile reported;
  final ReportReason reason;
  final String note;
  final String? billId;
  final DateTime at;
}

/// Someone you blocked: they can't find you, send you requests, or share
/// new bills with you until you unblock them.
class BlockedPerson {
  const BlockedPerson({required this.profile, required this.at});

  final Profile profile;
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is BlockedPerson && other.profile == profile && other.at == at;

  @override
  int get hashCode => Object.hash(profile, at);
}
