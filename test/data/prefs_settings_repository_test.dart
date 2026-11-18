import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_bucks/data/local/prefs_settings_repository.dart';

void main() {
  Future<PrefsSettingsRepository> repo(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return PrefsSettingsRepository(await SharedPreferences.getInstance());
  }

  test('the old "split with" name becomes the first saved person', () async {
    final r = await repo({'onboarded': true, 'splitWith': ' Alex '});
    final s = r.load();
    expect(s.savedGuests, ['Alex']);
    expect(s.splitsBills, isTrue);

    await r.save(s.copyWith(savedGuests: s.withGuests(['alex', 'Sam'])));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('splitWith'), isFalse);
    expect(r.load().savedGuests, ['Alex', 'Sam'], reason: 'names are unique, ignoring case');
  });

  test('nothing to migrate means no saved people', () async {
    final s = (await repo({})).load();
    expect(s.savedGuests, isEmpty);
    expect(s.splitsBills, isFalse);
  });
}
