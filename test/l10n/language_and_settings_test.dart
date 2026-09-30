import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container(SettingsStore store) {
  final container = ProviderContainer(overrides: [settingsStoreProvider.overrideWithValue(store)]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which language the app shows', () {
    const hebrewPhone = [Locale('he', 'IL'), Locale('en', 'US')];
    const oldAndroidHebrewPhone = [Locale('iw', 'IL')];
    const englishPhone = [Locale('en', 'US'), Locale('he', 'IL')];
    const russianPhone = [Locale('ru', 'RU')];

    test('the owner\'s choice wins over the phone', () {
      expect(resolveAppLocale(AppLanguage.hebrew, englishPhone, hebrewFollowsDevice: true), hebrewLocale);
      expect(resolveAppLocale(AppLanguage.english, hebrewPhone, hebrewFollowsDevice: true), englishLocale);
      expect(resolveAppLocale(AppLanguage.hebrew, russianPhone, hebrewFollowsDevice: false), hebrewLocale);
    });

    test('with no choice, Hebrew on a Hebrew phone and English on any other', () {
      expect(resolveAppLocale(AppLanguage.system, hebrewPhone, hebrewFollowsDevice: true), hebrewLocale);
      expect(resolveAppLocale(AppLanguage.system, oldAndroidHebrewPhone, hebrewFollowsDevice: true), hebrewLocale);
      // Hebrew as a second language does not count: the first one decides.
      expect(resolveAppLocale(AppLanguage.system, englishPhone, hebrewFollowsDevice: true), englishLocale);
      expect(resolveAppLocale(AppLanguage.system, russianPhone, hebrewFollowsDevice: true), englishLocale);
      expect(resolveAppLocale(AppLanguage.system, const [], hebrewFollowsDevice: true), englishLocale);
    });

    test('with the switch off a Hebrew phone starts in English; today the switch is on', () {
      expect(resolveAppLocale(AppLanguage.system, hebrewPhone, hebrewFollowsDevice: false), englishLocale);
      expect(_container(MemorySettingsStore()).read(hebrewFollowsDeviceProvider), isTrue);
    });

    test('each language is named in its own letters', () {
      expect(nativeLanguageName(hebrewLocale), 'עברית');
      expect(nativeLanguageName(englishLocale), 'English');
    });
  });

  group('the remembered language', () {
    test('nothing saved means no choice, and the app is in English', () {
      final container = _container(MemorySettingsStore());
      expect(container.read(appLanguageProvider), AppLanguage.system);
      expect(container.read(appLocaleProvider), englishLocale);
    });

    test('a choice applies at once, is saved, and is read back by the next start', () async {
      final store = MemorySettingsStore();
      final first = _container(store);
      await first.read(appLanguageProvider.notifier).choose(AppLanguage.hebrew);
      expect(first.read(appLocaleProvider), hebrewLocale);
      expect(store.values, {languageSettingKey: 'he'});

      // A new container on the same store: the app was closed and opened.
      final second = _container(store);
      expect(second.read(appLanguageProvider), AppLanguage.hebrew);
      expect(second.read(appLocaleProvider), hebrewLocale);
    });

    test('going back to "follow the phone" forgets the choice', () async {
      final store = MemorySettingsStore({languageSettingKey: 'he'});
      final container = _container(store);
      await container.read(appLanguageProvider.notifier).choose(AppLanguage.system);
      expect(store.values, isEmpty);
      expect(container.read(appLanguageProvider), AppLanguage.system);
    });

    test('an unreadable saved value is treated as no choice', () {
      expect(_container(MemorySettingsStore({languageSettingKey: 'xx'})).read(appLanguageProvider), AppLanguage.system);
    });

    test('a store that cannot save still switches the language for this session', () async {
      final container = _container(_BrokenStore());
      await container.read(appLanguageProvider.notifier).choose(AppLanguage.hebrew);
      expect(container.read(appLocaleProvider), hebrewLocale);
    });

    test('the strings providers follow the language', () async {
      final container = _container(MemorySettingsStore());
      expect(container.read(appL10nProvider).navHome, 'Home');
      expect(container.read(healthL10nProvider).tabTitle, 'Health');
      await container.read(appLanguageProvider.notifier).choose(AppLanguage.hebrew);
      expect(container.read(appL10nProvider).navHome, 'בית');
      expect(container.read(healthL10nProvider).tabTitle, 'בריאות');
      expect(container.read(communityL10nProvider).tabTitle, 'קהילה');
      expect(container.read(storeL10nProvider).tabTitle, 'חנות');
      expect(container.read(petsL10nProvider).myPetsTitle, 'החיות שלי');
      expect(container.read(appFormatProvider).localeName, 'he');
    });
  });

  group('the phone\'s own preferences', () {
    test('values written are there after the preferences are loaded again', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await SharedPrefsSettingsStore.load();
      expect(store, isNotNull);
      expect(store!.read(languageSettingKey), isNull);

      await store.write(languageSettingKey, 'he');
      expect(store.read(languageSettingKey), 'he');

      final again = await SharedPrefsSettingsStore.load();
      expect(again!.read(languageSettingKey), 'he');

      await again.write(languageSettingKey, null);
      expect((await SharedPrefsSettingsStore.load())!.read(languageSettingKey), isNull);
    });

    test('a saved value of another kind is ignored', () async {
      SharedPreferences.setMockInitialValues({languageSettingKey: 7});
      final store = await SharedPrefsSettingsStore.load();
      expect(store!.read(languageSettingKey), isNull);
    });
  });

  group('the week', () {
    test('is the Israeli week by default, in every language', () async {
      final container = _container(MemorySettingsStore());
      final week = container.read(weekSettingsProvider);
      expect(week, WeekSettings.israeli);
      expect(week.firstDay, DateTime.sunday);
      expect(week.orderedDays, [
        DateTime.sunday,
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
      ]);
      expect(week.weekdays, {7, 1, 2, 3, 4});
      expect(week.weekend, {DateTime.friday, DateTime.saturday});

      await container.read(appLanguageProvider.notifier).choose(AppLanguage.hebrew);
      expect(container.read(weekSettingsProvider), WeekSettings.israeli);
    });

    test('recognises "weekdays", "weekend" and "every day" for the layout in use', () {
      const israeli = WeekSettings.israeli;
      expect(israeli.isWeekdays({1, 2, 3, 4, 7}), isTrue);
      expect(israeli.isWeekdays({1, 2, 3, 4, 5}), isFalse);
      expect(israeli.isWeekend({5, 6}), isTrue);
      expect(israeli.isWeekend({6, 7}), isFalse);
      expect(israeli.isEveryDay({1, 2, 3, 4, 5, 6, 7}), isTrue);

      const monday = WeekSettings.mondayToFriday;
      expect(monday.orderedDays.first, DateTime.monday);
      expect(monday.isWeekdays({1, 2, 3, 4, 5}), isTrue);
      expect(monday.isWeekend({6, 7}), isTrue);
    });

    test('orders days as the week runs', () {
      expect(WeekSettings.israeli.sorted({1, 7, 4}), [7, 1, 4]);
      expect(WeekSettings.mondayToFriday.sorted({1, 7, 4}), [1, 4, 7]);
    });

    test('a changed layout is saved and read back by the next start', () async {
      final store = MemorySettingsStore();
      final first = _container(store);
      await first.read(weekSettingsProvider.notifier).use(WeekSettings.mondayToFriday);
      expect(first.read(weekSettingsProvider), WeekSettings.mondayToFriday);
      expect(store.values, {weekFirstDaySettingKey: '1', weekWeekdaysSettingKey: '1,2,3,4,5'});

      final second = _container(store);
      expect(second.read(weekSettingsProvider), WeekSettings.mondayToFriday);
    });

    test('the first day and the weekdays are set separately', () async {
      final store = MemorySettingsStore();
      final container = _container(store);
      await container.read(weekSettingsProvider.notifier).setFirstDay(DateTime.saturday);
      final week = container.read(weekSettingsProvider);
      expect(week.firstDay, DateTime.saturday);
      expect(week.orderedDays.first, DateTime.saturday);
      expect(week.weekdays, WeekSettings.israeli.weekdays);
      expect(store.values, {weekFirstDaySettingKey: '6'});
    });

    test('nonsense in the store falls back to the default', () {
      final container = _container(
        MemorySettingsStore({weekFirstDaySettingKey: '9', weekWeekdaysSettingKey: '1,two,3'}),
      );
      expect(container.read(weekSettingsProvider), WeekSettings.israeli);

      final allSeven = _container(MemorySettingsStore({weekWeekdaysSettingKey: '1,2,3,4,5,6,7'}));
      expect(allSeven.read(weekSettingsProvider).weekdays, WeekSettings.israeli.weekdays);
    });
  });
}

class _BrokenStore implements SettingsStore {
  @override
  String? read(String key) => null;

  @override
  Future<void> write(String key, String? value) => Future.error(StateError('no storage'));
}
