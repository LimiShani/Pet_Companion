import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/store/data/deal.dart';
import 'package:pet_companion/features/store/deal_detail_screen.dart';
import 'package:pet_companion/features/store/saved_deals_screen.dart';
import 'package:pet_companion/features/store/share_deal_screen.dart';
import 'package:pet_companion/features/store/store_strings.dart';
import 'package:pet_companion/features/store/widgets/deal_badge.dart';
import 'package:pet_companion/features/store/widgets/deal_card.dart';
import 'package:pet_companion/features/store/widgets/save_deal_button.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/widgets/directional_icon.dart';
import 'package:pet_companion/widgets/primary_button.dart';

import '../helpers.dart';
import 'store_test_helpers.dart';

// The Store in Hebrew, right to left, through the whole app. An overflow
// anywhere fails a test by itself, and the test font makes Hebrew letters
// as wide as Latin ones, so these layouts are checked as strictly as the
// English ones.

final _he = lookupStoreL10n(hebrewLocale);

/// A text as it reads: without the invisible direction marks, and with
/// ordinary spaces.
String _plain(String text) => stripBidiMarks(text).replaceAll('\u{00A0}', ' ');

/// A `Text` that reads [text], whatever direction marks it carries.
Finder _reads(String text) => find.byWidgetPredicate(
      (widget) => widget is Text && widget.data != null && _plain(widget.data!) == text,
      description: 'a text reading "$text"',
    );

Finder _on(Finder scope, Finder what) => find.descendant(of: scope, matching: what);

TextDirection _screenDirection(WidgetTester tester, Finder finder) => Directionality.of(tester.element(finder));

double _centerX(WidgetTester tester, Finder finder) => tester.getCenter(finder).dx;

Future<void> _pumpHebrewStore(
  WidgetTester tester, {
  List<Deal>? seed,
  List<Pet> extraPets = const [],
  Size size = const Size(390, 844),
}) =>
    pumpStore(
      tester,
      repository: fakeStore(seed: seed),
      extraPets: extraPets,
      language: AppLanguage.hebrew,
      size: size,
    );

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

Future<void> _pickCategory(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('the Store tab in Hebrew', () {
    testWidgets('reads in Hebrew, right to left', (tester) async {
      await _pumpHebrewStore(tester);

      final screen = find.byKey(const Key('store-screen'));
      expect(_screenDirection(tester, screen), TextDirection.rtl);

      // The tab's name: once in the header, once in the bottom bar.
      expect(find.text('חנות'), findsNWidgets(2));
      expect(find.text('חיפוש מבצעים'), findsOneWidget);
      expect(find.text('כל החיות'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'הכול'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'מזון'), findsOneWidget);
      expect(_reads('23 מבצעים עבור כלבים'), findsOneWidget);
      expect(find.text('ההנחה הגדולה ביותר'), findsOneWidget);
      expect(find.text('שיתוף מבצע'), findsOneWidget);

      // Nothing of the English screen is left.
      for (final english in ['Search deals', 'All animals', 'Food', 'Biggest discount', 'Share a deal']) {
        expect(find.text(english), findsNothing, reason: english);
      }
      expect(find.textContaining('deals for dogs'), findsNothing);

      // The pets keep their names; the row starts at the right.
      expect(_centerX(tester, find.text('Kelly')), greaterThan(_centerX(tester, find.text('Soya'))));
      // The count is at the right end of its row.
      expect(tester.getTopRight(find.byKey(const Key('store-deal-count'))).dx, greaterThan(350));
    });

    testWidgets('a card keeps its content as written and its numbers in one piece', (tester) async {
      await _pumpHebrewStore(tester);

      final card = find.byKey(const ValueKey('deal-card-d-rope-tug-toy'));
      expect(shownDealIds(tester).first, 'd-rope-tug-toy');

      // Content: the English title and seller, left to right.
      final title = tester.widget<Text>(_on(card, find.text('Squeaky rope tug toy, 2 pack')));
      expect(title.textDirection, TextDirection.ltr);
      final seller = tester.widget<Text>(_on(card, find.text('Toy Barn')));
      expect(seller.textDirection, TextDirection.ltr);

      // "-51%" keeps its minus in front: it is wrapped left to right.
      final badge = tester.widget<Text>(_on(card, _on(find.byType(DealBadge), find.byType(Text))));
      expect(badge.data, ltr('-51%'));

      // Prices: the number, then the shekel sign, each one unit.
      expect(_on(card, _reads('29 ₪')), findsOneWidget);
      expect(_on(card, _reads('59 ₪')), findsOneWidget);
      expect(_on(card, _reads('14.50 ₪ ליחידה')), findsOneWidget);
      expect(tester.widget<Text>(_on(card, _reads('29 ₪'))).data, startsWith('\u{2068}'));

      // The first card is on the right; its badge at the right, its heart
      // at the left.
      final cards = find.byType(DealCard);
      expect(_centerX(tester, cards.at(0)), greaterThan(_centerX(tester, cards.at(1))));
      expect(_centerX(tester, _on(card, find.byType(DealBadge))), greaterThan(_centerX(tester, card)));
      expect(_centerX(tester, _on(card, find.byType(SaveDealButton))), lessThan(_centerX(tester, card)));
    });

    testWidgets('delivery on a card, with a truck that drives the way Hebrew reads', (tester) async {
      await _pumpHebrewStore(
        tester,
        seed: [
          testDeal('paid', price: 179, originalPrice: 299, package: const PackageSize(12, PackageUnit.kg), delivery: 25),
          testDeal('free', price: 89, originalPrice: 129, delivery: 0),
        ],
      );

      final paid = find.byKey(const ValueKey('deal-card-paid'));
      expect(_on(paid, _reads('משלוח: 25 ₪')), findsOneWidget);
      expect(_on(paid, _reads('14.92 ₪ לק״ג')), findsOneWidget);
      expect(_on(find.byKey(const ValueKey('deal-card-free')), find.text('משלוח חינם')), findsOneWidget);

      // The truck is mirrored on a right-to-left screen.
      expect(_on(paid, find.byType(MirroredIcon)), findsOneWidget);
      final flip = tester.widget<Transform>(_on(paid, _on(find.byType(MirroredIcon), find.byType(Transform))));
      expect(flip.transform.storage[0], -1);
    });

    testWidgets('the count uses the Hebrew forms for one, two and many', (tester) async {
      await _pumpHebrewStore(
        tester,
        seed: [
          testDeal('a', title: 'Red ball'),
          testDeal('b', title: 'Red bone'),
          testDeal('c', title: 'Blue rope'),
        ],
      );
      expect(_reads('3 מבצעים עבור כלבים'), findsOneWidget);

      await _search(tester, 'ball');
      expect(shownDealIds(tester), ['a']);
      expect(_reads('מבצע אחד עבור כלבים'), findsOneWidget);

      await _search(tester, 'red');
      expect(shownDealIds(tester), unorderedEquals(['a', 'b']));
      expect(_reads('שני מבצעים עבור כלבים'), findsOneWidget);

      // For every animal the count stands alone.
      await tapPetPill(tester, 'כל החיות');
      expect(find.text('שני מבצעים'), findsOneWidget);
      await _search(tester, 'rope');
      expect(find.text('מבצע אחד'), findsOneWidget);
      await _search(tester, '');
      expect(find.text('3 מבצעים'), findsOneWidget);
    });

    testWidgets('the sort menu opens with the five orders in Hebrew', (tester) async {
      await _pumpHebrewStore(tester);

      await tester.tap(find.byTooltip('מיון המבצעים'));
      await tester.pumpAndSettle();

      final items = tester.widgetList<PopupMenuItem<DealSort>>(find.byType(PopupMenuItem<DealSort>)).toList();
      expect(items, hasLength(5));
      for (final label in [
        'ההנחה הגדולה ביותר',
        'המחיר הנמוך ביותר',
        'המחיר הנמוך ביותר ליחידת מידה',
        'החדשים ביותר',
        'מסתיימים בקרוב',
      ]) {
        expect(_on(find.byType(PopupMenuItem<DealSort>), find.text(label)), findsOneWidget, reason: label);
      }
      // The menu itself is laid out right to left.
      expect(_screenDirection(tester, find.byType(PopupMenuItem<DealSort>).first), TextDirection.rtl);

      await tester.tap(find.text('המחיר הנמוך ביותר ליחידת מידה'));
      await tester.pumpAndSettle();
      expect(find.text('המחיר הנמוך ביותר ליחידת מידה'), findsOneWidget);
      expect(find.text('ההנחה הגדולה ביותר'), findsNothing);
      // Cheapest per kilo first among what suits a dog.
      expect(shownDealIds(tester).first, 'd-chicken-rice-cans');
    });

    testWidgets('categories are named in Hebrew, and the search finds one by its Hebrew name', (tester) async {
      await _pumpHebrewStore(tester);

      await _pickCategory(tester, 'חול וניקיון');
      expect(_reads('שני מבצעים עבור כלבים'), findsOneWidget);
      expect(shownDealIds(tester), ['d-waste-bags-300', 'd-odour-remover-spray']);

      await _pickCategory(tester, 'הכול');
      await tapPetPill(tester, 'כל החיות');
      await _search(tester, 'חול');
      expect(find.text('6 מבצעים'), findsOneWidget);
      // The English name of the category no longer matches.
      await _search(tester, 'cleaning');
      expect(find.text('6 מבצעים'), findsNothing);
    });

    testWidgets('"All animals" tags the deals in Hebrew', (tester) async {
      await _pumpHebrewStore(tester);
      await tapPetPill(tester, 'כל החיות');

      expect(find.text('36 מבצעים'), findsOneWidget);
      expect(_on(find.byKey(const ValueKey('animals-d-rope-tug-toy')), find.text('כלבים')), findsOneWidget);
      await _search(tester, 'puzzle');
      expect(_on(find.byKey(const ValueKey('animals-d-puzzle-feeder')), _reads('כלבים, חתולים')), findsOneWidget);
    });

    testWidgets('nothing for this pet: the message and the way out are in Hebrew', (tester) async {
      await _pumpHebrewStore(tester, extraPets: [const Pet(id: 'tweety', name: 'Tweety', species: PetSpecies.bird)]);
      await tapPetPill(tester, 'Tweety');
      expect(_reads('4 מבצעים עבור ציפורים'), findsOneWidget);

      await _pickCategory(tester, 'צעצועים');
      expect(_reads('אין מבצעים עבור ציפורים'), findsOneWidget);
      expect(_reads('אין כאן מבצעים עבור ציפורים'), findsOneWidget);
      expect(
        _reads('אין כרגע דבר עבור ציפורים בקטגוריה צעצועים. לחיות אחרות יש כאן 5 מבצעים.'),
        findsOneWidget,
      );

      await tester.tap(find.text('הצגת כל החיות'));
      await tester.pumpAndSettle();
      expect(find.text('5 מבצעים'), findsOneWidget);
    });

    testWidgets('a search that finds nothing, and a load that fails, speak Hebrew', (tester) async {
      final store = fakeStore()..failFetches = true;
      await pumpStore(tester, repository: store, language: AppLanguage.hebrew);

      expect(find.text('לא הצלחנו לטעון את המבצעים'), findsOneWidget);
      expect(find.text('אין חיבור לשרת. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.'), findsOneWidget);

      store.failFetches = false;
      await tester.tap(find.text('לנסות שוב'));
      await tester.pumpAndSettle();
      expect(_reads('23 מבצעים עבור כלבים'), findsOneWidget);

      await _search(tester, 'hamster wheel');
      expect(find.text('לא נמצאו מבצעים'), findsOneWidget);
      final message = _reads('לא נמצא דבר עבור ״hamster wheel״. אפשר לנסות מילה אחרת.');
      expect(message, findsOneWidget);
      // What was typed is wrapped, so it cannot reorder the sentence.
      expect(tester.widget<Text>(message).data, contains(isolate('hamster wheel')));

      await tester.tap(find.text('ניקוי הסינון'));
      await tester.pumpAndSettle();
      expect(_reads('23 מבצעים עבור כלבים'), findsOneWidget);
    });
  });

  group('the deal page in Hebrew', () {
    Future<void> openLitter(WidgetTester tester) async {
      await _pumpHebrewStore(tester);
      await tapPetPill(tester, 'כל החיות');
      await _search(tester, 'clumping');
      await openDeal(tester, 'd-clumping-litter-10kg');
    }

    final page = find.byType(DealDetailScreen);

    testWidgets('labels in Hebrew, numbers and dates in one piece', (tester) async {
      await openLitter(tester);
      expect(_screenDirection(tester, page), TextDirection.rtl);

      expect(_on(page, find.text('מבצע')), findsOneWidget);
      expect(_on(page, find.text('חול וניקיון')), findsOneWidget);
      expect(_on(page, _reads('עבור חתולים')), findsOneWidget);
      expect(_on(page, find.text('בחירת Pet Companion')), findsOneWidget);

      expect(_on(page, _reads('36.90 ₪')), findsOneWidget);
      expect(_on(page, _reads('59.90 ₪')), findsOneWidget);
      expect(_on(page, _reads('חיסכון של 23 ₪ (38%)')), findsOneWidget);
      expect(_on(page, find.text('מחיר ליחידת מידה')), findsOneWidget);
      expect(_on(page, _reads('3.69 ₪ לק״ג')), findsOneWidget);
      expect(_on(page, find.text('אריזה')), findsOneWidget);
      expect(_on(page, _reads('10 ק״ג')), findsOneWidget);
      expect(_on(page, find.text('משלוח')), findsOneWidget);
      expect(_on(page, _reads('+ 25 ₪')), findsOneWidget);
      expect(_on(page, find.text('מחיר סופי')), findsOneWidget);
      expect(_on(page, _reads('61.90 ₪')), findsOneWidget);

      expect(_on(page, find.text('מוכר')), findsOneWidget);
      expect(_on(page, find.text('המחיר נבדק')), findsOneWidget);
      expect(_on(page, _reads('29.09.26 · אתמול')), findsOneWidget);
      expect(_on(page, find.text('פורסם')), findsOneWidget);
      expect(_on(page, find.text('לפני יומיים')), findsOneWidget);
      expect(_on(page, find.text('מסתיים')), findsOneWidget);
      expect(_on(page, _reads('14.10.26 · נותרו 14 ימים')), findsOneWidget);

      expect(_on(page, find.text('מעבר למבצע באתר המוכר')), findsOneWidget);
      final opens = _on(page, _reads('example.com ייפתח בדפדפן שלך'));
      expect(opens, findsOneWidget);
      expect(tester.widget<Text>(opens).data, contains(ltr('example.com')));

      for (final english in ['Unit price', 'Package', 'Delivery', 'Final price', 'Open offer', 'Price checked']) {
        expect(find.text(english), findsNothing, reason: english);
      }

      // Each label is at the right of its value.
      expect(_centerX(tester, find.text('אריזה')), greaterThan(_centerX(tester, _reads('10 ק״ג'))));
    });

    testWidgets('the title, the description and the seller stay as written, left to right', (tester) async {
      await openLitter(tester);

      expect(tester.widget<Text>(_on(page, find.text('Clumping cat litter, 10 kg'))).textDirection, TextDirection.ltr);
      expect(tester.widget<Text>(_on(page, find.text('Clean Paws'))).textDirection, TextDirection.ltr);
      final description = _on(page, find.textContaining('Fine-grain clumping litter'));
      expect(tester.widget<Text>(description).textDirection, TextDirection.ltr);
      // An English paragraph starts at the left even on a Hebrew page.
      expect(tester.getTopLeft(description).dx, lessThan(30));
    });

    testWidgets('content written in Hebrew reads right to left, on an English screen too', (tester) async {
      final hebrewDeal = testDeal(
        'he',
        title: 'חול מתגבש לחתולים, 10 ק״ג',
        seller: 'חיות ועוד',
        description: 'חול דק ומתגבש, כמעט בלי אבק.',
      );
      await pumpStore(tester, repository: fakeStore(seed: [hebrewDeal]));

      final card = find.byKey(const ValueKey('deal-card-he'));
      expect(tester.widget<Text>(_on(card, find.text('חול מתגבש לחתולים, 10 ק״ג'))).textDirection, TextDirection.rtl);
      expect(tester.widget<Text>(_on(card, find.text('חיות ועוד'))).textDirection, TextDirection.rtl);

      await openDeal(tester, 'he');
      expect(_screenDirection(tester, page), TextDirection.ltr);
      expect(tester.widget<Text>(_on(page, find.text('חיות ועוד'))).textDirection, TextDirection.rtl);
      expect(
        tester.widget<Text>(_on(page, find.text('חול דק ומתגבש, כמעט בלי אבק.'))).textDirection,
        TextDirection.rtl,
      );
      // The app's own words are still English.
      expect(_on(page, find.text('Seller')), findsOneWidget);
    });

    testWidgets('the "Open offer" arrow mirrors by itself, and the link still opens', (tester) async {
      expect(Icons.open_in_new_rounded.matchTextDirection, isTrue);

      final opener = FakeLinkOpener();
      await pumpStore(tester, opener: opener, language: AppLanguage.hebrew);
      await openDeal(tester, 'd-rope-tug-toy');

      final icon = _on(page, find.byIcon(Icons.open_in_new_rounded));
      expect(Directionality.of(tester.element(icon)), TextDirection.rtl);
      await tester.tap(find.text('מעבר למבצע באתר המוכר'));
      await tester.pumpAndSettle();
      expect(opener.opened, [Uri.parse('https://example.com/deals/rope-tug-toy')]);
    });

    testWidgets('reporting, and deleting a deal of your own, in Hebrew', (tester) async {
      await _pumpHebrewStore(tester);
      await openDeal(tester, 'd-rope-tug-toy');

      final report = _on(page, find.text('דיווח שהמבצע הסתיים'));
      await tester.ensureVisible(report);
      await tester.pumpAndSettle();
      await tester.tap(report);
      await tester.pumpAndSettle();
      expect(find.text('תודה, נבדוק את זה.'), findsOneWidget);
      expect(_on(page, find.text('דיווחת שהמבצע הסתיים')), findsOneWidget);

      await tester.tap(find.byTooltip('חזרה'));
      await tester.pumpAndSettle();

      // The demo user's own deal ended two days ago.
      await openDeal(tester, 'd-salmon-training-treats');
      expect(_on(page, find.text('הסתיים')), findsOneWidget);
      expect(_on(page, _reads('המבצע הסתיים בתאריך 28.09.26')), findsOneWidget);
      expect(_on(page, find.text('מבצע ששיתפת')), findsOneWidget);

      final delete = _on(page, find.text('מחיקת המבצע שלי'));
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.text('למחוק את המבצע?'), findsOneWidget);
      expect(find.text('המבצע יוסר מהחנות עבור כולם.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'ביטול'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'מחיקה'));
      await tester.pumpAndSettle();
      expect(find.byType(DealDetailScreen), findsNothing);
      expect(find.text('המבצע שלך נמחק.'), findsOneWidget);
    });

    testWidgets('a price checked long ago, and a deal shared by a member', (tester) async {
      await _pumpHebrewStore(
        tester,
        seed: [
          testDeal(
            'old',
            posted: const Duration(days: 60),
            checked: const Duration(days: 49),
            sharedBy: 'sample-dana',
            sharedByName: 'Dana',
          ),
        ],
      );
      await openDeal(tester, 'old');

      expect(_on(page, find.text('המחיר נבדק לפני זמן מה, וייתכן שהשתנה.')), findsOneWidget);
      expect(_on(page, _reads('12.08.26 · לפני 49 ימים')), findsOneWidget);
      expect(_on(page, _reads('שיתוף של Dana')), findsOneWidget);
      expect(_on(page, find.text('לכל החיות')), findsOneWidget);
      expect(_on(page, find.text('ללא תאריך סיום')), findsOneWidget);
    });
  });

  group('saved deals in Hebrew', () {
    testWidgets('saving, the saved list and its empty state', (tester) async {
      await _pumpHebrewStore(tester);

      final heart = find.byKey(const ValueKey('save-d-rope-tug-toy'));
      expect(find.byTooltip('שמירת המבצע'), findsWidgets);
      await tester.tap(heart);
      await tester.pumpAndSettle();
      expect(find.text('נשמר'), findsOneWidget);

      await tester.tap(find.byTooltip('מבצעים ששמרתי'));
      await tester.pumpAndSettle();
      expect(find.byType(SavedDealsScreen), findsOneWidget);
      expect(_on(find.byType(SavedDealsScreen), find.text('מבצעים ששמרתי')), findsOneWidget);
      expect(find.text('מבצע שמור אחד'), findsOneWidget);

      await tester.tap(find.byTooltip('הסרה מהשמורים'));
      await tester.pumpAndSettle();
      expect(find.text('הוסר מהמבצעים ששמרת'), findsOneWidget);
      expect(find.text('עדיין לא שמרת מבצעים'), findsOneWidget);
      expect(find.text('לחיצה על הלב שעל מבצע שומרת אותו כאן.'), findsOneWidget);

      await tester.tap(find.text('לכל המבצעים'));
      await tester.pumpAndSettle();
      expect(find.byType(SavedDealsScreen), findsNothing);
    });
  });

  group('sharing a deal in Hebrew', () {
    Future<void> openForm(WidgetTester tester) async {
      await tester.tap(find.text('שיתוף מבצע'));
      await tester.pumpAndSettle();
      expect(find.byType(ShareDealScreen), findsOneWidget);
    }

    Future<void> show(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, String field, String text) async {
      final input = find.byKey(Key('share-$field'));
      await show(tester, input);
      await tester.enterText(input, text);
      await tester.pumpAndSettle();
    }

    Future<void> pickFrom(WidgetTester tester, String dropdownKey, String label) async {
      final dropdown = find.byKey(Key(dropdownKey));
      await show(tester, dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      final target = find.byKey(Key(key));
      await show(tester, target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester) async {
      final button = find.widgetWithText(PrimaryButton, 'שיתוף המבצע');
      await show(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('the form and its checks speak Hebrew', (tester) async {
      await _pumpHebrewStore(tester);
      await openForm(tester);

      final form = find.byType(ShareDealScreen);
      expect(_screenDirection(tester, form), TextDirection.rtl);
      for (final label in ['כותרת', 'קטגוריה', 'לאילו חיות', 'גודל האריזה (לא חובה)', 'משלוח (לא חובה)']) {
        expect(_on(form, find.text(label)), findsOneWidget, reason: label);
      }
      expect(_on(form, _reads('המחיר עכשיו (₪)')), findsOneWidget);
      expect(_on(form, _reads('המחיר הקודם (₪)')), findsOneWidget);
      // The chips of the animals, starting on the selected pet's kind.
      expect(find.widgetWithText(FilterChip, 'כל החיות'), findsOneWidget);
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'כלבים')).selected, isTrue);
      expect(find.widgetWithText(FilterChip, 'חתולים'), findsOneWidget);

      await submit(tester);
      for (final problem in [
        'צריך לתת למבצע כותרת.',
        'צריך לבחור קטגוריה.',
        'צריך להזין את המחיר עכשיו.',
        'צריך להזין את המחיר שלפני ההנחה.',
        'מי המוכר?',
        'צריך להדביק את הקישור למבצע.',
      ]) {
        expect(find.text(problem), findsOneWidget, reason: problem);
      }
      expect(find.text('Give the deal a title.'), findsNothing);
      expect(find.byType(ShareDealScreen), findsOneWidget);

      await fill(tester, 'title', 'ab');
      expect(find.text('צריך לפחות 3 תווים.'), findsOneWidget);
      await fill(tester, 'original-price', '30');
      await fill(tester, 'price', '40');
      expect(find.text('מחיר המבצע צריך להיות נמוך מהמחיר הקודם.'), findsOneWidget);
      await fill(tester, 'price', 'זול');
      expect(find.text('צריך להזין מספר, למשל 49.90.'), findsOneWidget);

      // The link problem names "https://" without scrambling it.
      await fill(tester, 'link', 'http://example.com/x');
      final linkProblem = _reads('צריך קישור מלא שמתחיל ב־https://');
      expect(linkProblem, findsOneWidget);
      expect(tester.widget<Text>(linkProblem).data, endsWith(isolate('https://')));

      await fill(tester, 'package-amount', '10');
      expect(find.text('צריך לבחור יחידת מידה: ק״ג, גרם, ליטר, מ״ל או יחידות.'), findsOneWidget);
      await fill(tester, 'package-amount', '0');
      expect(find.text('צריך להזין גודל גדול מאפס, למשל 2.5.'), findsOneWidget);

      await tapKey(tester, 'share-delivery-paid');
      await submit(tester);
      expect(find.text('צריך להזין את עלות המשלוח.'), findsOneWidget);
      await fill(tester, 'delivery-cost', '0');
      expect(find.text('צריך להזין מספר גדול מאפס, או לבחור ״חינם״.'), findsOneWidget);
    });

    testWidgets('a link is typed left to right, and its hint shows how it starts', (tester) async {
      await _pumpHebrewStore(tester);
      await openForm(tester);

      final link = find.byKey(const Key('share-link'));
      await show(tester, link);
      expect(tester.widget<EditableText>(_on(link, find.byType(EditableText))).textDirection, TextDirection.ltr);
      expect(tester.widget<Text>(_on(link, find.text('https://'))).textDirection, TextDirection.ltr);
      // A field for words is not pinned: it follows the screen.
      final title = find.byKey(const Key('share-title'));
      await show(tester, title);
      final titleText = _on(title, find.byType(EditableText));
      expect(tester.widget<EditableText>(titleText).textDirection, isNull);
      expect(_screenDirection(tester, titleText), TextDirection.rtl);
    });

    testWidgets('a deal is shared from the Hebrew form, with live hints in Hebrew', (tester) async {
      await _pumpHebrewStore(tester);
      await openForm(tester);

      await fill(tester, 'title', 'Clumping cat litter, 10 kg');
      await pickFrom(tester, 'share-category', 'חול וניקיון');
      await tapKey(tester, 'share-animals-cat');
      await fill(tester, 'price', '36.90');
      await fill(tester, 'original-price', '59.90');
      expect(find.text('זו הנחה של 38%'), findsOneWidget);

      await fill(tester, 'package-amount', '10');
      await pickFrom(tester, 'share-package-unit', 'ק״ג');
      expect(_reads('כלומר 3.69 ₪ לק״ג'), findsOneWidget);

      await tapKey(tester, 'share-delivery-paid');
      expect(_on(find.byKey(const Key('share-delivery-cost')), _reads('עלות המשלוח (₪)')), findsOneWidget);
      await fill(tester, 'delivery-cost', '25');
      expect(_reads('מחיר סופי: 61.90 ₪'), findsOneWidget);

      await fill(tester, 'seller', 'Clean Paws');
      await fill(tester, 'link', 'https://example.com/litter');
      expect(_reads('המחיר יוצג כמחיר שנבדק היום, 30.09.26.'), findsOneWidget);
      await submit(tester);

      expect(find.byType(ShareDealScreen), findsNothing);
      expect(find.text('תודה, המבצע שלך פורסם.'), findsOneWidget);
      expect(_reads('24 מבצעים עבור כלבים'), findsOneWidget);
    });

    testWidgets('a share that fails is explained in Hebrew', (tester) async {
      final store = fakeStore();
      await pumpStore(tester, repository: store, language: AppLanguage.hebrew);
      await openForm(tester);

      await fill(tester, 'title', 'Dental chews');
      await pickFrom(tester, 'share-category', 'חטיפים');
      await fill(tester, 'price', '20');
      await fill(tester, 'original-price', '30');
      await fill(tester, 'seller', 'The Treat Jar');
      await fill(tester, 'link', 'https://example.com/chews');
      store.failWrites = true;
      await submit(tester);

      expect(find.byType(ShareDealScreen), findsOneWidget);
      expect(find.text('אין חיבור לשרת. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.'), findsOneWidget);
    });

    testWidgets('the calendar for the end date is in Hebrew too', (tester) async {
      await _pumpHebrewStore(tester);
      await openForm(tester);

      await tapKey(tester, 'share-end-date');
      expect(find.text('היום האחרון של המבצע'), findsOneWidget);
      // Flutter's own "OK", in Hebrew.
      await tester.tap(find.text('אישור'));
      await tester.pumpAndSettle();
      expect(_reads('מסתיים בתאריך 07.10.26'), findsOneWidget);
      expect(find.byTooltip('הסרת תאריך הסיום'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgetsInBothLanguages('the Store opens on its deals at 390 px', (tester, language) async {
      await pumpStore(tester, language: language);

      final words = lookupStoreL10n(language == AppLanguage.hebrew ? hebrewLocale : englishLocale);
      expect(_reads(_plain(words.dealsFor(23, PetSpecies.dog))), findsOneWidget);
      expect(find.text(words.shareADeal), findsOneWidget);
      expect(find.byType(DealCard), findsWidgets);
      expect(
        _screenDirection(tester, find.byKey(const Key('store-screen'))),
        language == AppLanguage.hebrew ? TextDirection.rtl : TextDirection.ltr,
      );
    });

    testWidgets('every Store screen fits a 320 px phone in Hebrew', (tester) async {
      // Signed in at the usual size first, then the screen shrinks: the
      // login screen is not what is being checked here.
      await _pumpHebrewStore(tester);
      tester.view.physicalSize = const Size(320, 568) * 3;
      await tester.pumpAndSettle();
      expect(find.byType(DealCard), findsWidgets);

      // A deal with a unit price, a delivery cost and an end date.
      await openDeal(tester, 'd-salmon-kibble-12kg');
      expect(find.byType(DealDetailScreen), findsOneWidget);
      await tester.tap(find.byTooltip('חזרה'));
      await tester.pumpAndSettle();

      // The user's own, expired deal, with its delete button and dialog.
      await openDeal(tester, 'd-salmon-training-treats');
      final delete = find.text('מחיקת המבצע שלי');
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'ביטול'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('חזרה'));
      await tester.pumpAndSettle();

      // Every animal, with the tags on the cards.
      await tapPetPill(tester, 'כל החיות');
      // Back to the top of the grid, where the count is.
      tester.state<ScrollableState>(gridScrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('36 מבצעים'), findsOneWidget);
      await tapPetPill(tester, 'Kelly');

      await tester.tap(find.byTooltip('מבצעים ששמרתי'));
      await tester.pumpAndSettle();
      expect(find.text('עדיין לא שמרת מבצעים'), findsOneWidget);
      await tester.tap(find.byTooltip('חזרה'));
      await tester.pumpAndSettle();

      await _search(tester, 'nothing like this');
      expect(find.text('לא נמצאו מבצעים'), findsOneWidget);
      await _search(tester, 'clumping');
      expect(_reads('אין כאן מבצעים עבור כלבים'), findsOneWidget);

      // The whole form, with every problem showing.
      await tester.tap(find.text('שיתוף מבצע'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('share-package-amount')), '10');
      final paid = find.byKey(const Key('share-delivery-paid'));
      await tester.ensureVisible(paid);
      await tester.pumpAndSettle();
      await tester.tap(paid);
      await tester.pumpAndSettle();
      final send = find.widgetWithText(PrimaryButton, 'שיתוף המבצע');
      await tester.ensureVisible(send);
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('צריך לבחור קטגוריה.'), findsOneWidget);
      expect(find.text('צריך להזין את עלות המשלוח.'), findsOneWidget);
    });
  });

  group('switching the language', () {
    testWidgets('the Store follows the switch at once, both ways', (tester) async {
      await pumpStore(tester);
      expect(find.text('23 deals for dogs'), findsOneWidget);

      final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('store-screen'))));
      await container.read(appLanguageProvider.notifier).choose(AppLanguage.hebrew);
      await tester.pumpAndSettle();

      expect(_reads('23 מבצעים עבור כלבים'), findsOneWidget);
      expect(find.text('חיפוש מבצעים'), findsOneWidget);
      expect(_screenDirection(tester, find.byKey(const Key('store-screen'))), TextDirection.rtl);
      expect(find.text('23 deals for dogs'), findsNothing);
      // Content does not change with the language.
      expect(find.text('Squeaky rope tug toy, 2 pack'), findsOneWidget);

      await container.read(appLanguageProvider.notifier).choose(AppLanguage.english);
      await tester.pumpAndSettle();
      expect(find.text('23 deals for dogs'), findsOneWidget);
      expect(find.text('₪29'), findsOneWidget);
    });
  });

  test('the Hebrew words used above come from the strings file', () {
    expect(_he.tabTitle, 'חנות');
    expect(_he.shareADeal, 'שיתוף מבצע');
    expect(_he.openOffer, 'מעבר למבצע באתר המוכר');
    expect(_he.category(DealCategory.litterAndCleaning), 'חול וניקיון');
  });
}
