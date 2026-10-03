import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/auth/widgets/language_pill.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';
import 'package:pet_companion/widgets/brand.dart';
import 'package:pet_companion/widgets/language_choice.dart';
import 'package:pet_companion/widgets/petloop_icon.dart';
import 'package:pet_companion/widgets/primary_button.dart';

import '../helpers.dart';

// The shared screens (sign-in, sign-up, Home, the bottom bar, the account
// sheet) in Hebrew and right to left. An overflow anywhere fails the test
// by itself, and the test font makes Hebrew letters as wide as Latin ones,
// so these layouts are checked as strictly as the English ones.

final _he = lookupAppL10n(hebrewLocale);
final _en = lookupAppL10n(englishLocale);

TextDirection _directionOf(WidgetTester tester, Finder finder) => Directionality.of(tester.element(finder));

double _centerX(WidgetTester tester, Finder finder) => tester.getCenter(finder).dx;

/// Lets Health's sample data (behind the Emergency pill) finish loading.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _openAccountSheet(WidgetTester tester) async {
  await tester.tap(find.text('A')); // the avatar of the demo user, Alex
  await _settle(tester);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('sign-in in Hebrew', () {
    testWidgets('reads in Hebrew, right to left', (tester) async {
      await pumpApp(tester, language: AppLanguage.hebrew);

      expect(find.text('טוב לראות אותך שוב'), findsOneWidget);
      expect(find.text('כניסה קצרה, ואפשר לראות מה שלום החיות שלך היום.'), findsOneWidget);
      expect(find.text('אימייל'), findsOneWidget);
      expect(find.text('סיסמה'), findsOneWidget);
      expect(find.text('שכחתי סיסמה'), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'כניסה'), findsOneWidget);
      expect(find.text('יצירת חשבון'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
      // The name stays in Latin letters: the PetLoop lettering of the logo.
      expect(find.byType(PetLoopWordmark), findsOneWidget);
      expect(_directionOf(tester, find.text('טוב לראות אותך שוב')), TextDirection.rtl);

      // "Forgot password" sits at the end of the line: the left in Hebrew.
      expect(_centerX(tester, find.text('שכחתי סיסמה')), lessThan(390 / 2));
      // The label of a field starts at the right.
      expect(tester.getTopRight(find.text('אימייל')).dx, greaterThan(390 - 40));
    });

    testWidgets('an address and a password are still typed left to right', (tester) async {
      await pumpApp(tester, language: AppLanguage.hebrew);

      final fields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
      expect(fields, hasLength(2));
      expect(fields[0].textDirection, TextDirection.ltr);
      expect(fields[1].textDirection, TextDirection.ltr);

      // The address hint sits where typing starts (the left); the hint in
      // words follows the screen (the right).
      expect(tester.widget<Text>(find.text('you@example.com')).textDirection, TextDirection.ltr);
      expect(tester.widget<Text>(find.text('הסיסמה שלך')).textDirection, TextDirection.rtl);
    });

    testWidgets('validation speaks Hebrew', (tester) async {
      await pumpApp(tester, language: AppLanguage.hebrew);

      await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextFormField).at(1), 'short');
      // Scrolled to first: below the banner the form can run past the screen.
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('זה לא נראה כמו כתובת אימייל.'), findsOneWidget);
      expect(find.text('צריך לפחות 8 תווים.'), findsOneWidget);
      expect(find.text('טוב לראות אותך שוב'), findsOneWidget);
    });

    testWidgets('a wrong password is explained in Hebrew', (tester) async {
      await pumpApp(tester, language: AppLanguage.hebrew);

      await tester.enterText(find.byType(TextFormField).at(0), FakeAuthRepository.demoEmail);
      await tester.enterText(find.byType(TextFormField).at(1), 'definitely-wrong');
      // Scrolled to first: below the banner the form can run past the screen.
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('הסיסמה לא נכונה. אפשר לנסות שוב.'), findsOneWidget);
      expect(find.text('Incorrect password. Please try again.'), findsNothing);
    });

    testWidgets('"Forgot password" names the address without scrambling the sentence', (tester) async {
      await pumpApp(tester, language: AppLanguage.hebrew);

      await tester.tap(find.text('שכחתי סיסמה'));
      await tester.pumpAndSettle();
      expect(find.text(_he.authForgotNeedsEmail), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), FakeAuthRepository.demoEmail);
      await tester.tap(find.text('שכחתי סיסמה'));
      await tester.pumpAndSettle();
      final message = _he.authResetSent(FakeAuthRepository.demoEmail);
      expect(find.text(message), findsOneWidget);
      // The address is wrapped, so it stays one left-to-right unit.
      expect(message, contains(isolate(FakeAuthRepository.demoEmail)));
    });
  });

  group('sign-up in Hebrew', () {
    testWidgets('reads in Hebrew, with the back arrow on the right', (tester) async {
      await pumpApp(tester, language: AppLanguage.hebrew);
      await tester.tap(find.text('יצירת חשבון'));
      await tester.pumpAndSettle();

      expect(find.text('יצירת חשבון חדש'), findsOneWidget);
      expect(find.text('חשבון אחד לכל החיות שלך.'), findsOneWidget);
      expect(find.text('השם שלך'), findsOneWidget);
      expect(find.text('לפחות 8 תווים'), findsOneWidget);
      expect(find.text('חזרה על הסיסמה'), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'יצירת חשבון'), findsOneWidget);

      final back = find.byTooltip('חזרה');
      expect(back, findsOneWidget);
      expect(_centerX(tester, back), greaterThan(390 / 2));
      // The pill is at the other end.
      expect(_centerX(tester, find.byKey(LanguagePill.pillKey)), lessThan(390 / 2));

      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('טוב לראות אותך שוב'), findsOneWidget);
    });

    testWidgets('a new account is created and an address already in use is refused, in Hebrew', (tester) async {
      await pumpApp(tester, language: AppLanguage.hebrew);
      await tester.tap(find.text('יצירת חשבון'));
      await tester.pumpAndSettle();

      // Scrolled to first: below the banner the form can run past the screen.
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('צריך שם, כדי שנדע איך לקרוא לך.'), findsOneWidget);
      expect(find.text('צריך להזין כתובת אימייל.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'לימור');
      await tester.enterText(find.byType(TextFormField).at(1), FakeAuthRepository.demoEmail);
      await tester.enterText(find.byType(TextFormField).at(2), 'walkies123');
      await tester.enterText(find.byType(TextFormField).at(3), 'walkies124');
      // Scrolled to first: below the banner the form can run past the screen.
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('הסיסמאות לא זהות.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(3), 'walkies123');
      // Scrolled to first: below the banner the form can run past the screen.
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('כבר יש חשבון עם כתובת האימייל הזאת.'), findsOneWidget);
    });
  });

  group('Home in Hebrew', () {
    Future<void> pumpHome(WidgetTester tester, {Size size = const Size(390, 844), double textScale = 1}) async {
      await pumpApp(tester, language: AppLanguage.hebrew, now: DateTime(2025, 6, 10, 15));
      await signInAsDemo(tester);
      if (size != const Size(390, 844) || textScale != 1) {
        tester.view.physicalSize = size * 3;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      await _settle(tester);
    }

    testWidgets('the dashboard reads in Hebrew', (tester) async {
      await pumpHome(tester);

      // The bottom bar.
      expect(find.text('בית'), findsOneWidget);
      expect(find.text('בריאות'), findsNWidgets(2)); // the tab and the Health card
      expect(find.text('קהילה'), findsOneWidget);
      expect(find.text('חנות'), findsOneWidget);

      // The header and the hero.
      expect(find.bySemanticsLabel('PetLoop'), findsOneWidget);
      expect(find.text('2 חיות'), findsOneWidget);
      expect(find.text('גזע'), findsOneWidget);
      expect(find.text('גיל'), findsOneWidget);
      expect(find.text('משקל'), findsOneWidget);
      expect(find.text(_he.homeWeightKg('23')), findsOneWidget);
      expect(stripBidiMarks(_he.homeWeightKg('23')), '23 ק״ג');
      expect(find.text('13.6'), findsOneWidget);

      // The cards.
      expect(find.text('האכלה'), findsOneWidget);
      expect(find.text(_he.homeGoal('1,030')), findsOneWidget);
      expect(stripBidiMarks(_he.homeGoal('1,030')), 'יעד: 1,030 קלוריות ביום');
      expect(find.text('504'), findsOneWidget);
      expect(find.text('קלוריות היום'), findsOneWidget);
      expect(find.text(_he.homeNextFeeding('19:30')), findsOneWidget);
      expect(stripBidiMarks(_he.homeNextFeeding('19:30')), 'ההאכלה הבאה · 19:30');
      expect(find.text('פעילות'), findsOneWidget);
      expect(find.text(isolate('1/2')), findsOneWidget);
      expect(find.text('טיולים היום'), findsOneWidget);
      expect(find.text(isolate('25')), findsOneWidget);
      expect(find.text('דקות פעילות'), findsOneWidget);
      expect(find.text(_he.homeNextWalk('18:30')), findsOneWidget);
      expect(find.text('האכלתי'), findsOneWidget);
      expect(find.text('טיול'), findsOneWidget);
      expect(find.text('בקרוב'), findsOneWidget);
      expect(find.text(lookupCareL10n(hebrewLocale).medicineItem('Joint tablets')), findsOneWidget);
      expect(find.text('12.06.25 · 18:20'), findsOneWidget);

      // Nothing of the English dashboard is left. (The pets' names and what
      // their owner wrote stay as they were entered.)
      for (final english in ['Home', 'Health', 'Community', 'Store', 'Feeding', 'Activity', 'Fed', 'Walk', 'Upcoming']) {
        expect(find.text(english), findsNothing, reason: english);
      }
      expect(find.text('Kelly'), findsNWidgets(2));
    });

    testWidgets('the layout is mirrored', (tester) async {
      await pumpHome(tester);

      expect(_directionOf(tester, find.byType(AppBottomNav)), TextDirection.rtl);

      // Bottom bar: Home on the right, Store on the left.
      final tabs = [for (final label in ['בית', 'בריאות', 'קהילה', 'חנות']) _centerX(tester, find.text(label).last)];
      expect(tabs, orderedEquals([...tabs]..sort((a, b) => b.compareTo(a))));

      // Top bar: menu on the right, the account on the left, the Emergency
      // pill beside the account.
      final menu = _centerX(tester, find.byTooltip('תפריט'));
      // (Announced as "חשבון" followed by the initial.)
      final account = _centerX(tester, find.bySemanticsLabel(RegExp('^חשבון')));
      final emergency = _centerX(tester, find.byType(EmergencyButton));
      expect(menu, greaterThan(emergency));
      expect(emergency, greaterThan(account));

      // Hero: the picture on the right, the details to its left.
      final photo = _centerX(tester, find.byType(PetAvatar).last);
      expect(photo, greaterThan(_centerX(tester, find.text('גזע'))));
      // In each pill the label is to the right of its value.
      expect(_centerX(tester, find.text('משקל')), greaterThan(_centerX(tester, find.text(_he.homeWeightKg('23')))));

      // Pet pills start from the right; the count is at the left end.
      expect(_centerX(tester, find.text('Kelly').first), greaterThan(_centerX(tester, find.text('Soya'))));
      expect(_centerX(tester, find.text('2 חיות')), lessThan(_centerX(tester, find.text('Soya'))));

      // The feeding progress bar fills from the right by itself.
      expect(_directionOf(tester, find.byType(LinearProgressIndicator)), TextDirection.rtl);
    });

    testWidgets('a pet with nothing filled in is described in Hebrew', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Soya'));
      await _settle(tester);

      expect(find.text('עוד לא נקבע יעד'), findsOneWidget);
      expect(find.text('ההאכלה הבאה · עוד לא נקבעה'), findsOneWidget);
      expect(find.text('הטיול הבא · עוד לא נקבע'), findsOneWidget);
      expect(find.text('עדיין אין אירועי בריאות'), findsOneWidget);
    });

    testWidgets('the tabs still switch, by their Hebrew names', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('חנות'));
      await _settle(tester);
      expect(find.text('האכלה'), findsNothing);

      await tester.tap(find.text('בית'));
      await _settle(tester);
      expect(find.text('האכלה'), findsOneWidget);
    });

    testWidgets('fits a small phone, and large text', (tester) async {
      await pumpHome(tester, size: const Size(320, 568));
      expect(find.text('האכלה'), findsOneWidget);

      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _settle(tester);
      expect(find.text('האכלה'), findsOneWidget);

      await _openAccountSheet(tester);
      expect(find.text('הגדרות'), findsOneWidget);
    });
  });

  group('the account sheet in Hebrew', () {
    testWidgets('shows the account, the way to Settings and sign-out', (tester) async {
      await pumpApp(tester, language: AppLanguage.hebrew);
      await signInAsDemo(tester);
      await _settle(tester);
      await _openAccountSheet(tester);

      expect(find.text('Alex'), findsOneWidget);
      final email = find.text(FakeAuthRepository.demoEmail);
      expect(email, findsOneWidget);
      expect(tester.widget<Text>(email).textDirection, TextDirection.ltr);
      expect(find.text('הגדרות'), findsOneWidget);
      expect(find.text('שפה, שבוע, התראות'), findsOneWidget);
      expect(find.text('יציאה מהחשבון'), findsOneWidget);
      // The language list itself is on the Settings page (test/settings/).
      expect(find.byType(LanguageChoice), findsNothing);

      // The sign-out arrow is mirrored here, and only here.
      final arrow = find.byWidgetPredicate((w) => w is PetLoopIcon && w.glyph == PetLoopGlyph.logout);
      expect(arrow, findsOneWidget);
      expect(find.descendant(of: arrow, matching: find.byType(Transform)), findsOneWidget);

      await tester.tap(find.text('יציאה מהחשבון'));
      await tester.pumpAndSettle();
      expect(find.text('טוב לראות אותך שוב'), findsOneWidget);
    });
  });

  group('the language switch', () {
    testWidgets('the pill on sign-in switches both ways at once', (tester) async {
      final store = MemorySettingsStore();
      await pumpApp(tester, settings: store);
      expect(find.text('Welcome back'), findsOneWidget);

      // On an English screen the pill offers Hebrew, in Hebrew letters.
      expect(find.descendant(of: find.byKey(LanguagePill.pillKey), matching: find.text('עברית')), findsOneWidget);
      expect(find.bySemanticsLabel(_en.languageSwitchTo('עברית')), findsOneWidget);
      await tester.tap(find.byKey(LanguagePill.pillKey));
      await tester.pumpAndSettle();

      expect(find.text('טוב לראות אותך שוב'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
      expect(store.values[languageSettingKey], 'he');

      // Now it offers English.
      expect(find.descendant(of: find.byKey(LanguagePill.pillKey), matching: find.text('English')), findsOneWidget);
      await tester.tap(find.byKey(LanguagePill.pillKey));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(store.values[languageSettingKey], 'en');
    });

    testWidgets('what was typed survives the switch', (tester) async {
      await pumpApp(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'limor@example.com');
      await tester.tap(find.byKey(LanguagePill.pillKey));
      await tester.pumpAndSettle();
      expect(find.text('limor@example.com'), findsOneWidget);
    });

    testWidgets('a Hebrew phone that made no choice starts in Hebrew', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('he', 'IL')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await pumpApp(tester);
      expect(find.text(lookupAppL10n(hebrewLocale).authWelcomeBack), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
    });
  });

  group('both languages fit', () {
    for (final size in const [Size(390, 844), Size(320, 568)]) {
      for (final textScale in const [1.0, 1.3]) {
        testWidgetsInBothLanguages('sign-in, sign-up, Home and the account sheet at '
            '${size.width.toInt()}x${size.height.toInt()}, text x$textScale', (tester, language) async {
          final l10n = lookupAppL10n(language == AppLanguage.hebrew ? hebrewLocale : englishLocale);
          await pumpApp(tester, language: language, size: size, textScale: textScale);
          expect(find.text(l10n.authWelcomeBack), findsOneWidget);

          // Every validation message at once: the tallest the form gets.
          await tester.ensureVisible(find.byType(PrimaryButton));
          // Scrolled to first: below the banner the form can run past the screen.
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
          await tester.pumpAndSettle();
          expect(find.text(l10n.validEmailEmpty), findsOneWidget);

          await tester.ensureVisible(find.text(l10n.authCreateAnAccount));
          await tester.tap(find.text(l10n.authCreateAnAccount));
          await tester.pumpAndSettle();
          expect(find.text(l10n.authCreateTitle), findsOneWidget);
          await tester.ensureVisible(find.byType(PrimaryButton));
          // Scrolled to first: below the banner the form can run past the screen.
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
          await tester.pumpAndSettle();
          expect(find.text(l10n.validNameEmpty), findsOneWidget);

          await tester.ensureVisible(find.byTooltip(l10n.commonBack));
          await tester.tap(find.byTooltip(l10n.commonBack));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(PrimaryButton));
          await signInAsDemo(tester);
          await _settle(tester);
          expect(find.text(l10n.homeFeeding), findsOneWidget);

          await _openAccountSheet(tester);
          expect(find.text(l10n.settingsTitle), findsOneWidget);
          await tester.ensureVisible(find.text(l10n.accountSignOut));
          await tester.pumpAndSettle();
          expect(find.text(l10n.accountSignOut), findsOneWidget);
        });
      }
    }
  });
}
