import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/store/share_deal_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/theme/app_fonts.dart';
import 'package:pet_companion/widgets/header_search.dart';
import 'package:pet_companion/widgets/primary_button.dart';

import 'store_test_helpers.dart';

/// Loads the app's real fonts (the widget-test font is square and much
/// wider), so this file can check what fits on a real 320 px phone.
Future<void> _loadAppFonts() async {
  Future<ByteData> read(String file) async =>
      ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync());
  final nunito = FontLoader(AppFonts.latin);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    nunito.addFont(read('Nunito-$weight.ttf'));
  }
  final fredoka = FontLoader(AppFonts.hebrew);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    fredoka.addFont(read('Fredoka-$weight.ttf'));
  }
  await nunito.load();
  await fredoka.load();
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
  });

  void expectWhole(WidgetTester tester, String label) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(label).first);
    expect(paragraph.didExceedMaxLines, isFalse, reason: '"$label" is cut short');
  }

  void expectOnScreen(WidgetTester tester, Finder finder) {
    final rect = tester.getRect(finder);
    expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
    expect(rect.right, lessThanOrEqualTo(320), reason: '$finder');
  }

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets('the Store header, its search and the share form fit at 320 px (${language.name})', (tester) async {
      // Signed in at the usual size first, then the screen shrinks: the
      // login screen is not what is being checked here.
      await pumpStore(tester, language: language);
      tester.view.physicalSize = const Size(320, 568) * 3;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final locale = language == AppLanguage.hebrew ? hebrewLocale : englishLocale;
      final store = lookupStoreL10n(locale);
      final budget = lookupBudgetL10n(locale);
      final app = lookupAppL10n(locale);

      // The header: title, magnifier, heart and avatar, then the switch.
      expectWhole(tester, store.tabTitle);
      expectWhole(tester, budget.deals);
      expectWhole(tester, budget.basketTab);
      expectOnScreen(tester, find.byTooltip(store.searchTooltip));
      expectOnScreen(tester, find.byTooltip(store.savedDeals));

      // The sort pill is a menu chip like the animals chip.
      final sort = find.byKey(const Key('store-sort-chip'));
      expect(tester.getSize(sort).height, inInclusiveRange(32, 36));
      // As tall as the animals chip, give or take its outline.
      expect(tester.getSize(sort).height, closeTo(tester.getSize(find.byKey(const Key('store-kind-chip'))).height, 1));
      expectWhole(tester, tester.widget<Text>(find.descendant(of: sort, matching: find.byType(Text))).data!);

      // The search takes the switch's place and fits beside its close button.
      await tester.tap(find.byTooltip(store.searchTooltip));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(budget.basketTab), findsNothing);
      expectOnScreen(tester, find.byKey(HeaderSearchField.fieldKey));
      expectOnScreen(tester, find.byTooltip(app.commonClose));
      expect(tester.getSize(find.byKey(HeaderSearchField.fieldKey)).width, greaterThan(180));
      expectWhole(tester, store.searchHint);
      await tester.enterText(find.byKey(HeaderSearchField.fieldKey), 'salmon');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(app.commonClose));
      await tester.pumpAndSettle();

      // The share form: both steps, with the step line under the title.
      await tester.tap(find.byKey(const Key('add-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-share-deal')));
      await tester.pumpAndSettle();
      expect(find.byType(ShareDealScreen), findsOneWidget);
      final pets = lookupPetsL10n(locale);
      expectWhole(tester, store.shareADeal);
      expectWhole(tester, pets.stepOf(1, 2));
      expectWhole(tester, store.shareStepWhat);
      final next = find.widgetWithText(PrimaryButton, store.shareNext);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(store.validCategoryRequired), findsOneWidget);
    });
  }
}
