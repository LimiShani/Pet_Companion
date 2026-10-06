"""Check feature UI boundaries and prove omitted UI has no entry-point imports.

Run after configure_features.py. Shared services/resources are intentionally
retained; only the selected product modules may be reachable from main.dart.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
lib = root / 'lib'
pattern = re.compile(r"^\s*(?:import|export)\s+['\"]([^'\"]+)['\"]", re.MULTILINE)

def dependencies(path):
    for uri in pattern.findall(path.read_text(encoding='utf-8')):
        if uri.startswith('package:pet_companion/'):
            yield (lib / uri.removeprefix('package:pet_companion/')).resolve()
        elif not uri.startswith(('dart:', 'package:')):
            yield (path.parent / uri).resolve()

errors = []
for folder in ['services', 'presentation', 'platform', 'state', 'widgets', 'access']:
    for path in (lib / folder).rglob('*.dart'):
        for target in dependencies(path):
            if target.is_relative_to(lib / 'features'):
                errors.append(f'{path.relative_to(root)} imports UI {target.relative_to(root)}')

composition = (lib / 'composition/modules.g.dart').read_text(encoding='utf-8')
selected = set(re.findall(r"features/([^/]+)/module.dart", composition))
core = {'auth', 'home', 'settings'}
pending = [lib / 'main.dart']
seen = set()
while pending:
    path = pending.pop().resolve()
    if path in seen or not path.exists():
        continue
    seen.add(path)
    if path.is_relative_to(lib / 'features'):
        feature = path.relative_to(lib / 'features').parts[0]
        if feature not in selected | core:
            errors.append(f'Omitted module {feature} remains reachable: {path.relative_to(root)}')
    pending.extend(dependencies(path))

if errors:
    print('\n'.join(sorted(set(errors))))
    sys.exit(1)
print(f'Feature boundaries passed; {len(seen)} local Dart files reachable; UI modules: {", ".join(sorted(selected)) or "none"}.')
