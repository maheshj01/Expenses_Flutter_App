/// Whether the phone lets the app show notifications.
enum PushPermission {
  /// Never asked. Asking shows the system prompt.
  notAsked,
  granted,

  /// Refused; only the phone's Settings app can change it now.
  denied,
}

/// What a notification is about, so tapping it opens the right place.
enum PushTopic {
  /// Someone asked to connect with you.
  request,

  /// Someone accepted your request.
  accepted,

  /// Someone added you to a split bill.
  newBill,

  /// The payer changed a bill you're on (sent 5 minutes after the first
  /// of a burst of edits).
  billUpdated,
}

/// A notification that arrived while the app was open, or was tapped.
class PushMessage {
  const PushMessage({required this.topic, required this.title, required this.body, this.id});

  final PushTopic topic;
  final String title;
  final String body;

  /// The connection or bill id.
  final String? id;

  /// Reads the `data` the server sends (functions/src/notices.ts). Null for
  /// anything this version of the app doesn't know.
  static PushMessage? fromData(Map<String, Object?> data, {String? title, String? body}) {
    final topic = PushTopic.values.where((t) => t.name == data['topic']).firstOrNull;
    if (topic == null) return null;
    final id = data['id'];
    return PushMessage(
      topic: topic,
      title: title ?? '',
      body: body ?? '',
      id: id is String && id.isNotEmpty ? id : null,
    );
  }
}

/// Push notifications for sharing: connection requests, accepted requests
/// and new split bills. The server decides who hears what; the app only
/// asks permission, tells the backend where to deliver, and reacts to taps.
///
/// Like `SocialBackend`, the app only talks to this interface, so the push
/// provider can be swapped by writing one new implementation.
abstract interface class PushService {
  Future<PushPermission> permission();

  /// Shows the system prompt if it hasn't been answered yet.
  Future<PushPermission> requestPermission();

  /// Delivers notifications for [uid] to this device, keeping its address
  /// up to date while registered.
  Future<void> register(String uid);

  /// Stops delivering notifications for [uid] to this device. Call before
  /// signing out, while the account can still write.
  Future<void> unregister(String uid);

  /// Notifications that arrive while the app is open (the system doesn't
  /// show those itself).
  Stream<PushMessage> get received;

  /// Notifications tapped while the app was running in the background.
  Stream<PushMessage> get opened;

  /// The notification that launched the app, if any.
  Future<PushMessage?> launchMessage();
}
