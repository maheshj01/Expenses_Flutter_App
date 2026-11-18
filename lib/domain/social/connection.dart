import 'account.dart';

enum ConnectionStatus { pending, accepted }

/// A two-way link between you and someone else. Bills can only be split
/// with people whose connection is [ConnectionStatus.accepted].
class Connection {
  const Connection({
    required this.id,
    required this.other,
    required this.status,
    required this.requestedByMe,
    required this.createdAt,
  });

  final String id;

  /// The other person.
  final Profile other;
  final ConnectionStatus status;
  final bool requestedByMe;
  final DateTime createdAt;

  bool get isAccepted => status == ConnectionStatus.accepted;

  /// Someone asked to connect with you and is waiting for an answer.
  bool get isIncomingRequest => status == ConnectionStatus.pending && !requestedByMe;

  bool get isOutgoingRequest => status == ConnectionStatus.pending && requestedByMe;

  /// The same id on both sides, so two people can only have one link.
  static String pairId(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';
}
