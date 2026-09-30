import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/widgets/directional_icon.dart';

const _lri = '\u{2066}';
const _fsi = '\u{2068}';
const _pdi = '\u{2069}';

void main() {
  const en = AppFormat('en');
  const he = AppFormat('he');
  final tuesday = DateTime(2025, 6, 10, 18, 20);

  group('dates and times', () {
    // In the app the names of months and days are loaded together with the
    // app's localizations; here they are loaded by hand.
    setUpAll(initializeDateFormatting);

    test('the numeric forms are the same in both languages', () {
      for (final format in [en, he]) {
        expect(format.date(tuesday), '10.06.25');
        expect(format.time(tuesday), '18:20');
        expect(format.dateTime(tuesday), '10.06.25 · 18:20');
        expect(format.timeOfDay(const TimeOfDay(hour: 7, minute: 5)), '07:05');
        expect(format.hoursMinutes(const Duration(hours: 1, minutes: 32)), '01:32');
      }
    });

    test('names of months and days follow the language', () {
      expect(en.monthYear(tuesday), 'June 2025');
      expect(he.monthYear(tuesday), 'יוני 2025');
      expect(en.longDay(tuesday), 'Tuesday, June 10');
      expect(he.longDay(tuesday), 'יום שלישי, 10 ביוני');
      expect(en.shortDay(tuesday), 'Tue, Jun 10');
      expect(he.shortDay(tuesday), contains('10 ביוני'));
    });

    test('weekday names by ISO number, Sunday being 7', () {
      expect(en.weekdayShort(DateTime.monday), 'Mon');
      expect(en.weekdayShort(DateTime.sunday), 'Sun');
      expect(he.weekdayNarrow(DateTime.sunday), 'א׳');
      expect(he.weekdayNarrow(DateTime.monday), 'ב׳');
      expect(he.weekdayNarrow(DateTime.saturday), 'ש׳');
      // The Israeli week in Hebrew letters.
      expect([for (final day in WeekSettings.israeli.orderedDays) he.weekdayNarrow(day)], [
        'א׳',
        'ב׳',
        'ג׳',
        'ד׳',
        'ה׳',
        'ו׳',
        'ש׳',
      ]);
    });
  });

  test('before any language data is loaded the numeric forms still work', () {
    expect(const AppFormat('he').date(DateTime(2025, 7, 27)), '27.07.25');
  });

  group('numbers', () {
    test('whole numbers and decimals', () {
      for (final format in [en, he]) {
        expect(format.integer(2569), '2,569');
        expect(format.decimal(23), '23');
        expect(format.decimal(13.6), '13.6');
        expect(format.decimal(0.035, decimals: 3), '0.035');
      }
    });

    test('a price follows the language and stays one unit', () {
      expect(stripBidiMarks(en.money(179, 'ILS')), '₪179');
      expect(stripBidiMarks(en.money(39.9, 'ILS')), '₪39.90');
      // Hebrew: the number, a space, then the sign.
      expect(stripBidiMarks(he.money(179, 'ILS')).replaceAll('\u{00A0}', ' '), '179 ₪');
      expect(en.money(179, 'ILS'), startsWith(_fsi));
      expect(he.money(179, 'ILS'), endsWith(_pdi));
    });

    test('a percentage keeps its sign in front', () {
      expect(he.percent(-40), '$_lri-40%$_pdi');
      expect(stripBidiMarks(he.percent(-40)), '-40%');
    });
  });

  group('direction helpers', () {
    test('ltr keeps a phone number in order and can be undone', () {
      const phone = '+972 3 555 0142';
      expect(ltr(phone), '$_lri$phone$_pdi');
      expect(stripBidiMarks(ltr(phone)), phone);
      expect(ltr(''), '');
    });

    test('isolate wraps a name in its own direction', () {
      expect(isolate('Kelly'), '${_fsi}Kelly$_pdi');
      expect(isolate(''), '');
    });

    test('what people write takes the direction of its first letter', () {
      expect(directionOfText('Pepper says hi', fallback: TextDirection.rtl), TextDirection.ltr);
      expect(directionOfText('בוקר טוב', fallback: TextDirection.ltr), TextDirection.rtl);
      expect(directionOfText('13 שנים', fallback: TextDirection.ltr), TextDirection.rtl);
      expect(directionOfText('"Hello" היא אמרה', fallback: TextDirection.rtl), TextDirection.ltr);
      // Nothing to go by: the screen's direction.
      expect(directionOfText('12:30', fallback: TextDirection.rtl), TextDirection.rtl);
      expect(directionOfText('', fallback: TextDirection.ltr), TextDirection.ltr);
    });
  });

  group('icons on a right-to-left screen', () {
    Future<void> pump(WidgetTester tester, TextDirection direction, Widget icon) => tester.pumpWidget(
      Directionality(textDirection: direction, child: Center(child: icon)),
    );

    testWidgets('MirroredIcon flips an icon Flutter leaves alone', (tester) async {
      // The sign-out arrow does not mirror by itself.
      expect(Icons.logout_rounded.matchTextDirection, isFalse);

      await pump(tester, TextDirection.ltr, const MirroredIcon(Icons.logout_rounded));
      expect(find.byType(Transform), findsNothing);

      await pump(tester, TextDirection.rtl, const MirroredIcon(Icons.logout_rounded));
      final flip = tester.widget<Transform>(find.byType(Transform));
      expect(flip.transform.storage[0], -1, reason: 'mirrored left to right');
      // Drawn left-to-right underneath, so it is mirrored exactly once.
      expect(tester.widget<Icon>(find.byType(Icon)).textDirection, TextDirection.ltr);
    });

    testWidgets('FixedIcon keeps the question mark as it is', (tester) async {
      // Flutter would mirror it, which is wrong for Hebrew.
      expect(Icons.help_outline_rounded.matchTextDirection, isTrue);

      await pump(tester, TextDirection.rtl, const FixedIcon(Icons.help_outline_rounded));
      expect(tester.widget<Icon>(find.byType(Icon)).textDirection, TextDirection.ltr);
      expect(find.byType(Transform), findsNothing);
    });

    test('the arrows the app uses mirror by themselves', () {
      for (final icon in [
        Icons.arrow_back_rounded,
        Icons.chevron_right_rounded,
        Icons.send_rounded,
        Icons.open_in_new_rounded,
      ]) {
        expect(icon.matchTextDirection, isTrue);
      }
    });
  });
}
