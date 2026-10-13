#!/usr/bin/env python3
"""Signs the iOS app and its widget extension for the App Store, in the
Release workflow's checkout (.github/workflows/release.yml):

    python3 tool/ios/sign_for_app_store.py --team ABCDE12345 \\
        --profile 'org.shnayimmikrah.app=Shnayim Mikrah App Store' \\
        --profile 'org.shnayimmikrah.app.ParshaWidget=Shnayim Mikrah Widget App Store'

The project in the repository signs automatically, for builds made in Xcode.
This switches the Release configuration of every target the app ships (the
app and each extension embedded in it) to manual signing, with the Apple
Distribution certificate and the App Store profile named for its bundle id,
as Xcode's Signing & Capabilities editor would. Build settings given on the
command line can't: they apply to every target alike, and each of these
needs a profile of its own. It then fills in the team and the profiles in
ios/ExportOptions.plist, which flutter build ipa exports the archive with.

It refuses a shipped target without a profile, and a profile for no target,
so that a new extension can't reach the upload unsigned (docs/RELEASE.md,
iOS).
"""

from __future__ import annotations

import argparse
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / 'ios' / 'Runner.xcodeproj' / 'project.pbxproj'
EXPORT_OPTIONS = ROOT / 'ios' / 'ExportOptions.plist'

# The products the app ships, each signed with a profile of its own. (Unit
# tests and Swift packages are not; the frameworks the app embeds are signed
# with its identity as they are copied.)
SHIPPED = {
    'com.apple.product-type.application',
    'com.apple.product-type.app-extension',
    'com.apple.product-type.extensionkit-extension',
}
# The configuration flutter build ipa archives.
CONFIGURATION = 'Release'
IDENTITY = 'Apple Distribution'
TEAM_ID = re.compile(r'[A-Z0-9]{10}')


class SigningError(Exception):
    pass


def _quote(value: str) -> str:
    """A value as an Xcode project file writes it."""
    if '\n' in value:
        raise SigningError(f'{value!r} spans lines')
    if re.fullmatch(r'[A-Za-z0-9_$./]+', value):
        return value
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'


def _unquote(raw: str) -> str:
    if len(raw) >= 2 and raw[0] == raw[-1] == '"':
        return re.sub(r'\\(.)', r'\1', raw[1:-1])
    return raw


def _body(text: str, object_id: str) -> tuple[int, int]:
    """Where the object `object_id`'s properties are in the project file."""
    match = re.search(rf'^\t\t{object_id}(?: /\*.*?\*/)? = {{\n(.*?)^\t\t}};\n', text,
                      re.MULTILINE | re.DOTALL)
    if not match:
        raise SigningError(f'the project has no object {object_id}')
    return match.span(1)


def _settings(text: str, configuration_id: str) -> tuple[int, int]:
    """Where a build configuration's settings are in the project file."""
    start, end = _body(text, configuration_id)
    match = re.compile(r'^\t\t\tbuildSettings = \{\n(.*?)^\t\t\t\};\n',
                       re.MULTILINE | re.DOTALL).search(text, start, end)
    if not match:
        raise SigningError(f'the build configuration {configuration_id} has no settings')
    return match.span(1)


def _setting_line(key: str) -> re.Pattern[str]:
    return re.compile(rf'^\t\t\t\t{re.escape(_quote(key))} = (.*);\n', re.MULTILINE)


def setting(text: str, configuration_id: str, key: str) -> str | None:
    """A build configuration's own value for `key`, if it has one."""
    start, end = _settings(text, configuration_id)
    match = _setting_line(key).search(text, start, end)
    return _unquote(match.group(1)) if match else None


def _set(text: str, configuration_id: str, key: str, value: str) -> str:
    start, end = _settings(text, configuration_id)
    line = f'\t\t\t\t{_quote(key)} = {_quote(value)};\n'
    existing = _setting_line(key).search(text, start, end)
    if existing:
        return text[:existing.start()] + line + text[existing.end():]
    # In order among the others, as Xcode keeps them.
    at = end
    for match in re.compile(r'^\t\t\t\t("[^"\n]*"|[^\s=]+) = ', re.MULTILINE).finditer(text, start, end):
        if _unquote(match.group(1)) > key:
            at = match.start()
            break
    return text[:at] + line + text[at:]


def shipped_targets(text: str) -> list[tuple[str, str, str]]:
    """(name, bundle id, Release configuration id) of each target the app
    ships."""
    section = re.search(r'/\* Begin PBXNativeTarget section \*/\n(.*?)/\* End PBXNativeTarget section \*/',
                        text, re.DOTALL)
    if not section:
        raise SigningError('the project has no targets')
    targets = []
    for target in re.finditer(r'^\t\t\w+ /\* (.*?) \*/ = \{\n(.*?)^\t\t\};', section.group(1),
                              re.MULTILINE | re.DOTALL):
        name, properties = target.groups()
        product_type = re.search(r'^\t\t\tproductType = "?([^";\n]+)"?;', properties, re.MULTILINE)
        if not product_type or product_type.group(1) not in SHIPPED:
            continue
        configuration_list = re.search(r'^\t\t\tbuildConfigurationList = (\w+)', properties,
                                       re.MULTILINE).group(1)
        start, end = _body(text, configuration_list)
        configuration_id = next((candidate for candidate, configuration_name in re.findall(
            r'^\t\t\t\t(\w+) /\* (.*?) \*/,', text[start:end], re.MULTILINE)
            if configuration_name == CONFIGURATION), None)
        if not configuration_id:
            raise SigningError(f'{name} has no {CONFIGURATION} configuration')
        bundle_id = setting(text, configuration_id, 'PRODUCT_BUNDLE_IDENTIFIER')
        if not bundle_id or '$' in bundle_id:
            raise SigningError(f'{name} has no plain bundle id in its {CONFIGURATION} configuration')
        targets.append((name, bundle_id, configuration_id))
    return targets


def sign(text: str, team: str, profiles: dict[str, str]) -> str:
    """The project file with each shipped target's Release configuration
    signed manually, with the profile named for its bundle id."""
    targets = shipped_targets(text)
    for name, bundle_id, _ in targets:
        if bundle_id not in profiles:
            raise SigningError(f'{name} ({bundle_id}) ships in the app, but no --profile names '
                               'its App Store provisioning profile')
    unused = set(profiles) - {bundle_id for _, bundle_id, _ in targets}
    if unused:
        raise SigningError(f'no target the app ships has the bundle id {", ".join(sorted(unused))}')
    for _, bundle_id, configuration_id in targets:
        for key, value in (
            ('CODE_SIGN_STYLE', 'Manual'),
            ('DEVELOPMENT_TEAM', team),
            ('CODE_SIGN_IDENTITY', IDENTITY),
            # Over the project's own "iPhone Developer" for devices.
            ('CODE_SIGN_IDENTITY[sdk=iphoneos*]', IDENTITY),
            ('PROVISIONING_PROFILE_SPECIFIER', profiles[bundle_id]),
        ):
            text = _set(text, configuration_id, key, value)
    return text


def export_options(data: bytes, team: str, profiles: dict[str, str]) -> bytes:
    """ExportOptions.plist with the team and the profiles filled in."""
    options = plistlib.loads(data)
    options['teamID'] = team
    options['provisioningProfiles'] = dict(profiles)
    return plistlib.dumps(options)


def _profile(argument: str) -> tuple[str, str]:
    bundle_id, separator, name = argument.partition('=')
    if not separator or not bundle_id or not name.strip():
        raise argparse.ArgumentTypeError(f'{argument!r} is not BUNDLE_ID=PROFILE_NAME')
    return bundle_id, name


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--team', required=True, help='the Apple developer team id')
    parser.add_argument('--profile', required=True, action='append', type=_profile,
                        metavar='BUNDLE_ID=PROFILE_NAME',
                        help='the App Store provisioning profile for a shipped target, by its name')
    parser.add_argument('--project', type=Path, default=PROJECT)
    parser.add_argument('--export-options', type=Path, default=EXPORT_OPTIONS)
    args = parser.parse_args(argv)

    if not TEAM_ID.fullmatch(args.team):
        parser.error(f'the team id is ten capital letters and digits, not {args.team!r}')
    profiles = dict(args.profile)
    if len(profiles) != len(args.profile):
        parser.error('a bundle id is given more than one profile')
    try:
        text = args.project.read_text(encoding='utf-8')
        signed = sign(text, args.team, profiles)
        options = export_options(args.export_options.read_bytes(), args.team, profiles)
    except SigningError as error:
        sys.exit(f'sign_for_app_store: {error}')
    args.project.write_text(signed, encoding='utf-8')
    args.export_options.write_bytes(options)
    for name, bundle_id, _ in shipped_targets(signed):
        print(f'{name} ({bundle_id}): {IDENTITY}, profile “{profiles[bundle_id]}”')


if __name__ == '__main__':
    main()
