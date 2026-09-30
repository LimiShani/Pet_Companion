import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_store.dart';

/// The languages the app speaks.
const englishLocale = Locale('en');
const hebrewLocale = Locale('he');
const appSupportedLocales = [englishLocale, hebrewLocale];

/// What the owner chose in the language switch.
enum AppLanguage {
  /// No choice made: the app follows the phone (see [resolveAppLocale]).
  system(null),
  english('en'),
  hebrew('he');

  const AppLanguage(this.code);

  /// What is stored; `null` for [system], which is stored as "nothing".
  final String? code;

  static AppLanguage fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return AppLanguage.system;
  }
}

/// A language's name in its own letters, so its speakers can find it
/// whatever language the app is showing. Never translated.
String nativeLanguageName(Locale locale) => isHebrew(locale) ? 'עברית' : 'English';

/// Whether [locale] is Hebrew. Older Android versions report it as `iw`.
bool isHebrew(Locale locale) => locale.languageCode == 'he' || locale.languageCode == 'iw';

/// The key of the language choice in the [SettingsStore].
const languageSettingKey = 'app_language';

/// Whether a phone set to Hebrew starts the app in Hebrew. On since every
/// feature speaks Hebrew; while it was off, Hebrew was only a choice in
/// the switch, tagged "Preview". A provider so tests can exercise both.
final hebrewFollowsDeviceProvider = Provider<bool>((ref) => true);

/// The language the app shows: the owner's [choice], or for
/// [AppLanguage.system] Hebrew when the phone's first language is Hebrew
/// (once [hebrewFollowsDevice] is on) and English on any other phone.
Locale resolveAppLocale(AppLanguage choice, List<Locale> deviceLocales, {required bool hebrewFollowsDevice}) {
  switch (choice) {
    case AppLanguage.english:
      return englishLocale;
    case AppLanguage.hebrew:
      return hebrewLocale;
    case AppLanguage.system:
      final onHebrewPhone = deviceLocales.isNotEmpty && isHebrew(deviceLocales.first);
      return hebrewFollowsDevice && onHebrewPhone ? hebrewLocale : englishLocale;
  }
}

/// The owner's language choice, remembered on the phone.
class AppLanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => AppLanguage.fromCode(ref.watch(settingsStoreProvider).read(languageSettingKey));

  /// Switches the app to [language] at once and remembers it.
  Future<void> choose(AppLanguage language) async {
    state = language;
    try {
      await ref.read(settingsStoreProvider).write(languageSettingKey, language.code);
    } catch (_) {
      // The choice holds for this session; it just is not remembered.
    }
  }
}

final appLanguageProvider = NotifierProvider<AppLanguageController, AppLanguage>(AppLanguageController.new);

/// The phone's own languages, most preferred first, kept up to date when
/// the owner changes them in the phone's settings.
class DeviceLocales extends Notifier<List<Locale>> with WidgetsBindingObserver {
  @override
  List<Locale> build() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    return binding.platformDispatcher.locales;
  }

  @override
  void didChangeLocales(List<Locale>? locales) => state = locales ?? const [];
}

final deviceLocalesProvider = NotifierProvider<DeviceLocales, List<Locale>>(DeviceLocales.new);

/// The language the app is showing now.
final appLocaleProvider = Provider<Locale>(
  (ref) => resolveAppLocale(
    ref.watch(appLanguageProvider),
    ref.watch(deviceLocalesProvider),
    hebrewFollowsDevice: ref.watch(hebrewFollowsDeviceProvider),
  ),
);
