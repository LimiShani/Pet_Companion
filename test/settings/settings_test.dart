import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/config/app_config.dart';
import 'package:pet_companion/features/settings/settings_screen.dart';
import 'package:pet_companion/features/settings/widgets/legal_links.dart';
import 'package:pet_companion/features/settings/widgets/week_choice.dart';
import 'package:pet_companion/features/settings/you_screen.dart';
import 'package:pet_companion/notifications/widgets/notification_settings_card.dart';
import 'package:pet_companion/platform/link_opener.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/widgets/language_choice.dart';

import '../helpers.dart';
import 'settings_test_helpers.dart';

// The Settings page (three rows: Language, Week, Notifications) and the
// Language and Week pages behind it, reached through the You page, in
// English and in Hebrew. The About page (legal links) is here too.

final _en = lookupAppL10n(englishLocale);
final _he = lookupAppL10n(hebrewLocale);

Key _language(AppLanguage language) => LanguageChoice.keyOf(language);

bool _firstDayChosen(WidgetTester tester, int day) =>
    tester.widget<ChoiceChip>(find.byKey(WeekChoice.firstDayKey(day))).selected;

NotificationsL10n _notificationsOf(AppLanguage language) =>
    lookupNotificationsL10n(language == AppLanguage.hebrew ? hebrewLocale : englishLocale);

/// One step back with the header's arrow.
Future<void> _back(WidgetTester tester, AppL10n l10n) async {
  await tester.tap(find.byTooltip(l10n.commonBack));
  await settle(tester);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('the page', () {
    testWidgetsInBothLanguages('shows three rows with the current choices, and no controls', (tester, language) async {
      final l10n = stringsOf(language);
      final hebrew = language == AppLanguage.hebrew;
      await pumpHome(tester, language: language);
      await openSettingsFromYou(tester, l10n);

      expect(find.text(l10n.settingsTitle), findsOneWidget);
      expect(Directionality.of(tester.element(settingsPage)), hebrew ? TextDirection.rtl : TextDirection.ltr);
      // The back arrow is at the start: the left in English, the right in Hebrew.
      final back = tester.getCenter(find.byTooltip(l10n.commonBack)).dx;
      expect(back, hebrew ? greaterThan(phone.width / 2) : lessThan(phone.width / 2));

      // Language, Week and Notifications, one under the other.
      double y(Key key) => tester.getCenter(find.byKey(key)).dy;
      expect(y(SettingsScreen.languageKey), lessThan(y(SettingsScreen.weekKey)));
      expect(y(SettingsScreen.weekKey), lessThan(y(SettingsScreen.notificationsKey)));
      expect(find.text(l10n.accountLanguage), findsOneWidget);
      expect(find.text(l10n.settingsWeek), findsOneWidget);
      expect(find.text(_notificationsOf(language).sectionTitle), findsOneWidget);

      // Under each, the current choice: the language in its own letters,
      // the Israeli week, and every reminder on without quiet hours.
      expect(subtitleOf(tester, SettingsScreen.languageKey), hebrew ? 'עברית' : 'English');
      expect(
        subtitleOf(tester, SettingsScreen.weekKey),
        l10n.settingsWeekSummary(l10n.settingsDaySunday, l10n.settingsWeekdaysSunThu),
      );
      expect(subtitleOf(tester, SettingsScreen.notificationsKey), _notificationsOf(language).summaryQuietOff);
      expect(find.text(l10n.settingsSavedNote), findsOneWidget);

      // The controls themselves are on the pages behind the rows.
      expect(find.byType(LanguageChoice), findsNothing);
      expect(find.byType(WeekChoice), findsNothing);
      expect(find.byType(NotificationSettingsCard), findsNothing);
      expect(find.text(l10n.languageNote), findsNothing);
      expect(find.text(l10n.settingsWeekNote), findsNothing);
    });

    testWidgets('in English the rows read "Starts on Sunday · Sunday to Thursday" and "Reminders on · quiet hours off"', (
      tester,
    ) async {
      await pumpHome(tester);
      await openSettingsFromYou(tester, _en);

      // No choice was made yet: the app follows the phone, English here.
      expect(subtitleOf(tester, SettingsScreen.languageKey), 'Follow the phone · English');
      expect(subtitleOf(tester, SettingsScreen.weekKey), 'Starts on Sunday · Sunday to Thursday');
      expect(subtitleOf(tester, SettingsScreen.notificationsKey), 'Reminders on · quiet hours off');
    });

    testWidgetsInBothLanguages('each row opens its page; back returns to Settings', (tester, language) async {
      final l10n = stringsOf(language);
      final notifications = _notificationsOf(language);
      await pumpHome(tester, language: language);
      await openSettingsFromYou(tester, l10n);

      for (final (row, page, title, control, note) in [
        (SettingsScreen.languageKey, languagePage, l10n.accountLanguage, find.byType(LanguageChoice), l10n.languageNote),
        (SettingsScreen.weekKey, weekPage, l10n.settingsWeek, find.byType(WeekChoice), l10n.settingsWeekNote),
        (
          SettingsScreen.notificationsKey,
          notificationsPage,
          notifications.sectionTitle,
          find.byType(NotificationSettingsCard),
          null,
        ),
      ]) {
        await openSettingsRow(tester, row, page);
        expect(settingsPage, findsNothing);
        expect(find.text(title), findsOneWidget, reason: title);
        expect(control, findsOneWidget, reason: title);
        if (note != null) expect(find.text(note), findsOneWidget, reason: title);

        await _back(tester, l10n);
        expect(page, findsNothing);
        expect(settingsPage, findsOneWidget);
      }
    });

    testWidgets('the day letters run from Sunday, with Friday and Saturday as the weekend', (tester) async {
      await pumpHome(tester);
      await openWeekFromYou(tester, _en);

      expect(previewLetters(tester), ['S', 'M', 'T', 'W', 'T', 'F', 'S']);
      expect(find.bySemanticsLabel(_en.settingsWeekendIs('Fri, Sat')), findsOneWidget);
    });

    testWidgets('in Hebrew the day letters start with Sunday on the right', (tester) async {
      await pumpHome(tester, language: AppLanguage.hebrew);
      await openWeekFromYou(tester, _he);

      // Read from the right: א׳ (Sunday) to ש׳ (Saturday).
      expect(previewLetters(tester).reversed, ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳']);
      const format = AppFormat('he');
      final weekend = '${format.weekdayShort(DateTime.friday)}, ${format.weekdayShort(DateTime.saturday)}';
      expect(find.bySemanticsLabel(_he.settingsWeekendIs(weekend)), findsOneWidget);
    });
  });

  group('language', () {
    testWidgetsInBothLanguages('the page shows the choices and the note', (tester, language) async {
      final l10n = stringsOf(language);
      await pumpHome(tester, language: language);
      await openLanguageFromYou(tester, l10n);

      // Each language in its own letters, whatever the screen's.
      expect(find.text(l10n.accountLanguage), findsOneWidget);
      expect(find.text('עברית'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(isChosen(tester, _language(language)), isTrue);
      expect(find.text(l10n.languageNote), findsOneWidget);
    });

    testWidgets('a choice switches the whole app at once, shows on the Settings row and survives a restart', (
      tester,
    ) async {
      final store = MemorySettingsStore();
      await pumpHome(tester, settings: store);
      await openLanguageFromYou(tester, _en);

      expect(find.text('Language'), findsOneWidget);
      // No choice was made yet: the app follows the phone, English here.
      expect(isChosen(tester, _language(AppLanguage.system)), isTrue);
      expect(isChosen(tester, _language(AppLanguage.english)), isFalse);
      expect(isChosen(tester, _language(AppLanguage.hebrew)), isFalse);

      await tapOnSettings(tester, find.byKey(_language(AppLanguage.hebrew)));

      // The page itself is in Hebrew now, right to left.
      expect(find.text('שפה'), findsOneWidget);
      expect(find.text('Language'), findsNothing);
      expect(Directionality.of(tester.element(languagePage)), TextDirection.rtl);
      expect(isChosen(tester, _language(AppLanguage.hebrew)), isTrue);
      expect(store.values, {languageSettingKey: 'he'});

      // And so are Settings (whose row names the new language), the You
      // page and Home behind it.
      await _back(tester, _he);
      expect(find.text('הגדרות'), findsOneWidget);
      expect(find.text('שבוע'), findsOneWidget);
      expect(subtitleOf(tester, SettingsScreen.languageKey), 'עברית');
      await _back(tester, _he);
      expect(find.text('יציאה מהחשבון'), findsOneWidget);
      await _back(tester, _he);
      expect(find.text('האכלה'), findsOneWidget);
      expect(find.text('Feeding'), findsNothing);

      // Close the app and open it again with the same saved choices.
      await pumpHome(tester, settings: store);
      expect(find.text('האכלה'), findsOneWidget);

      // Back to English.
      await openLanguageFromYou(tester, _he);
      await tapOnSettings(tester, find.byKey(_language(AppLanguage.english)));
      expect(find.text('Language'), findsOneWidget);
      expect(store.values, {languageSettingKey: 'en'});
      await _back(tester, _en);
      expect(find.text('Settings'), findsOneWidget);
      expect(subtitleOf(tester, SettingsScreen.languageKey), 'English');
    });

    testWidgets('"Follow the phone" is offered and Hebrew is no longer tagged as a preview', (tester) async {
      await pumpHome(tester);
      await openLanguageFromYou(tester, _en);

      expect(find.byKey(_language(AppLanguage.system)), findsOneWidget);
      expect(find.text('Preview'), findsNothing);
    });

    testWidgets('once Hebrew follows the phone, a Hebrew phone starts in Hebrew and may choose otherwise', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('he', 'IL')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.view.physicalSize = phone * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final store = MemorySettingsStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
            settingsStoreProvider.overrideWithValue(store),
            hebrewFollowsDeviceProvider.overrideWithValue(true),
          ],
          child: const PetLoopApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('טוב לראות אותך שוב'), findsOneWidget);

      await signInAsDemo(tester);
      await settle(tester);
      await openSettingsFromYou(tester, _he);
      expect(subtitleOf(tester, SettingsScreen.languageKey), _he.settingsLanguageFollowing('עברית'));
      await openSettingsRow(tester, SettingsScreen.languageKey, languagePage);

      // Three choices now, and no "preview" tag.
      expect(find.text('לפי שפת המכשיר'), findsOneWidget);
      expect(find.text(_he.languageFollowPhoneNow('עברית')), findsOneWidget);
      expect(isChosen(tester, _language(AppLanguage.system)), isTrue);
      expect(find.text('בהרצה'), findsNothing);

      await tapOnSettings(tester, find.byKey(_language(AppLanguage.english)));
      expect(find.text('Follow the phone'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(store.values, {languageSettingKey: 'en'});

      await tapOnSettings(tester, find.byKey(_language(AppLanguage.system)));
      expect(find.text('שפה'), findsOneWidget);
      expect(store.values, isEmpty);
    });
  });

  group('week', () {
    testWidgetsInBothLanguages('the page shows the first day, the weekdays and the note', (tester, language) async {
      final l10n = stringsOf(language);
      await pumpHome(tester, language: language);
      await openWeekFromYou(tester, l10n);

      // The Israeli week unless the owner chose otherwise.
      expect(find.text(l10n.settingsWeek), findsOneWidget);
      expect(find.text(l10n.settingsFirstDay), findsOneWidget);
      for (final day in [l10n.settingsDaySaturday, l10n.settingsDaySunday, l10n.settingsDayMonday]) {
        expect(find.widgetWithText(ChoiceChip, day), findsOneWidget);
      }
      expect(_firstDayChosen(tester, DateTime.sunday), isTrue);
      expect(_firstDayChosen(tester, DateTime.saturday), isFalse);
      expect(_firstDayChosen(tester, DateTime.monday), isFalse);
      expect(find.text(l10n.settingsWeekdays), findsOneWidget);
      expect(find.text(l10n.settingsWeekdaysSunThu), findsOneWidget);
      expect(find.text(l10n.settingsWeekdaysMonFri), findsOneWidget);
      expect(isChosen(tester, WeekChoice.sundayToThursdayKey), isTrue);
      expect(isChosen(tester, WeekChoice.mondayToFridayKey), isFalse);
      expect(find.text(l10n.settingsWeekNote), findsOneWidget);
    });

    testWidgets('the first day reorders the week at once and is remembered', (tester) async {
      final store = MemorySettingsStore();
      await pumpHome(tester, settings: store);
      await openWeekFromYou(tester, _en);

      await tapOnSettings(tester, find.byKey(WeekChoice.firstDayKey(DateTime.monday)));
      expect(_firstDayChosen(tester, DateTime.monday), isTrue);
      expect(_firstDayChosen(tester, DateTime.sunday), isFalse);
      expect(previewLetters(tester), ['M', 'T', 'W', 'T', 'F', 'S', 'S']);
      expect(weekOf(tester).firstDay, DateTime.monday);
      // The weekdays were not touched.
      expect(weekOf(tester).weekdays, WeekSettings.israeli.weekdays);
      expect(store.values, {weekFirstDaySettingKey: '1'});

      await tapOnSettings(tester, find.byKey(WeekChoice.firstDayKey(DateTime.saturday)));
      expect(previewLetters(tester), ['S', 'S', 'M', 'T', 'W', 'T', 'F']);
      expect(store.values, {weekFirstDaySettingKey: '6'});
    });

    testWidgets('the weekdays move the weekend at once and are remembered', (tester) async {
      final store = MemorySettingsStore();
      await pumpHome(tester, settings: store);
      await openWeekFromYou(tester, _en);
      expect(find.bySemanticsLabel(_en.settingsWeekendIs('Fri, Sat')), findsOneWidget);

      await tapOnSettings(tester, find.byKey(WeekChoice.mondayToFridayKey));
      expect(isChosen(tester, WeekChoice.mondayToFridayKey), isTrue);
      expect(isChosen(tester, WeekChoice.sundayToThursdayKey), isFalse);
      // The week still starts on Sunday, so Sunday is the first weekend day.
      expect(find.bySemanticsLabel(_en.settingsWeekendIs('Sun, Sat')), findsOneWidget);
      expect(weekOf(tester).weekdays, WeekSettings.mondayToFriday.weekdays);
      expect(weekOf(tester).firstDay, DateTime.sunday);
      expect(store.values, {weekWeekdaysSettingKey: '1,2,3,4,5'});

      await tapOnSettings(tester, find.byKey(WeekChoice.sundayToThursdayKey));
      expect(isChosen(tester, WeekChoice.sundayToThursdayKey), isTrue);
      expect(find.bySemanticsLabel(_en.settingsWeekendIs('Fri, Sat')), findsOneWidget);
      expect(store.values, {weekWeekdaysSettingKey: '1,2,3,4,7'});
    });

    testWidgetsInBothLanguages('a change shows on the Settings row', (tester, language) async {
      final l10n = stringsOf(language);
      await pumpHome(tester, language: language);
      await openWeekFromYou(tester, l10n);
      await tapOnSettings(tester, find.byKey(WeekChoice.firstDayKey(DateTime.monday)));
      await tapOnSettings(tester, find.byKey(WeekChoice.mondayToFridayKey));

      await _back(tester, l10n);
      expect(
        subtitleOf(tester, SettingsScreen.weekKey),
        l10n.settingsWeekSummary(l10n.settingsDayMonday, l10n.settingsWeekdaysMonFri),
      );
    });

    testWidgets('both choices survive a restart', (tester) async {
      final store = MemorySettingsStore();
      await pumpHome(tester, settings: store);
      await openWeekFromYou(tester, _en);
      await tapOnSettings(tester, find.byKey(WeekChoice.firstDayKey(DateTime.monday)));
      await tapOnSettings(tester, find.byKey(WeekChoice.mondayToFridayKey));

      // Close the app and open it again with the same saved choices.
      await pumpHome(tester, settings: store);
      await openSettingsFromYou(tester, _en);
      expect(subtitleOf(tester, SettingsScreen.weekKey), 'Starts on Monday · Monday to Friday');
      await openSettingsRow(tester, SettingsScreen.weekKey, weekPage);

      expect(_firstDayChosen(tester, DateTime.monday), isTrue);
      expect(isChosen(tester, WeekChoice.mondayToFridayKey), isTrue);
      expect(previewLetters(tester), ['M', 'T', 'W', 'T', 'F', 'S', 'S']);
      expect(find.bySemanticsLabel(_en.settingsWeekendIs('Sat, Sun')), findsOneWidget);
      expect(weekOf(tester), WeekSettings.mondayToFriday);
    });

    testWidgets('a week saved earlier is what the page shows, in Hebrew too', (tester) async {
      final store = MemorySettingsStore({
        languageSettingKey: 'he',
        weekFirstDaySettingKey: '1',
        weekWeekdaysSettingKey: '1,2,3,4,5',
      });
      await pumpHome(tester, settings: store);
      await openWeekFromYou(tester, _he);

      expect(_firstDayChosen(tester, DateTime.monday), isTrue);
      expect(isChosen(tester, WeekChoice.mondayToFridayKey), isTrue);
      // Read from the right: Monday (ב׳) first, Sunday (א׳) last.
      expect(previewLetters(tester).reversed, ['ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳', 'א׳']);
    });

    testWidgets('the language does not change the week', (tester) async {
      final store = MemorySettingsStore();
      await pumpHome(tester, settings: store);
      await openLanguageFromYou(tester, _en);
      await tapOnSettings(tester, find.byKey(_language(AppLanguage.hebrew)));
      expect(weekOf(tester), WeekSettings.israeli);

      await _back(tester, _he);
      await openSettingsRow(tester, SettingsScreen.weekKey, weekPage);
      expect(_firstDayChosen(tester, DateTime.sunday), isTrue);
      expect(isChosen(tester, WeekChoice.sundayToThursdayKey), isTrue);
    });
  });

  group('notifications', () {
    testWidgetsInBothLanguages('a change on the page shows on the Settings row', (tester, language) async {
      final l10n = stringsOf(language);
      final notifications = _notificationsOf(language);
      await pumpHome(tester, language: language);
      await openSettingsFromYou(tester, l10n);
      await openSettingsRow(tester, SettingsScreen.notificationsKey, notificationsPage);

      await tapOnSettings(tester, find.byKey(NotificationSettingsCard.quietHoursKey));
      await _back(tester, l10n);
      expect(subtitleOf(tester, SettingsScreen.notificationsKey), notifications.summaryQuietOn);

      await openSettingsRow(tester, SettingsScreen.notificationsKey, notificationsPage);
      await tapOnSettings(tester, find.byKey(NotificationSettingsCard.masterKey));
      await _back(tester, l10n);
      expect(subtitleOf(tester, SettingsScreen.notificationsKey), notifications.summaryOff);
    });
  });

  group('the You page', () {
    testWidgetsInBothLanguages('holds the account and the way to Settings; the language list is not there', (
      tester,
      language,
    ) async {
      final l10n = stringsOf(language);
      await pumpHome(tester, language: language);
      await openYou(tester, l10n);

      expect(find.text('Alex'), findsOneWidget);
      expect(find.text(FakeAuthRepository.demoEmail), findsOneWidget);
      expect(find.byKey(YouScreen.settingsKey), findsOneWidget);
      expect(find.text(l10n.settingsTitle), findsOneWidget);
      expect(find.text(l10n.settingsSummary), findsOneWidget);
      // The language list lives behind the Settings page only.
      expect(find.byType(LanguageChoice), findsNothing);
      expect(find.text(l10n.accountLanguage), findsNothing);
    });

    testWidgetsInBothLanguages('its Settings row opens the page; one step back is the You page', (
      tester,
      language,
    ) async {
      final l10n = stringsOf(language);
      await pumpHome(tester, language: language);
      await openSettingsFromYou(tester, l10n);

      expect(youPage, findsNothing);
      expect(find.byKey(SettingsScreen.languageKey), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(settingsPage, findsNothing);
      expect(youPage, findsOneWidget);
      expect(find.byKey(SettingsScreen.languageKey), findsNothing);
    });
  });

  group('fits', () {
    for (final textScale in const [1.0, 1.3]) {
      testWidgetsInBothLanguages('Settings and its pages on a small phone, text x$textScale', (tester, language) async {
        final l10n = stringsOf(language);
        await pumpHome(tester, language: language, size: smallPhone, textScale: textScale);

        await openYou(tester, l10n);
        await tester.ensureVisible(find.byKey(YouScreen.settingsKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(YouScreen.settingsKey));
        await settle(tester);
        expect(settingsPage, findsOneWidget);
        expect(tester.takeException(), isNull);

        // Every row can be reached and opened.
        await openSettingsRow(tester, SettingsScreen.notificationsKey, notificationsPage);
        await tester.ensureVisible(find.byKey(NotificationSettingsCard.quietHoursKey));
        await tester.pumpAndSettle();
        await _back(tester, l10n);

        // Every week control can be reached and used; the page scrolls.
        await openSettingsRow(tester, SettingsScreen.weekKey, weekPage);
        await tapOnSettings(tester, find.byKey(WeekChoice.firstDayKey(DateTime.monday)));
        await tapOnSettings(tester, find.byKey(WeekChoice.mondayToFridayKey));
        await tester.ensureVisible(find.text(l10n.settingsWeekNote));
        await tester.pumpAndSettle();
        expect(weekOf(tester), WeekSettings.mondayToFriday);
        expect(previewLetters(tester), hasLength(7));
        await _back(tester, l10n);

        // Switching the language must fit as well.
        final other = language == AppLanguage.hebrew ? AppLanguage.english : AppLanguage.hebrew;
        await openSettingsRow(tester, SettingsScreen.languageKey, languagePage);
        await tapOnSettings(tester, find.byKey(_language(other)));
        expect(find.text(stringsOf(other).accountLanguage), findsOneWidget);
        await tester.ensureVisible(find.text(stringsOf(other).languageNote));
        await tester.pumpAndSettle();
        await _back(tester, stringsOf(other));
        expect(find.text(stringsOf(other).settingsTitle), findsOneWidget);
        await tester.ensureVisible(find.text(stringsOf(other).settingsSavedNote));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('About PetLoop', () {
    testWidgets('opens the Terms of Use and the Privacy Policy in the browser', (tester) async {
      final opener = RecordingLinkOpener();
      await pumpApp(tester, overrides: [linkOpenerProvider.overrideWithValue(opener)]);
      await signInAsDemo(tester);
      await settle(tester);
      await openAboutFromYou(tester, _en);

      expect(find.text(_en.aboutTitle), findsOneWidget);
      await tester.ensureVisible(find.byKey(LegalLinks.termsKey));
      await tester.tap(find.byKey(LegalLinks.termsKey));
      await tester.tap(find.byKey(LegalLinks.privacyKey));
      await tester.pump();

      expect(opener.opened, [AppConfig.termsUrl('en'), AppConfig.privacyUrl('en')]);
    });

    testWidgets('in Hebrew it opens the Hebrew pages, and says when a page would not open', (tester) async {
      final opener = RecordingLinkOpener()..succeeds = false;
      await pumpApp(
        tester,
        language: AppLanguage.hebrew,
        overrides: [linkOpenerProvider.overrideWithValue(opener)],
      );
      await signInAsDemo(tester);
      await settle(tester);
      await openAboutFromYou(tester, _he);

      await tester.ensureVisible(find.byKey(LegalLinks.privacyKey));
      await tester.tap(find.byKey(LegalLinks.privacyKey));
      await tester.pump();

      expect(opener.opened.single.toString(), endsWith('/legal/privacy.he.html'));
      expect(find.text(_he.legalOpenFailed), findsOneWidget);
    });
  });
}
