/// How someone signs in to use sharing features.
enum SignInMethod {
  apple('Apple'),
  google('Google');

  const SignInMethod(this.label);

  final String label;

  SignInMethod get other => this == apple ? google : apple;
}

/// A signed-in (non-anonymous) account. Personal tracking works without
/// one; it is needed to back up and to split bills with other people.
class Account {
  const Account({required this.uid, required this.method, this.email, this.suggestedName = ''});

  final String uid;
  final SignInMethod method;
  final String? email;

  /// Name the sign-in provider shared, used to pre-fill the profile.
  final String suggestedName;

  @override
  bool operator ==(Object other) =>
      other is Account && other.uid == uid && other.method == method && other.email == email;

  @override
  int get hashCode => Object.hash(uid, method, email);
}

/// How other people see you: a unique handle plus a display name.
class Profile {
  const Profile({required this.uid, required this.handle, required this.name});

  final String uid;

  /// Unique, lowercase, without the leading `@`.
  final String handle;
  final String name;

  String get displayName => name.isEmpty ? '@$handle' : name;

  String get initials {
    final words = displayName.replaceAll('@', '').trim().split(RegExp(r'\s+'));
    final letters = words.where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase());
    return letters.isEmpty ? '?' : letters.join();
  }

  Map<String, Object?> toJson() => {'handle': handle, 'name': name};

  static Profile fromJson(String uid, Map<String, Object?> json) => Profile(
    uid: uid,
    handle: json['handle'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is Profile && other.uid == uid && other.handle == handle && other.name == name;

  @override
  int get hashCode => Object.hash(uid, handle, name);

  @override
  String toString() => 'Profile(@$handle)';
}

/// Rules for usernames, shared by the UI and every backend.
abstract final class Handle {
  static const minLength = 3;
  static const maxLength = 20;
  static final _pattern = RegExp(r'^[a-z][a-z0-9_.]*$');

  /// Lowercases and strips spaces and a leading `@`.
  static String normalize(String input) =>
      input.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '').replaceAll(' ', '');

  /// Returns a message explaining what is wrong, or null when [handle]
  /// (already normalized) is valid.
  static String? validate(String handle) {
    if (handle.length < minLength) return 'At least $minLength characters';
    if (handle.length > maxLength) return 'At most $maxLength characters';
    if (!RegExp(r'^[a-z]').hasMatch(handle)) return 'Start with a letter';
    if (!_pattern.hasMatch(handle)) return 'Letters, numbers, _ and . only';
    if (handle.endsWith('.') || handle.contains('..')) return 'Dots can’t end it or repeat';
    return null;
  }

  /// A starting suggestion built from a name, e.g. "Maya Rao" -> "mayarao".
  static String suggest(String name) {
    final base = normalize(name).replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    final trimmed = base.replaceFirst(RegExp(r'^[^a-z]+'), '');
    return trimmed.length > maxLength ? trimmed.substring(0, maxLength) : trimmed;
  }
}
