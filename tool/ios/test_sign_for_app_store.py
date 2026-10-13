"""Checks tool/ios/sign_for_app_store.py against the real Xcode project, and
that the Release workflow and ios/ExportOptions.plist name a profile for
every target the app ships.

    python3 -m unittest discover -s tool/ios
"""

import io
import plistlib
import re
import shutil
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

import sign_for_app_store as signing

TEXT = signing.PROJECT.read_text(encoding='utf-8')
TEAM = 'ABCDE12345'
APP = 'org.shnayimmikrah.app'
WIDGET = 'org.shnayimmikrah.app.ParshaWidget'
PROFILES = {APP: 'Shnayim Mikrah App Store', WIDGET: 'Shnayim Mikrah Widget App Store'}


def configuration(text: str, target: str) -> str:
    """The id of a shipped target's Release configuration."""
    return next(id for name, _, id in signing.shipped_targets(text) if name == target)


def configurations(text: str) -> list[str]:
    """The id of every build configuration in the project: each target's
    and the project's, Debug, Release and Profile alike."""
    section = re.search(r'/\* Begin XCBuildConfiguration section \*/\n(.*?)/\* End XCBuildConfiguration section \*/',
                        text, re.DOTALL)
    return re.findall(r'^\t\t(\w+) /\* .*? \*/ = \{', section.group(1), re.MULTILINE)


def settings(text: str, configuration_id: str) -> list[tuple[str, str]]:
    """A build configuration's settings, as its lines give them, in order."""
    start, end = signing._settings(text, configuration_id)
    return [(signing._unquote(key), signing._unquote(value)) for key, value in
            re.findall(r'^\t\t\t\t("[^"\n]*"|[^\s=]+) = (.*);$', text[start:end], re.MULTILINE)]


def outside(text: str, configuration_ids: list[str]) -> str:
    """The project file with the settings of [configuration_ids] taken out."""
    spans = sorted(signing._settings(text, id) for id in configuration_ids)
    kept, at = [], 0
    for start, end in spans:
        kept.append(text[at:start])
        at = end
    return ''.join(kept) + text[at:]


def set_up_in_xcode(text: str, team: str = 'QWERT54321') -> str:
    """The project as Xcode leaves it once the development team is set for
    the app and its widget (docs/RELEASE.md, iOS, Xcode setup): the team and
    automatic signing in each of their configurations."""
    lists = re.findall(r'^\t\t\tbuildConfigurationList = (\w+) /\* Build configuration list for PBXNativeTarget '
                       r'"(Runner|ParshaWidget)" \*/;', text, re.MULTILINE)
    assert len(lists) == 2, lists
    for configuration_list, _ in lists:
        start, end = signing._body(text, configuration_list)
        for configuration_id in re.findall(r'^\t\t\t\t(\w+) /\*', text[start:end], re.MULTILINE):
            text = signing._set(text, configuration_id, 'CODE_SIGN_STYLE', 'Automatic')
            text = signing._set(text, configuration_id, 'DEVELOPMENT_TEAM', team)
    return text


# The project as it is in the repository, and as it will be once someone has
# set the team in Xcode, which signing must cope with alike.
PROJECTS = {'as committed': TEXT, 'set up in Xcode': set_up_in_xcode(TEXT)}


class SignTest(unittest.TestCase):
    def test_the_app_ships_itself_and_its_widget(self):
        self.assertEqual({(name, bundle_id) for name, bundle_id, _ in signing.shipped_targets(TEXT)},
                         {('Runner', APP), ('ParshaWidget', WIDGET)})

    def test_each_release_configuration_is_signed_with_its_own_profile(self):
        signed = signing.sign(TEXT, TEAM, PROFILES)
        for target, bundle_id in (('Runner', APP), ('ParshaWidget', WIDGET)):
            with self.subTest(target):
                release = configuration(signed, target)
                self.assertEqual(signing.setting(signed, release, 'CODE_SIGN_STYLE'), 'Manual')
                self.assertEqual(signing.setting(signed, release, 'DEVELOPMENT_TEAM'), TEAM)
                self.assertEqual(signing.setting(signed, release, 'CODE_SIGN_IDENTITY'), 'Apple Distribution')
                self.assertEqual(signing.setting(signed, release, 'CODE_SIGN_IDENTITY[sdk=iphoneos*]'),
                                 'Apple Distribution')
                self.assertEqual(signing.setting(signed, release, 'PROVISIONING_PROFILE_SPECIFIER'),
                                 PROFILES[bundle_id])
                # The rest of the configuration is as it was.
                self.assertEqual(signing.setting(signed, release, 'PRODUCT_BUNDLE_IDENTIFIER'), bundle_id)

    def test_it_changes_only_the_signing_settings_of_those_two_configurations(self):
        for project, text in PROJECTS.items():
            with self.subTest(project):
                signed = signing.sign(text, TEAM, PROFILES)
                releases = [configuration(text, 'Runner'), configuration(text, 'ParshaWidget')]
                self.assertEqual(releases, [configuration(signed, 'Runner'), configuration(signed, 'ParshaWidget')])
                # Nothing outside their settings.
                self.assertEqual(outside(signed, releases), outside(text, releases))
                for configuration_id in configurations(text):
                    before, after = settings(text, configuration_id), settings(signed, configuration_id)
                    if configuration_id not in releases:
                        # Debug and Profile keep their signing, for builds in
                        # Xcode, and so does everything else.
                        self.assertEqual(after, before, configuration_id)
                        continue
                    bundle_id = signing.setting(text, configuration_id, 'PRODUCT_BUNDLE_IDENTIFIER')
                    signs = {
                        'CODE_SIGN_STYLE': 'Manual',
                        'DEVELOPMENT_TEAM': TEAM,
                        'CODE_SIGN_IDENTITY': signing.IDENTITY,
                        'CODE_SIGN_IDENTITY[sdk=iphoneos*]': signing.IDENTITY,
                        'PROVISIONING_PROFILE_SPECIFIER': PROFILES[bundle_id],
                    }
                    # Each signing setting once, and the others as they were.
                    self.assertEqual([key for key, _ in after if key in signs], sorted(signs))
                    self.assertEqual(dict(after), {**dict(before), **signs})
                    self.assertEqual([item for item in after if item[0] not in signs],
                                     [item for item in before if item[0] not in signs])
                    # In order among the other settings, as Xcode writes them.
                    keys = [key for key, _ in after]
                    self.assertEqual(keys, sorted(keys))

    def test_signing_again_replaces_the_settings(self):
        for project, text in PROJECTS.items():
            with self.subTest(project):
                signed = signing.sign(signing.sign(text, TEAM, PROFILES), 'ZYXWV98765',
                                      {APP: 'Renewed', WIDGET: 'Renewed widget'})
                for target, profile in (('Runner', 'Renewed'), ('ParshaWidget', 'Renewed widget')):
                    keys = [key for key, _ in settings(signed, configuration(signed, target))]
                    self.assertEqual(keys.count('PROVISIONING_PROFILE_SPECIFIER'), 1)
                    self.assertEqual(keys.count('DEVELOPMENT_TEAM'), 1)
                    self.assertEqual(signing.setting(signed, configuration(signed, target), 'DEVELOPMENT_TEAM'),
                                     'ZYXWV98765')
                    self.assertEqual(signing.setting(signed, configuration(signed, target),
                                                     'PROVISIONING_PROFILE_SPECIFIER'), profile)
                self.assertEqual(signing.sign(text, 'ZYXWV98765', {APP: 'Renewed', WIDGET: 'Renewed widget'}),
                                 signed)

    def test_the_fixture_is_set_up_as_xcode_sets_it(self):
        text = PROJECTS['set up in Xcode']
        for target in ('Runner', 'ParshaWidget'):
            release = configuration(text, target)
            self.assertEqual(signing.setting(text, release, 'CODE_SIGN_STYLE'), 'Automatic')
            self.assertEqual(signing.setting(text, release, 'DEVELOPMENT_TEAM'), 'QWERT54321')
        self.assertEqual(text.count('DEVELOPMENT_TEAM = QWERT54321;'), 6)

    def test_names_are_quoted_as_xcode_quotes_them(self):
        name = 'Shnayim "Mikrah" \\ App Store'
        signed = signing.sign(TEXT, TEAM, {**PROFILES, APP: name})
        self.assertIn('PROVISIONING_PROFILE_SPECIFIER = "Shnayim \\"Mikrah\\" \\\\ App Store";', signed)
        self.assertIn(f'DEVELOPMENT_TEAM = {TEAM};', signed)
        self.assertIn('CODE_SIGN_IDENTITY = "Apple Distribution";', signed)
        self.assertEqual(signing.setting(signed, configuration(signed, 'Runner'),
                                         'PROVISIONING_PROFILE_SPECIFIER'), name)
        with self.assertRaises(signing.SigningError):
            signing.sign(TEXT, TEAM, {**PROFILES, APP: 'two\nlines'})

    def test_a_shipped_target_without_a_profile_is_refused(self):
        with self.assertRaisesRegex(signing.SigningError, rf'ParshaWidget \({re.escape(WIDGET)}\)'):
            signing.sign(TEXT, TEAM, {APP: PROFILES[APP]})

    def test_a_profile_for_no_shipped_target_is_refused(self):
        with self.assertRaisesRegex(signing.SigningError, 'org.shnayimmikrah.app.RunnerTests'):
            signing.sign(TEXT, TEAM, {**PROFILES, 'org.shnayimmikrah.app.RunnerTests': 'Tests'})


class ExportOptionsTest(unittest.TestCase):
    OPTIONS = plistlib.loads(signing.EXPORT_OPTIONS.read_bytes())

    def test_it_exports_for_the_app_store_with_manual_signing(self):
        self.assertEqual(self.OPTIONS['method'], 'app-store-connect')
        self.assertEqual(self.OPTIONS['signingStyle'], 'manual')
        self.assertEqual(self.OPTIONS['signingCertificate'], signing.IDENTITY)
        self.assertIs(self.OPTIONS['manageAppVersionAndBuildNumber'], False)

    def test_it_names_a_profile_for_every_shipped_target(self):
        self.assertEqual(set(self.OPTIONS['provisioningProfiles']),
                         {bundle_id for _, bundle_id, _ in signing.shipped_targets(TEXT)})

    def test_the_team_and_profiles_are_filled_in(self):
        options = plistlib.loads(signing.export_options(signing.EXPORT_OPTIONS.read_bytes(), TEAM, PROFILES))
        self.assertEqual(options['teamID'], TEAM)
        self.assertEqual(options['provisioningProfiles'], PROFILES)
        self.assertEqual(options['method'], 'app-store-connect')


class MainTest(unittest.TestCase):
    def setUp(self):
        folder = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, folder)
        self.project = folder / 'project.pbxproj'
        self.options = folder / 'ExportOptions.plist'
        shutil.copy(signing.PROJECT, self.project)
        shutil.copy(signing.EXPORT_OPTIONS, self.options)

    def run_main(self, *arguments: str) -> str:
        output = io.StringIO()
        with redirect_stdout(output), redirect_stderr(io.StringIO()):
            signing.main(['--project', str(self.project), '--export-options', str(self.options), *arguments])
        return output.getvalue()

    def test_it_signs_the_project_and_fills_in_the_export_options(self):
        output = self.run_main('--team', TEAM, '--profile', f'{APP}={PROFILES[APP]}',
                               '--profile', f'{WIDGET}={PROFILES[WIDGET]}')
        self.assertEqual(self.project.read_text(encoding='utf-8'), signing.sign(TEXT, TEAM, PROFILES))
        self.assertEqual(plistlib.loads(self.options.read_bytes())['provisioningProfiles'], PROFILES)
        self.assertIn('ParshaWidget', output)

    def test_it_changes_nothing_when_it_refuses(self):
        for arguments in (
            ['--team', 'abcde12345', '--profile', f'{APP}=A', '--profile', f'{WIDGET}=B'],
            ['--team', TEAM, '--profile', f'{APP}=A'],
            ['--team', TEAM, '--profile', f'{APP}=A', '--profile', f'{WIDGET}='],
            ['--team', TEAM, '--profile', f'{APP}=A', '--profile', f'{WIDGET}=B', '--profile', f'{APP}=C'],
        ):
            with self.subTest(arguments), self.assertRaises(SystemExit) as exit:
                self.run_main(*arguments)
            self.assertNotEqual(exit.exception.code, 0)
            self.assertEqual(self.project.read_text(encoding='utf-8'), TEXT)
            self.assertEqual(self.options.read_bytes(), signing.EXPORT_OPTIONS.read_bytes())


class ReleaseWorkflowTest(unittest.TestCase):
    def test_it_names_a_profile_for_every_shipped_target(self):
        workflow = (signing.ROOT / '.github' / 'workflows' / 'release.yml').read_text(encoding='utf-8')
        self.assertIn('python3 tool/ios/sign_for_app_store.py', workflow)
        self.assertIn('--export-options-plist=ios/ExportOptions.plist', workflow)
        self.assertEqual(set(re.findall(r'--profile "([\w.]+)=', workflow)),
                         {bundle_id for _, bundle_id, _ in signing.shipped_targets(TEXT)})


if __name__ == '__main__':
    unittest.main()
