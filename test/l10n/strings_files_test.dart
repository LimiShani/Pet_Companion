import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Checks on the strings files themselves (no widgets): every module has an
// English and a Hebrew file that agree with each other and with the
// generated classes. `dart run tool/gen_l10n.dart` keeps them in step.

const _modules = {
  'app': 'lib/l10n',
  'health': 'lib/features/health/l10n',
  'community': 'lib/features/community/l10n',
  'store': 'lib/features/store/l10n',
  'pets': 'lib/features/pets/l10n',
  'care': 'lib/features/care/l10n',
};

const _firstStrongIsolate = '\u{2068}';
const _popIsolate = '\u{2069}';

Map<String, dynamic> _arb(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Map<String, String> _messages(Map<String, dynamic> arb) => {
  for (final entry in arb.entries)
    if (!entry.key.startsWith('@')) entry.key: entry.value as String,
};

/// The names between braces in a message: `{count}`, `{email}`, and the
/// variable of `{count, plural, ...}`.
Set<String> _placeholders(String message) => {
  for (final match in RegExp(r'\{(\w+)(?:\}|,)').allMatches(message)) match.group(1)!,
};

/// The placeholders declared as strings in the English file.
Set<String> _stringPlaceholders(Map<String, dynamic> en, String key) {
  final declared = (en['@$key'] as Map<String, dynamic>?)?['placeholders'] as Map<String, dynamic>?;
  return {
    for (final entry in declared?.entries ?? const <MapEntry<String, dynamic>>[])
      if ((entry.value as Map<String, dynamic>)['type'] == 'String') entry.key,
  };
}

void main() {
  for (final MapEntry(key: module, value: folder) in _modules.entries) {
    group('$module strings', () {
      final en = _arb('$folder/${module}_en.arb');
      final he = _arb('$folder/${module}_he.arb');
      final english = _messages(en);
      final hebrew = _messages(he);

      test('the two files are marked with their languages', () {
        expect(en['@@locale'], 'en');
        expect(he['@@locale'], 'he');
      });

      test('Hebrew has no key that English does not have', () {
        expect(hebrew.keys.toSet().difference(english.keys.toSet()), isEmpty);
      });

      test('no message is empty', () {
        for (final entry in [...english.entries, ...hebrew.entries]) {
          expect(entry.value.trim(), isNotEmpty, reason: entry.key);
        }
      });

      test('a Hebrew message uses the same placeholders as the English one', () {
        for (final entry in hebrew.entries) {
          expect(_placeholders(entry.value), _placeholders(english[entry.key]!), reason: entry.key);
        }
      });

      test('every placeholder used in English is declared', () {
        for (final entry in english.entries) {
          final declared = ((en['@${entry.key}'] as Map<String, dynamic>?)?['placeholders'] as Map<String, dynamic>?)
              ?.keys
              .toSet();
          expect(declared ?? <String>{}, _placeholders(entry.value), reason: entry.key);
        }
      });

      test('Hebrew wraps every text placeholder, so a Latin name cannot reorder the sentence', () {
        for (final entry in hebrew.entries) {
          for (final name in _stringPlaceholders(en, entry.key)) {
            expect(
              entry.value,
              contains('$_firstStrongIsolate{$name}$_popIsolate'),
              reason: '${entry.key}: write {$name} between the marks U+2068 and U+2069',
            );
          }
        }
      });

      test('the generated classes are up to date (run: dart run tool/gen_l10n.dart $module)', () {
        final base = File('$folder/gen/${module}_l10n.dart').readAsStringSync();
        final generatedEn = File('$folder/gen/${module}_l10n_en.dart').readAsStringSync();
        final generatedHe = File('$folder/gen/${module}_l10n_he.dart').readAsStringSync();
        final member = RegExp(r'^\s+String (?:get )?(\w+)(?: =>|\(|;)', multiLine: true);
        Set<String> members(String source) => {for (final m in member.allMatches(source)) m.group(1)!};

        expect(members(base), english.keys.toSet(), reason: 'keys of ${module}_en.arb');
        expect(members(generatedEn), english.keys.toSet());
        expect(members(generatedHe), hebrew.keys.toSet(), reason: 'keys of ${module}_he.arb');
        // A few words of each message must be in the generated file as they
        // are in the strings file.
        for (final entry in hebrew.entries) {
          final plain = entry.value.split(RegExp(r'[{}]')).first.trim();
          if (plain.length < 3 || plain.contains(_firstStrongIsolate)) continue;
          expect(generatedHe, contains(plain), reason: '${entry.key} changed since the classes were generated');
        }
      });

      test('the report lists exactly what is missing in Hebrew', () {
        final report = jsonDecode(File('$folder/gen/untranslated.json').readAsStringSync()) as Map<String, dynamic>;
        final listed = {for (final keys in report.values) ...(keys as List).cast<String>()};
        expect(listed, english.keys.toSet().difference(hebrew.keys.toSet()));
      });
    });
  }

  test('the shared strings are fully translated', () {
    final report = jsonDecode(File('lib/l10n/gen/untranslated.json').readAsStringSync()) as Map<String, dynamic>;
    expect(report, isEmpty);
  });

  test('no strings file or generated class contains an invisible direction mark', () {
    final marks = RegExp('[\u{2066}-\u{2069}\u{200E}\u{200F}\u{202A}-\u{202E}]');
    for (final folder in _modules.values) {
      final files = [
        ...Directory(folder).listSync().whereType<File>().where((f) => f.path.endsWith('.arb')),
        ...Directory('$folder/gen').listSync().whereType<File>().where((f) => f.path.endsWith('.dart')),
      ];
      for (final file in files) {
        expect(
          marks.hasMatch(file.readAsStringSync()),
          isFalse,
          reason: '${file.path}: run dart run tool/gen_l10n.dart, which writes the marks as visible escapes',
        );
      }
    }
  });
}
