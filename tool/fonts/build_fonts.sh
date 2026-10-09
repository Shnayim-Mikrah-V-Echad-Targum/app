#!/usr/bin/env bash
# Builds the static display fonts from pinned google/fonts sources
# (docs/DESIGN_SYSTEM.md §4.1). From the repository root:
#
#   pip install -r tool/fonts/requirements.txt
#   bash tool/fonts/build_fonts.sh
#
# Every source is checked against a SHA-256 prefix and cached in
# tool/fonts/.cache. The app never drives a variable font's wght axis, so each
# weight the app asks for is a separate static instance, subset to the
# characters the app can show. The outputs keep the sources' timestamps, so a
# rebuild is byte-for-byte identical.
#
# Writes:
#   assets/fonts/EBGaramond-{Medium,SemiBold,Bold,MediumItalic}.ttf
#   assets/fonts/FrankRuhlLibre-{Medium,SemiBold,Bold}.ttf
#   assets/fonts/rashi/NotoRashiHebrew-Regular.ttf  (a plain asset, loaded lazily)
#   assets/fonts/NotoSansHebrew-{Regular,Medium,Bold}.ttf  (re-instanced; the
#     variable font's default is Thin, so the name table needs updating)
#   assets/fonts/licenses/{EBGaramond,FrankRuhlLibre,NotoRashiHebrew}-OFL.txt
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FONTS="$ROOT/assets/fonts"
CACHE="$ROOT/tool/fonts/.cache"
COMMIT=2eb0b48d5f760f62e286216f0859a8c540dbc1bd
BASE="https://raw.githubusercontent.com/google/fonts/$COMMIT/ofl"
FONTTOOLS_VERSION=4.66

LATIN='U+0020-007E,U+00A0-017F,U+02BB-02BF,U+0300-0331,U+1E00-1EFF,U+2000-206F,U+20AA,U+2190-2193,U+2212'
HEB='U+0020-007E,U+00A0-00FF,U+0591-05F4,U+FB1D-FB4F,U+2000-206F,U+20AA'
RASHI='U+0020-0040,U+0591-05F4,U+FB1D-FB4F,U+2000-206F'
EBG_FEATURES='kern,liga,clig,calt,ccmp,locl,mark,mkmk,lnum,onum,pnum,tnum,smcp,c2sc,case'
# No onum, smcp, c2sc or case: the italic is only used for marginalia.
EBG_ITALIC_FEATURES='kern,liga,clig,calt,ccmp,locl,mark,mkmk,lnum,pnum,tnum'

die() { echo "build_fonts: $*" >&2; exit 1; }

have_version="$(python3 -c 'import fontTools; print(fontTools.version)' 2>/dev/null)" \
  || die 'fontTools is not installed (pip install -r tool/fonts/requirements.txt)'
case "$have_version" in
  "$FONTTOOLS_VERSION" | "$FONTTOOLS_VERSION".*) ;;
  *) die "fontTools $FONTTOOLS_VERSION is required for reproducible output, found $have_version" ;;
esac
command -v pyftsubset > /dev/null || die 'pyftsubset is not on PATH'

sha256() {
  if command -v sha256sum > /dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1
}

# fetch <path under ofl/> <sha256 prefix>: prints the cached file's path.
fetch() {
  local path="$1" want="$2"
  local file="$CACHE/${path//\//__}"
  if [[ ! -f "$file" ]]; then
    mkdir -p "$CACHE"
    local url="$BASE/$path"
    url="${url//\[/%5B}"
    url="${url//\]/%5D}"
    echo "Downloading $path" >&2
    curl -fsSL --retry 3 -o "$file.part" "$url" || die "download failed: $url"
    mv "$file.part" "$file"
  fi
  local got
  got="$(sha256 "$file")"
  if [[ "$got" != "$want"* ]]; then
    rm -f "$file"
    die "$path: SHA-256 $got does not start with $want"
  fi
  echo "$file"
}

EBG="$(fetch 'ebgaramond/EBGaramond[wght].ttf' ef9512f92f6d579e)"
EBG_ITALIC="$(fetch 'ebgaramond/EBGaramond-Italic[wght].ttf' bba2c4499c93c961)"
EBG_OFL="$(fetch 'ebgaramond/OFL.txt' 0985066662eb755e)"
FRL="$(fetch 'frankruhllibre/FrankRuhlLibre[wght].ttf' f9bf26966681037a)"
FRL_OFL="$(fetch 'frankruhllibre/OFL.txt' 4e9720b2544d9467)"
RASHI_VF="$(fetch 'notorashihebrew/NotoRashiHebrew[wght].ttf' 4da0058f46aa66f9)"
RASHI_OFL="$(fetch 'notorashihebrew/OFL.txt' 9b9fe028b5ba74d2)"
NSH="$(fetch 'notosanshebrew/NotoSansHebrew[wdth,wght].ttf' 7ef36a2c3593758c)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# instance <variable font> <output> <axis=value>...
instance() {
  local src="$1" out="$2"
  shift 2
  fonttools varLib.instancer "$src" "$@" --update-name-table --no-recalc-timestamp -q -o "$out"
}

# subset <font> <unicodes> <features> <output>
# Keeps the copyright and license names (0, 13, 14) and the typographic family
# and style (16, 17) that pyftsubset drops by default.
subset() {
  pyftsubset "$1" --unicodes="$2" --layout-features="$3" \
    --name-IDs='0,1,2,3,4,5,6,13,14,16,17' --output-file="$4"
}

for w in 500:Medium 600:SemiBold 700:Bold; do
  instance "$EBG" "$TMP/ebg.ttf" "wght=${w%%:*}"
  subset "$TMP/ebg.ttf" "$LATIN" "$EBG_FEATURES" "$FONTS/EBGaramond-${w##*:}.ttf"
done
instance "$EBG_ITALIC" "$TMP/ebgi.ttf" wght=500
subset "$TMP/ebgi.ttf" "$LATIN" "$EBG_ITALIC_FEATURES" "$FONTS/EBGaramond-MediumItalic.ttf"

for w in 500:Medium 600:SemiBold 700:Bold; do
  instance "$FRL" "$TMP/frl.ttf" "wght=${w%%:*}"
  subset "$TMP/frl.ttf" "$HEB" '*' "$FONTS/FrankRuhlLibre-${w##*:}.ttf"
done

mkdir -p "$FONTS/rashi"
instance "$RASHI_VF" "$TMP/rashi.ttf" wght=400
subset "$TMP/rashi.ttf" "$RASHI" '*' "$FONTS/rashi/NotoRashiHebrew-Regular.ttf"

# Full character set, as before; only the name table changes.
for w in 400:Regular 500:Medium 700:Bold; do
  instance "$NSH" "$FONTS/NotoSansHebrew-${w##*:}.ttf" "wght=${w%%:*}" wdth=100
done

cp "$EBG_OFL" "$FONTS/licenses/EBGaramond-OFL.txt"
cp "$FRL_OFL" "$FONTS/licenses/FrankRuhlLibre-OFL.txt"
cp "$RASHI_OFL" "$FONTS/licenses/NotoRashiHebrew-OFL.txt"

# Checks the outputs and prints their sizes.
python3 - "$FONTS" << 'EOF'
import sys
from pathlib import Path

from fontTools.ttLib import TTFont

fonts = Path(sys.argv[1])
EAGER = {
    'EBGaramond-Medium.ttf': ('EB Garamond', 500),
    'EBGaramond-SemiBold.ttf': ('EB Garamond', 600),
    'EBGaramond-Bold.ttf': ('EB Garamond', 700),
    'EBGaramond-MediumItalic.ttf': ('EB Garamond', 500),
    'FrankRuhlLibre-Medium.ttf': ('Frank Ruhl Libre', 500),
    'FrankRuhlLibre-SemiBold.ttf': ('Frank Ruhl Libre', 600),
    'FrankRuhlLibre-Bold.ttf': ('Frank Ruhl Libre', 700),
}
LAZY = {'rashi/NotoRashiHebrew-Regular.ttf': ('Noto Rashi Hebrew', 400)}
REINSTANCED = {
    'NotoSansHebrew-Regular.ttf': ('Noto Sans Hebrew', 400),
    'NotoSansHebrew-Medium.ttf': ('Noto Sans Hebrew', 500),
    'NotoSansHebrew-Bold.ttf': ('Noto Sans Hebrew', 700),
}
# Lookups the eyebrow style relies on (FontFeature smcp + c2sc), with the
# number of glyphs each maps after subsetting.
SMALL_CAPS = {'smcp': 209, 'c2sc': 204}

errors = []


def name(font, name_id):
    record = font['name'].getName(name_id, 3, 1, 0x409)
    return record.toUnicode() if record else None


def mappings(font, tag):
    gsub = font['GSUB'].table
    lookups = {i for r in gsub.FeatureList.FeatureRecord if r.FeatureTag == tag
               for i in r.Feature.LookupListIndex}
    glyphs = set()
    for i in lookups:
        lookup = gsub.LookupList.Lookup[i]
        for table in lookup.SubTable:
            if lookup.LookupType == 7:
                table = table.ExtSubTable
            glyphs.update(getattr(table, 'mapping', {}))
    return len(glyphs)


def check(rel, family, weight):
    font = TTFont(fonts / rel)
    if 'fvar' in font:
        errors.append(f'{rel}: still variable')
    if font['OS/2'].usWeightClass != weight:
        errors.append(f'{rel}: weight class {font["OS/2"].usWeightClass}, want {weight}')
    typographic = name(font, 16) or name(font, 1)
    if typographic != family:
        errors.append(f'{rel}: family "{typographic}", want "{family}"')
    full = name(font, 4)
    if 'Thin' in full:
        errors.append(f'{rel}: full name "{full}"')
    return font, full


def report(group, table):
    total = 0
    print(group)
    for rel, (family, weight) in table.items():
        font, full = check(rel, family, weight)
        size = (fonts / rel).stat().st_size
        total += size
        extra = ''
        if rel.startswith('EBGaramond-') and 'Italic' not in rel:
            counts = {tag: mappings(font, tag) for tag in SMALL_CAPS}
            for tag, want in SMALL_CAPS.items():
                if counts[tag] != want:
                    errors.append(f'{rel}: {tag} maps {counts[tag]} glyphs, want {want}')
            extra = '  ' + ', '.join(f'{t} {n}' for t, n in counts.items())
        print(f'  {rel:36} {size / 1024:6.1f} KB  {full}{extra}')
    print(f'  {"total":36} {total / 1024:6.1f} KB')


report('Display fonts (bundled, loaded at start-up):', EAGER)
report('Rashi script (plain asset, loaded on first use):', LAZY)
report('Noto Sans Hebrew (re-instanced):', REINSTANCED)

if errors:
    print('\n'.join(['', 'FAILED:', *errors]), file=sys.stderr)
    sys.exit(1)
EOF
