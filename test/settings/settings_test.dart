import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/auth/widgets/account_sheet.dart';
import 'package:pet_companion/config/app_config.dart';
import 'package:pet_companion/features/settings/widgets/legal_links.dart';
import 'package:pet_companion/features/settings/widgets/week_choice.dart';
import 'package:pet_companion/platform/link_opener.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/widgets/language_choice.dart';

import '../helpers.dart';
import 'settings_test_helpers.dart';

// The Settings page (Language and Week) and the account sheet that leads
// to it, in English and in Hebrew.

final _en = lookupAppL10n(englishLocale);
final _he = lookupAppL10n(hebrewLocale);

Key _language(AppLanguage language) => LanguageChoice.keyOf(language);

bool _firstDayChosen(WidgetTester tester, int day) =>
    tester.widget<ChoiceChip>(find.byKey(WeekChoice.firstDayKey(day))).selected;

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('the page', () {
    testWidgetsInBothLanguages('shows Language and Week with their controls', (tester, language) async {
      final l10n = stringsOf(language);
      final hebrew = language == AppLanguage.hebrew;
      await pumpHome(tester, language: language);
      await openSettingsFromMenu(tester, l10n);

      expect(find.text(l10n.settingsTitle), findsOneWidget);
      expect(Directionality.of(tester.element(settingsPage)), hebrew ? TextDirection.rtl : TextDirection.ltr);
      // The back arrow is at the start: the left in English, the right in Hebrew.
      final back = tester.getCenter(find.byTooltip(l10n.commonBack)).dx;
      expect(back, hebrew ? greaterThan(phone.width / 2) : lessThan(phone.width / 2));

      // Language: each language in its own letters, whatever the screen's.
      expect(find.text(l10n.accountLanguage), findsOneWidget);
      expect(find.text('עברית'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(isChosen(tester, _language(language)), isTrue);
      expect(find.text(l10n.languageNote), findsOneWidget);

      // Week: the Israeli week unless the owner chose otherwise.
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
      expect(find.text(l10n.settingsSavedNote), findsOneWidget);
    });

    testWidgets('the day letters run from Sunday, with Friday and Saturday as the weekend', (tester) async {
      await pumpHome(tester);
      await openSettingsFromMenu(tester, _en);

      expect(previewLetters(tester), ['S', 'M', 'T', 'W', 'T', 'F', 'S']);
      expect(find.bySemanticsLabel(_en.settingsWeekendIs('Fri, Sat')), findsOneWidget);
    });

    testWidgets('in Hebrew the day letters start with Sunday on the right', (tester) async {
      await pumpHome(tester, language: AppLanguage.hebrew);
      await openSettingsFromMenu(tester, _he);

      // Read from the right: א׳ (Sunday) to ש׳ (Saturday).
      expect(previewLetters(tester).reversed, ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳']);
      const format = AppFormat('he');
      final weekend = '${format.weekdayShort(DateTime.friday)}, ${format.weekdayShort(DateTime.saturday)}';
      expect(find.bySemanticsLabel(_he.settingsWeekendIs(weekend)), findsOneWidget);
    });
  });

  group('language', () {
    testWidgets('a choice switches the whole app at once and survives a restart', (tester) async {
      final store = MemorySettingsStore();
      await pumpHome(tester, settings: store);
      await openSettingsFromAccountSheet(tester);

      expect(find.text('Settings'), findsOneWidget);
      // No choice was made yet: the app follows the phone, English here.
      expect(isChosen(tester, _language(AppLanguage.system)), isTrue);
      expect(isChosen(tester, _language(AppLanguage.english)), isFalse);
      expect(isChosen(tester, _language(AppLanguage.hebrew)), isFalse);

      await tapOnSettings(tester, find.byKey(_language(AppLanguage.hebrew)));

      // The page itself is in Hebrew now, right to left.
      expect(find.text('הגדרות'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('שבוע'), findsOneWidget);
      expect(Directionality.of(tester.element(settingsPage)), TextDirection.rtl);
      expect(isChosen(tester, _language(AppLanguage.hebrew)), isTrue);
      expect(store.values, {languageSettingKey: 'he'});

      // And so is the app behind it.
      await tester.tap(find.byTooltip('חזרה'));
      await settle(tester);
      expect(find.text('האכלה'), findsOneWidget);
      expect(find.text('Feeding'), findsNothing);

      // Close the app and open it again with the same saved choices.
      await pumpHome(tester, settings: store);
      expect(find.text('האכלה'), findsOneWidget);

      // Back to English, through the side menu this time.
      await openSettingsFromMenu(tester, _he);
      await tapOnSettings(tester, find.byKey(_language(AppLanguage.english)));
      expect(find.text('Settings'), findsOneWidget);
      expect(store.values, {languageSettingKey: 'en'});
    });

    testWidgets('"Follow the phone" is offered and Hebrew is no longer tagged as a preview', (tester) async {
      await pumpHome(tester);
      await openSettingsFromMenu(tester, _en);

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
      await openSettingsFromMenu(tester, _he);

      // Three choices now, and no "preview" tag.
      expect(find.text('לפי שפת המכשיר'), findsOneWidget);
      expect(find.text(_he.languageFollowPhoneNow('עברית')), findsOneWidget);
      expect(isChosen(tester, _language(AppLanguage.system)), isTrue);
      expect(find.text('בהרצה'), findsNothing);

      await tapOnSettings(tester, find.byKey(_language(AppLanguage.english)));
      expect(find.text('Follow the phone'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(store.values, {languageSettingKey: 'en'});

      await tapOnSettings(tester, find.byKey(_language(AppLanguage.system)));
      expect(find.text('הגדרות'), findsOneWidget);
      expect(store.values, isEmpty);
    });
  });

  group('week', () {
    testWidgets('the first day reorders the week at once and is remembered', (tester) async {
      final store = MemorySettingsStore();
      await pumpHome(tester, settings: store);
      await openSettingsFromMenu(tester, _en);

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
      await openSettingsFromMenu(tester, _en);
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

    testWidgets('both choices survive a restart', (tester) async {
      final store = MemorySettingsStore();
      await pumpHome(tester, settings: store);
      await openSettingsFromMenu(tester, _en);
      await tapOnSettings(tester, find.byKey(WeekChoice.firstDayKey(DateTime.monday)));
      await tapOnSettings(tester, find.byKey(WeekChoice.mondayToFridayKey));

      // Close the app and open it again with the same saved choices.
      await pumpHome(tester, settings: store);
      await openSettingsFromMenu(tester, _en);

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
      await openSettingsFromMenu(tester, _he);

      expect(_firstDayChosen(tester, DateTime.monday), isTrue);
      expect(isChosen(tester, WeekChoice.mondayToFridayKey), isTrue);
      // Read from the right: Monday (ב׳) first, Sunday (א׳) last.
      expect(previewLetters(tester).reversed, ['ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳', 'א׳']);
    });

    testWidgets('the language does not change the week', (tester) async {
      final store = MemorySettingsStore();
      await pumpHome(tester, settings: store);
      await openSettingsFromMenu(tester, _en);
      await tapOnSettings(tester, find.byKey(_language(AppLanguage.hebrew)));

      expect(weekOf(tester), WeekSettings.israeli);
      expect(_firstDayChosen(tester, DateTime.sunday), isTrue);
      expect(isChosen(tester, WeekChoice.sundayToThursdayKey), isTrue);
    });
  });

  group('the account sheet', () {
    testWidgetsInBothLanguages('holds the account, a way to Settings and Sign out', (tester, language) async {
      final l10n = stringsOf(language);
      await pumpHome(tester, language: language);
      await tester.tap(find.text('A'));
      await settle(tester);

      expect(find.text('Alex'), findsOneWidget);
      expect(find.text(FakeAuthRepository.demoEmail), findsOneWidget);
      expect(find.byKey(AccountSheet.settingsKey), findsOneWidget);
      expect(find.text(l10n.settingsTitle), findsOneWidget);
      expect(find.text(l10n.settingsSummary), findsOneWidget);
      expect(find.text(l10n.accountSignOut), findsOneWidget);
      // The language list lives on the Settings page only.
      expect(find.byType(LanguageChoice), findsNothing);
      expect(find.text(l10n.accountLanguage), findsNothing);

      // The Settings row comes before Sign out.
      expect(
        tester.getCenter(find.byKey(AccountSheet.settingsKey)).dy,
        lessThan(tester.getCenter(find.text(l10n.accountSignOut)).dy),
      );
    });

    testWidgetsInBothLanguages('its Settings row closes the sheet and opens the page', (tester, language) async {
      final l10n = stringsOf(language);
      await pumpHome(tester, language: language);
      await openSettingsFromAccountSheet(tester);

      expect(find.byType(AccountSheet), findsNothing);
      expect(find.byType(LanguageChoice), findsOneWidget);

      // One step back is Home, not the sheet.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(settingsPage, findsNothing);
      expect(find.byType(AccountSheet), findsNothing);
      expect(find.text(l10n.homeFeeding), findsOneWidget);
    });

    testWidgets('Sign out still signs out', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('A'));
      await settle(tester);
      await tester.tap(find.text('Sign out'));
      await settle(tester);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('fits', () {
    for (final textScale in const [1.0, 1.3]) {
      testWidgetsInBothLanguages('Settings and the account sheet on a small phone, text x$textScale', (
        tester,
        language,
      ) async {
        final l10n = stringsOf(language);
        await pumpHome(tester, language: language, size: smallPhone, textScale: textScale);

        await tester.tap(find.text('A'));
        await settle(tester);
        expect(find.text(l10n.accountSignOut), findsOneWidget);
        await tester.tap(find.byKey(AccountSheet.settingsKey));
        await settle(tester);
        expect(settingsPage, findsOneWidget);

        // Every control can be reached and used; the page scrolls.
        await tapOnSettings(tester, find.byKey(WeekChoice.firstDayKey(DateTime.monday)));
        await tapOnSettings(tester, find.byKey(WeekChoice.mondayToFridayKey));
        await tester.ensureVisible(find.text(l10n.settingsSavedNote));
        await tester.pumpAndSettle();
        expect(weekOf(tester), WeekSettings.mondayToFriday);
        expect(previewLetters(tester), hasLength(7));

        // Switching the language here must fit as well.
        final other = language == AppLanguage.hebrew ? AppLanguage.english : AppLanguage.hebrew;
        await tapOnSettings(tester, find.byKey(_language(other)));
        expect(find.text(stringsOf(other).settingsTitle), findsOneWidget);
        await tester.ensureVisible(find.text(stringsOf(other).settingsSavedNote));
        await tester.pumpAndSettle();
      });
    }
  });

  group('About PetLoop', () {
    testWidgets('opens the Terms of Use and the Privacy Policy in the browser', (tester) async {
      final opener = RecordingLinkOpener();
      await pumpApp(tester, overrides: [linkOpenerProvider.overrideWithValue(opener)]);
      await signInAsDemo(tester);
      await settle(tester);
      await openSettingsFromMenu(tester, _en);

      expect(find.text(_en.settingsAbout), findsOneWidget);
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
      await openSettingsFromMenu(tester, _he);

      await tester.ensureVisible(find.byKey(LegalLinks.privacyKey));
      await tester.tap(find.byKey(LegalLinks.privacyKey));
      await tester.pump();

      expect(opener.opened.single.toString(), endsWith('/legal/privacy.he.html'));
      expect(find.text(_he.legalOpenFailed), findsOneWidget);
    });
  });
}
