"""Builds lib/l10n/app_he.arb from tool/l10n/he_strings.py and reports any
keys of the English template that are missing a Hebrew translation."""
import collections
import json
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from he_strings import HE  # noqa: E402

root = os.path.dirname(os.path.dirname(here))
en = json.load(open(os.path.join(root, 'lib/l10n/app_en.arb')), object_pairs_hook=collections.OrderedDict)
keys = [k for k in en if not k.startswith('@')]
missing = [k for k in keys if k not in HE]
extra = [k for k in HE if k not in en]
out = collections.OrderedDict([('@@locale', 'he')])
for k in keys:
    if k in HE:
        out[k] = HE[k]
with open(os.path.join(root, 'lib/l10n/app_he.arb'), 'w') as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
    f.write('\n')
print(f'{len(out) - 1} Hebrew strings written')
if extra:
    print('Unknown keys:', extra)
if missing:
    print('MISSING:', missing)
    sys.exit(1)
