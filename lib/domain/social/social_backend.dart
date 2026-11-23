import 'account.dart';
import 'connection.dart';
import 'safety.dart';
import 'settlement.dart';
import 'shared_bill.dart';

/// Everything sharing needs from a backend: accounts, usernames,
/// connections, shared bills, settlements, and blocking and reporting.
///
/// Like `RemoteStore` for personal data, the app only talks to this
/// interface, so Firebase can be swapped for another backend by writing one
/// new implementation.
///
/// Writes return once the change is accepted locally. Implementations should
/// queue them while offline and deliver them when the network returns.
abstract interface class SocialBackend {
  /// Human readable name, e.g. "Firebase".
  String get displayName;

  /// Sign-in options this device supports.
  List<SignInMethod> get signInMethods;

  // ---- account ----

  /// The signed-in account, or null when using the app without one.
  Stream<Account?> watchAccount();

  Account? get currentAccount;

  /// Signs in, keeping data made before signing in. Throws
  /// [SignInCancelled] if the user backs out.
  Future<void> signIn(SignInMethod method);

  /// Signs out. Personal data stays on this device.
  Future<void> signOut();

  /// Deletes the account, username, connections and blocks. Bills already
  /// shared with others stay visible to them.
  ///
  /// Asks the user to confirm who they are first (throwing
  /// [SignInCancelled] if they back out, with nothing deleted), then runs
  /// [eraseData] to delete their other data before the sign-in itself goes.
  Future<void> deleteAccount({Future<void> Function()? eraseData});

  // ---- profile ----

  /// Your username and name, or null until you pick a username.
  Stream<Profile?> watchMyProfile();

  /// Reserves [handle] (normalized, valid) for the current account. Throws
  /// [HandleTaken] when someone else has it.
  Future<Profile> claimHandle(String handle, String name);

  /// Exact-match lookup. There is deliberately no search, so people can't
  /// browse who uses the app.
  Future<Profile?> findByHandle(String handle);

  // ---- connections ----

  Stream<List<Connection>> watchConnections();

  /// Asks [other] to connect. If they already asked you, this accepts.
  Future<void> requestConnection(Profile me, Profile other);

  Future<void> acceptConnection(String connectionId);

  /// Declines a request, cancels your own, or removes a connection.
  Future<void> removeConnection(String connectionId);

  // ---- bills ----

  /// Bills you are a member of, kept up to date.
  Stream<BillsSnapshot> watchBills();

  /// Creates or updates a bill you created, flags included: editing the
  /// amount or people should clear them (see [SharedBill.edited]).
  Future<void> saveBill(SharedBill bill);

  /// Flags (or with null, un-flags) your own share of a bill.
  Future<void> setFlag(String billId, BillFlag? flag);

  // ---- settlements ----

  Stream<List<Settlement>> watchSettlements();

  Future<void> addSettlement(Settlement settlement);

  /// Undoes a settlement you recorded.
  Future<void> deleteSettlement(String id);

  // ---- safety ----

  /// People you blocked, newest first.
  Stream<List<BlockedPerson>> watchBlocked();

  /// Blocks [other]: removes any connection or request with them, and stops
  /// them finding you, asking to connect, or sharing new bills with you.
  Future<void> block(Profile other);

  Future<void> unblock(String uid);

  /// Sends [report] to the app's moderators.
  Future<void> report(Report report);
}

class SignInCancelled implements Exception {
  const SignInCancelled();
}

class HandleTaken implements Exception {
  const HandleTaken(this.handle);

  final String handle;

  @override
  String toString() => '@$handle is taken';
}

/// A sharing action failed in a way worth telling the user about.
class SocialError implements Exception {
  const SocialError(this.message);

  final String message;

  @override
  String toString() => message;
}
