// Generates the strings classes from the ARB files.
//
//   dart run tool/gen_l10n.dart            every module
//   dart run tool/gen_l10n.dart health     one module (or several)
//   dart run tool/gen_l10n.dart --strict   also fail when Hebrew is missing
//
// Each module has its own folder with `<name>_en.arb` (the template) and
// `<name>_he.arb`, and gets its own class in `<folder>/gen/`, so features
// never share a strings file. There is deliberately no `l10n.yaml` in the
// project root: with one, `flutter gen-l10n` ignores these arguments.
//
// A string missing in Hebrew is not an error: the app shows the English
// text, and the key is listed in `<folder>/gen/untranslated.json`.
import 'dart:convert';
import 'dart:io';

class L10nModule {
  const L10nModule(this.name, this.folder, this.className);

  final String name;
  final String folder;
  final String className;
}

const modules = [
  L10nModule('app', 'lib/l10n', 'AppL10n'),
  L10nModule('health', 'lib/features/health/l10n', 'HealthL10n'),
  L10nModule('community', 'lib/features/community/l10n', 'CommunityL10n'),
  L10nModule('store', 'lib/features/store/l10n', 'StoreL10n'),
  L10nModule('pets', 'lib/features/pets/l10n', 'PetsL10n'),
  L10nModule('care', 'lib/features/care/l10n', 'CareL10n'),
  L10nModule('budget', 'lib/features/budget/l10n', 'BudgetL10n'),
  L10nModule('firstdays', 'lib/features/firstdays/l10n', 'FirstDaysL10n'),
];

Future<void> main(List<String> args) async {
  final strict = args.contains('--strict');
  final names = args.where((a) => !a.startsWith('--')).toList();
  final unknown = names.where((n) => modules.every((m) => m.name != n)).toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown module: ${unknown.join(', ')}. Known: ${modules.map((m) => m.name).join(', ')}.');
    exit(64);
  }
  final chosen = names.isEmpty ? modules : modules.where((m) => names.contains(m.name)).toList();

  var missing = 0;
  for (final module in chosen) {
    // Keep the strings files themselves free of invisible characters.
    _escapeDirectionMarks(Directory(module.folder), '.arb');

    final report = '${module.folder}/gen/untranslated.json';
    final result = await Process.run(
      'flutter',
      [
        'gen-l10n',
        '--arb-dir=${module.folder}',
        '--template-arb-file=${module.name}_en.arb',
        '--output-dir=${module.folder}/gen',
        '--output-localization-file=${module.name}_l10n.dart',
        '--output-class=${module.className}',
        '--untranslated-messages-file=$report',
        '--no-nullable-getter',
      ],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      stderr
        ..writeln('${module.name}: flutter gen-l10n failed.')
        ..writeln(result.stdout)
        ..writeln(result.stderr);
      exit(result.exitCode);
    }

    _escapeDirectionMarks(Directory('${module.folder}/gen'), '.dart');

    final keys = _messageKeys(File('${module.folder}/${module.name}_en.arb'));
    final untranslated = _untranslated(File(report));
    missing += untranslated.length;
    stdout.writeln(
      '${module.name}: ${keys.length} strings, '
      '${untranslated.isEmpty ? 'all translated' : '${untranslated.length} not yet in Hebrew'} '
      '(${module.className}, ${module.folder}/gen/).',
    );
    for (final key in untranslated) {
      stdout.writeln('  missing in Hebrew: $key');
    }
  }

  if (strict && missing > 0) {
    stderr.writeln('$missing strings are not translated.');
    exit(1);
  }
}

/// The Hebrew strings wrap their placeholders in invisible direction marks
/// (U+2066 to U+2069), so a Latin name cannot reorder a Hebrew sentence.
/// Invisible characters in source files are easy to lose and the analyzer
/// rightly warns about them, so this rewrites them as visible escapes
/// (backslash, u, four digits) in the files of [folder] ending in
/// [extension]: the same strings, to JSON and to Dart alike.
void _escapeDirectionMarks(Directory folder, String extension) {
  if (!folder.existsSync()) return;
  final marks = RegExp('[\u{2066}-\u{2069}\u{200E}\u{200F}\u{202A}-\u{202E}]');
  for (final file in folder.listSync().whereType<File>()) {
    if (!file.path.endsWith(extension)) continue;
    final source = file.readAsStringSync();
    final escaped = source.replaceAllMapped(
      marks,
      (m) => '\\u${m[0]!.codeUnitAt(0).toRadixString(16).toUpperCase().padLeft(4, '0')}',
    );
    if (escaped != source) file.writeAsStringSync(escaped);
  }
}

List<String> _messageKeys(File arb) {
  final json = jsonDecode(arb.readAsStringSync()) as Map<String, dynamic>;
  return [
    for (final key in json.keys)
      if (!key.startsWith('@')) key,
  ];
}

/// The keys the generator reported as missing in Hebrew. The report is
/// rewritten on every run, so the file always exists and is `{}` when
/// nothing is missing.
List<String> _untranslated(File report) {
  if (!report.existsSync()) {
    report.writeAsStringSync('{}\n');
    return const [];
  }
  final text = report.readAsStringSync().trim();
  if (text.isEmpty) return const [];
  final json = jsonDecode(text) as Map<String, dynamic>;
  return [
    for (final keys in json.values)
      if (keys is List) ...keys.cast<String>(),
  ];
}
