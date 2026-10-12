"""List strings (ARB keys) that no Dart code refers to.

    py -3 tool/find_unused_strings.py            every module
    py -3 tool/find_unused_strings.py health     one module (or several)

The modules and their folders are read from tool/gen_l10n.dart, so a new
module is picked up without editing this script. For each module, every
key of its English file (`<name>_en.arb`) is looked for as `.<key>` (a
getter, a tear-off or a call `.<key>(`) in every Dart file under lib/ and
test/, leaving out the generated `gen/` folders. Inside an extension on the
module's generated class (`extension HealthWords on HealthL10n`), where the
strings are written without a receiver, the bare `<key>` counts too.

The result is a list to review by hand, not a list to delete: a key can be
used without its name being written out, for example when code builds the
name or picks the string from a map. A key that is only reached from an
extension method nobody calls is not listed either.
Exit code 1 when anything is listed, so it can also guard a CI step.
"""
from pathlib import Path
import json
import re
import sys

root = Path(__file__).resolve().parents[1]

MODULE = re.compile(r"L10nModule\('([^']+)',\s*'([^']+)',\s*'([^']+)'")
MEMBER = re.compile(r'\.([A-Za-z_]\w*)')
IDENTIFIER = re.compile(r'[A-Za-z_]\w*')
EXTENSION = re.compile(r'\bextension\s+\w*\s*on\s+(\w+)')


def modules():
    return MODULE.findall((root / 'tool' / 'gen_l10n.dart').read_text(encoding='utf-8'))


def dart_sources():
    for folder in ('lib', 'test'):
        for path in (root / folder).rglob('*.dart'):
            if 'gen' in path.relative_to(root).parts:
                continue
            yield path.read_text(encoding='utf-8')


def main(args):
    chosen = [m for m in modules() if not args or m[0] in args]
    unknown = set(args) - {m[0] for m in chosen}
    if unknown:
        print(f'Unknown module: {", ".join(sorted(unknown))}', file=sys.stderr)
        return 64

    # Every `.identifier` written anywhere in the code.
    used = set()
    # Every identifier in a file with an extension on a generated class.
    in_extensions = {}
    for text in dart_sources():
        used.update(MEMBER.findall(text))
        for owner in set(EXTENSION.findall(text)):
            in_extensions.setdefault(owner, set()).update(IDENTIFIER.findall(text))

    total = 0
    for name, folder, class_name in chosen:
        seen = used | in_extensions.get(class_name, set())
        arb = json.loads((root / folder / f'{name}_en.arb').read_text(encoding='utf-8'))
        keys = [k for k in arb if not k.startswith('@')]
        unused = [k for k in keys if k not in seen]
        total += len(unused)
        print(f'{name} ({folder}): {len(unused)} of {len(keys)} unused')
        for key in unused:
            print(f'  {key}')
    return 1 if total else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
