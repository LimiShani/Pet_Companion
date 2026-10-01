import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/store/data/deal.dart';
import 'package:pet_companion/features/store/data/deal_filters.dart';
import 'package:pet_companion/features/store/data/store_repository.dart';
import 'package:pet_companion/features/store/store_format.dart';
import 'package:pet_companion/features/store/store_strings.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';

// The Store's words and numbers in Hebrew, without a screen: plural forms,
// lists, prices and percentages that keep their shape in a right-to-left
// line, and the English texts staying as they were.

final _he = lookupStoreL10n(hebrewLocale);
final _en = lookupStoreL10n(englishLocale);
final _heFormat = StoreFormat.forLocale(hebrewLocale);
final _enFormat = StoreFormat.forLocale(englishLocale);
final _now = DateTime(2026, 9, 30, 12);

const _leftToRightIsolate = '\u{2066}';
const _firstStrongIsolate = '\u{2068}';
const _popIsolate = '\u{2069}';

/// A text as it reads: without the invisible direction marks, and with
/// ordinary spaces.
String _plain(String text) => stripBidiMarks(text).replaceAll('\u{00A0}', ' ');

final _hebrewLetter = RegExp('[\u{05D0}-\u{05EA}]');
final _anyLetter = RegExp('[A-Za-z\u{05D0}-\u{05EA}]');
final _anyMark = RegExp('[\u{2066}-\u{2069}\u{200E}\u{200F}]');

void main() {
  group('plural forms in Hebrew: one, two and many', () {
    test('deals', () {
      expect(_he.dealCount(1), 'מבצע אחד');
      expect(_he.dealCount(2), 'שני מבצעים');
      expect(_he.dealCount(5), '5 מבצעים');
      expect(_he.dealCount(20), '20 מבצעים');
      expect(_he.dealCount(36), '36 מבצעים');
    });

    test('deals for a kind of animal', () {
      expect(_plain(_he.dealsFor(0, PetSpecies.bird)), 'אין מבצעים עבור ציפורים');
      expect(_plain(_he.dealsFor(1, PetSpecies.cat)), 'מבצע אחד עבור חתולים');
      expect(_plain(_he.dealsFor(2, PetSpecies.cat)), 'שני מבצעים עבור חתולים');
      expect(_plain(_he.dealsFor(23, PetSpecies.dog)), '23 מבצעים עבור כלבים');
      expect(_plain(_he.dealsFor(4, PetSpecies.other)), '4 מבצעים עבור חיות אחרות');
    });

    test('saved deals', () {
      expect(_he.savedCount(1), 'מבצע שמור אחד');
      expect(_he.savedCount(2), 'שני מבצעים שמורים');
      expect(_he.savedCount(7), '7 מבצעים שמורים');
    });

    test('what other animals have', () {
      expect(_he.othersHaveDeals(1), 'לחיות אחרות יש כאן מבצע אחד.');
      expect(_he.othersHaveDeals(2), 'לחיות אחרות יש כאן שני מבצעים.');
      expect(_he.othersHaveDeals(5), 'לחיות אחרות יש כאן 5 מבצעים.');
    });

    test('minutes, hours and days ago', () {
      expect(_he.timeMinutesAgo(1), 'לפני דקה');
      expect(_he.timeMinutesAgo(2), 'לפני שתי דקות');
      expect(_he.timeMinutesAgo(30), 'לפני 30 דקות');
      expect(_he.timeHoursAgo(1), 'לפני שעה');
      expect(_he.timeHoursAgo(2), 'לפני שעתיים');
      expect(_he.timeHoursAgo(5), 'לפני 5 שעות');
      expect(_he.timeDaysAgo(2), 'לפני יומיים');
      expect(_he.timeDaysAgo(9), 'לפני 9 ימים');
    });

    test('days left', () {
      expect(_plain(_he.endsOn('30.09.26', 0)), '30.09.26 · מסתיים היום');
      expect(_plain(_he.endsOn('01.10.26', 1)), '01.10.26 · נותר יום אחד');
      expect(_plain(_he.endsOn('02.10.26', 2)), '02.10.26 · נותרו יומיים');
      expect(_plain(_he.endsOn('12.10.26', 12)), '12.10.26 · נותרו 12 ימים');
    });

    test('the English forms are unchanged', () {
      expect(_en.dealCount(1), '1 deal');
      expect(_en.dealCount(2), '2 deals');
      expect(_en.dealsFor(0, PetSpecies.bird), '0 deals for birds');
      expect(_en.dealsFor(23, PetSpecies.dog), '23 deals for dogs');
      expect(_en.savedCount(1), '1 saved deal');
      expect(_en.timeHoursAgo(1), '1 hour ago');
      expect(_en.timeHoursAgo(3), '3 hours ago');
      expect(_en.endsOn('30.09.26', 0), '30.09.26 · ends today');
      expect(_en.endsOn('01.10.26', 1), '01.10.26 · 1 day left');
      expect(_en.endsOn('12.10.26', 12), '12.10.26 · 12 days left');
    });
  });

  group('lists', () {
    test('Hebrew joins the last item with a vav', () {
      expect(_he.list(const []), '');
      expect(_he.list(const ['כלבים']), 'כלבים');
      expect(_plain(_he.list(const ['כלבים', 'חתולים'])), 'כלבים וחתולים');
      expect(_plain(_he.list(const ['כלבים', 'חתולים', 'ארנבים'])), 'כלבים, חתולים וארנבים');
      expect(
        _plain(_he.list(const ['כלבים', 'חתולים', 'ציפורים', 'ארנבים'])),
        'כלבים, חתולים, ציפורים וארנבים',
      );
    });

    test('English joins it with "and"', () {
      expect(_en.list(const ['dogs']), 'dogs');
      expect(_en.list(const ['dogs', 'cats']), 'dogs and cats');
      expect(_en.list(const ['dogs', 'cats', 'rabbits']), 'dogs, cats and rabbits');
    });

    test('who a deal is for', () {
      expect(_he.forWhom(const []), 'לכל החיות');
      expect(_plain(_he.forWhom(const [PetSpecies.cat])), 'עבור חתולים');
      expect(_plain(_he.forWhom(const [PetSpecies.dog, PetSpecies.cat])), 'עבור כלבים וחתולים');
      expect(
        _plain(_he.forWhom(const [PetSpecies.dog, PetSpecies.cat, PetSpecies.rabbit])),
        'עבור כלבים, חתולים וארנבים',
      );
      expect(_he.animalsTag(const [PetSpecies.cat]), 'חתולים');
      expect(_plain(_he.animalsTag(const [PetSpecies.rabbit, PetSpecies.other])), 'ארנבים, חיות אחרות');
      expect(_en.forWhom(const [PetSpecies.dog, PetSpecies.cat, PetSpecies.rabbit]), 'For dogs, cats and rabbits');
      expect(_en.animalsTag(const [PetSpecies.dog, PetSpecies.cat]), 'Dogs, cats');
    });
  });

  group('numbers inside Hebrew text keep their shape', () {
    test('a price is one unit: the number, then the shekel sign', () {
      final price = _heFormat.money(179, 'ILS');
      expect(_plain(price), '179 ₪');
      expect(price, startsWith(_firstStrongIsolate));
      expect(price, endsWith(_popIsolate));
      expect(_plain(_heFormat.money(39.9, 'ILS')), '39.90 ₪');
      expect(_plain(_heFormat.money(26.999, 'ILS')), '27 ₪');
      expect(_plain(_heFormat.money(1299, 'ILS')), '1,299 ₪');
    });

    test('a discount keeps its minus in front', () {
      expect(_heFormat.discount(40), '$_leftToRightIsolate-40%$_popIsolate');
      expect(_plain(_heFormat.discount(51)), '-51%');
    });

    test('a unit price', () {
      String text(double price, PackageSize size) =>
          _heFormat.unitPrice(UnitPrice(price / size.inBaseUnits, size.unit.kind), 'ILS');

      final perKg = text(189, const PackageSize(10, PackageUnit.kg));
      expect(_plain(perKg), '18.90 ₪ לק״ג');
      // The price sits in its own isolate inside the sentence.
      expect(perKg, startsWith(_firstStrongIsolate));
      expect(_plain(text(29.90, const PackageSize(5, PackageUnit.litre))), '5.98 ₪ לליטר');
      expect(_plain(text(19.90, const PackageSize(300, PackageUnit.unit))), '0.07 ₪ ליחידה');
      expect(_plain(text(34.90, const PackageSize(1020, PackageUnit.g))), '34.22 ₪ לק״ג');
    });

    test('a package size', () {
      expect(_plain(_heFormat.package(const PackageSize(10, PackageUnit.kg))), '10 ק״ג');
      expect(_plain(_heFormat.package(const PackageSize(1020, PackageUnit.g))), '1,020 גרם');
      expect(_plain(_heFormat.package(const PackageSize(1, PackageUnit.litre))), '1 ליטר');
      expect(_plain(_heFormat.package(const PackageSize(60, PackageUnit.litre))), '60 ליטר');
      expect(_plain(_heFormat.package(const PackageSize(500, PackageUnit.ml))), '500 מ״ל');
      expect(_plain(_heFormat.package(const PackageSize(1, PackageUnit.unit))), '1 יחידה');
      expect(_plain(_heFormat.package(const PackageSize(28, PackageUnit.unit))), '28 יחידות');
    });

    test('the saving, the delivery and the final price', () {
      expect(_plain(_he.youSave(_heFormat.money(120, 'ILS'), 40)), 'חיסכון של 120 ₪ (40%)');
      expect(_plain(_he.plusDelivery(_heFormat.money(25, 'ILS'))), 'משלוח: 25 ₪');
      expect(_plain(_he.deliveryPlus(_heFormat.money(25, 'ILS'))), '+ 25 ₪');
      expect(_plain(_he.hintFinalPrice(_heFormat.money(61.9, 'ILS'))), 'מחיר סופי: 61.90 ₪');
      expect(_he.hintPercentOff(38), 'זו הנחה של 38%');
    });

    test('dates: when a deal ends and when its price was checked', () {
      expect(_heFormat.date(DateTime(2026, 10, 12)), '12.10.26');
      expect(_plain(_heFormat.ends(_now.add(const Duration(days: 12)), _now)), '12.10.26 · נותרו 12 ימים');
      expect(_plain(_heFormat.ends(_now.add(const Duration(days: 2)), _now)), '02.10.26 · נותרו יומיים');
      expect(_plain(_heFormat.ends(_now.add(const Duration(hours: 2)), _now)), '30.09.26 · מסתיים היום');
      expect(_heFormat.ends(null, _now), 'ללא תאריך סיום');
      expect(_plain(_heFormat.ends(_now.subtract(const Duration(days: 2)), _now)), 'הסתיים בתאריך 28.09.26');

      expect(_plain(_heFormat.checked(_now.subtract(const Duration(hours: 2)), _now)), '30.09.26 · היום');
      expect(_plain(_heFormat.checked(_now.subtract(const Duration(hours: 20)), _now)), '29.09.26 · אתמול');
      expect(_plain(_heFormat.checked(_now.subtract(const Duration(days: 2)), _now)), '28.09.26 · לפני יומיים');
      expect(_plain(_heFormat.checked(_now.subtract(const Duration(days: 49)), _now)), '12.08.26 · לפני 49 ימים');
      // The date is wrapped, so it cannot swap places with the words.
      expect(
        _heFormat.checked(_now.subtract(const Duration(hours: 20)), _now),
        startsWith('${_firstStrongIsolate}29.09.26$_popIsolate'),
      );
    });

    test('how long ago a deal was posted', () {
      String ago(Duration d) => _heFormat.timeAgo(_now.subtract(d), _now);
      expect(ago(const Duration(seconds: 20)), 'ממש עכשיו');
      expect(ago(const Duration(minutes: 30)), 'לפני 30 דקות');
      expect(ago(const Duration(hours: 1)), 'לפני שעה');
      expect(ago(const Duration(hours: 3)), 'לפני 3 שעות');
      expect(ago(const Duration(hours: 30)), 'אתמול');
      expect(ago(const Duration(days: 2)), 'לפני יומיים');
      expect(ago(const Duration(days: 9)), 'לפני 9 ימים');
      expect(ago(const Duration(days: 60)), '01.08.26');
    });

    test('a web address stays left to right inside a Hebrew sentence', () {
      final hint = _he.validLinkNotHttps(httpsPrefix);
      expect(_plain(hint), 'צריך קישור מלא שמתחיל ב־https://');
      expect(hint, endsWith('${_firstStrongIsolate}https://$_popIsolate'));

      final opens = _he.opensInBrowser(ltr('shop.example.com'));
      expect(_plain(opens), 'shop.example.com ייפתח בדפדפן שלך');
      expect(opens, contains('${_leftToRightIsolate}shop.example.com$_popIsolate'));
    });

    test('a name somebody typed is wrapped in its own direction', () {
      expect(_he.sharedBy('Dana'), 'שיתוף של ${_firstStrongIsolate}Dana$_popIsolate');
      expect(_he.nothingMatches('hamster wheel'), contains('${_firstStrongIsolate}hamster wheel$_popIsolate'));
      expect(_plain(_he.nothingMatches('hamster wheel')), 'לא נמצא דבר עבור ״hamster wheel״. אפשר לנסות מילה אחרת.');
    });
  });

  group('English stays as it was', () {
    test('no English text carries an invisible direction mark', () {
      final deal = Deal(
        id: 'a',
        title: 'Thing',
        category: DealCategory.food,
        price: 36.90,
        originalPrice: 59.90,
        sellerName: 'Shop',
        link: 'https://example.com/a',
        postedAt: _now.subtract(const Duration(days: 2)),
        expiresAt: _now.add(const Duration(days: 14)),
        package: const PackageSize(10, PackageUnit.kg),
        deliveryCost: 25,
      );
      final texts = [
        _enFormat.money(deal.price, 'ILS'),
        _enFormat.discount(deal.discountPercent),
        _enFormat.unitPrice(deal.unitPrice!, 'ILS'),
        _enFormat.package(deal.package!),
        _enFormat.ends(deal.expiresAt, _now),
        _enFormat.checked(deal.priceChecked, _now),
        _enFormat.timeAgo(deal.postedAt, _now),
        _en.youSave(_enFormat.money(deal.amountSaved, 'ILS'), deal.discountPercent),
        _en.plusDelivery(_enFormat.money(25, 'ILS')),
        _en.dealsFor(23, PetSpecies.dog),
        _en.forWhom(const [PetSpecies.dog, PetSpecies.cat]),
        _en.opensInBrowser('example.com'),
        _en.validLinkNotHttps(httpsPrefix),
      ];
      for (final text in texts) {
        expect(_anyMark.hasMatch(text), isFalse, reason: text);
      }
      expect(texts.take(7), [
        '₪36.90',
        '-38%',
        '₪3.69 per kg',
        '10 kg',
        '14.10.26 · 14 days left',
        '28.09.26 · 2 days ago',
        '2 days ago',
      ]);
    });
  });

  group('stored values are put into words in both languages', () {
    test('categories, following the glossary', () {
      expect(
        [for (final c in DealCategory.values) _he.category(c)],
        ['מזון', 'חטיפים', 'חול וניקיון', 'צעצועים', 'בריאות', 'טיפוח', 'אביזרים', 'מיטות וכלובים'],
      );
      expect(_en.category(DealCategory.litterAndCleaning), 'Litter & cleaning');
    });

    test('sort orders', () {
      expect(
        [for (final s in DealSort.values) _he.sort(s)],
        [
          'ההנחה הגדולה ביותר',
          'המחיר הנמוך ביותר',
          'המחיר הנמוך ביותר ליחידת מידה',
          'החדשים ביותר',
          'מסתיימים בקרוב',
        ],
      );
    });

    test('animals and units', () {
      expect(
        [for (final kind in PetSpecies.values) _he.animals(kind)],
        ['כלבים', 'חתולים', 'ציפורים', 'ארנבים', 'זוחלים', 'אחר'],
      );
      expect(_he.animalsInSentence(PetSpecies.other), 'חיות אחרות');
      expect([for (final u in PackageUnit.values) _he.unit(u)], ['ק״ג', 'גרם', 'ליטר', 'מ״ל', 'יחידות']);
      expect([for (final u in PackageUnit.values) _en.unit(u)], ['kg', 'g', 'litre', 'ml', 'units']);
    });

    test('every reason for failure has words, except the unknown one', () {
      for (final failure in StoreFailure.values) {
        if (failure == StoreFailure.unknown) {
          expect(_he.failure(failure), isNull);
          continue;
        }
        final hebrew = _he.failure(failure);
        expect(hebrew, isNotNull, reason: failure.name);
        expect(_hebrewLetter.hasMatch(hebrew!), isTrue, reason: failure.name);
        expect(_en.failure(failure), isNot(hebrew));
      }
      expect(_he.failure(StoreFailure.network), 'אין חיבור לשרת. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.');
      expect(_en.failure(StoreFailure.network), 'Cannot reach the server. Check your connection and try again.');
    });

    test('an exception says what failed without a sentence of its own', () {
      expect(const StoreException(StoreFailure.network).toString(), 'StoreException(network)');
      expect(
        const StoreException(StoreFailure.unknown, 'boom').toString(),
        'StoreException(unknown: boom)',
      );
    });
  });

  group('search', () {
    Deal deal(String id, DealCategory category) => Deal(
          id: id,
          title: 'Thing $id',
          category: category,
          price: 1,
          originalPrice: 2,
          sellerName: 'Shop',
          link: 'https://example.com/$id',
          postedAt: _now,
        );

    test('a category is found by its name in the language on screen', () {
      final deals = [deal('a', DealCategory.litterAndCleaning), deal('b', DealCategory.food)];
      List<String> search(String query, StoreL10n words) => [
            for (final d in visibleDeals(deals, StoreFilter(query: query), _now, categoryLabel: words.category)) d.id,
          ];

      expect(search('חול', _he), ['a']);
      expect(search('מזון', _he), ['b']);
      expect(search('litter', _he), isEmpty);
      expect(search('litter', _en), ['a']);
      expect(search('חול', _en), isEmpty);
    });
  });

  group('the strings files', () {
    Map<String, dynamic> arb(String name) =>
        jsonDecode(File('lib/features/store/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

    test('nothing is left untranslated', () {
      final report = jsonDecode(File('lib/features/store/l10n/gen/untranslated.json').readAsStringSync());
      expect(report, isEmpty);

      final english = arb('store_en.arb').keys.where((k) => !k.startsWith('@')).toSet();
      final hebrew = arb('store_he.arb').keys.where((k) => !k.startsWith('@')).toSet();
      expect(hebrew, english);
      expect(english.length, greaterThan(150));
    });

    test('every Hebrew text is in Hebrew', () {
      final hebrew = arb('store_he.arb');
      for (final entry in hebrew.entries) {
        if (entry.key.startsWith('@')) continue;
        final text = entry.value as String;
        // "+ {price}" and "{first}, {next}" are patterns with no words.
        final words = text.replaceAll(RegExp(r'\{\w+\}'), '');
        if (!_anyLetter.hasMatch(words)) continue;
        expect(_hebrewLetter.hasMatch(text), isTrue, reason: entry.key);
      }
    });

    test('no Hebrew text addresses the user as a man or as a woman with a slash', () {
      final hebrew = arb('store_he.arb');
      for (final entry in hebrew.entries) {
        if (entry.key.startsWith('@')) continue;
        expect((entry.value as String).contains('/'), isFalse, reason: entry.key);
      }
    });
  });

  test('the formatter follows the screen\'s language', () {
    expect(StoreFormat.forLocale(const Locale('he')).app.localeName, 'he');
    expect(StoreFormat.forLocale(const Locale('iw')).app.localeName, 'he');
    expect(StoreFormat.forLocale(const Locale('en')).app.localeName, 'en');
    expect(_heFormat.currencySymbol('ILS'), '₪');
  });
}
