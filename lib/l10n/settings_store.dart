import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the app keeps the owner's choices that belong to this phone: the
/// language and the week layout today, a settings page later.
///
/// Reading is synchronous, so the first frame is already in the chosen
/// language. `main.dart` loads the phone's preferences before the app
/// starts and overrides [settingsStoreProvider] with a
/// [SharedPrefsSettingsStore]; without that (tests, a phone whose
/// preferences cannot be read) the app runs on a [MemorySettingsStore] and
/// simply forgets the choices when it closes.
abstract class SettingsStore {
  /// The saved value of [key], or `null` when nothing was saved.
  String? read(String key);

  /// Saves [value] under [key]; `null` removes it.
  Future<void> write(String key, String? value);
}

/// Keeps the settings in memory only. Also the fake used by tests: hand the
/// same instance to two app starts to simulate a restart.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  String? read(String key) => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

/// Keeps the settings in the phone's preferences.
class SharedPrefsSettingsStore implements SettingsStore {
  SharedPrefsSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  /// Loads the phone's preferences; `null` when they cannot be read.
  static Future<SettingsStore?> load() async {
    try {
      return SharedPrefsSettingsStore(await SharedPreferences.getInstance());
    } catch (_) {
      return null;
    }
  }

  @override
  String? read(String key) {
    final value = _prefs.get(key);
    return value is String ? value : null;
  }

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }
}

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => MemorySettingsStore(),
);
