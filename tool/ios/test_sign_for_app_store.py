"""Checks tool/ios/sign_for_app_store.py against the real Xcode project, and
that the Release workflow and ios/ExportOptions.plist name a profile for
every target the app ships.

    python3 -m unittest discover -s tool/ios
"""

import difflib
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
APP = 'org.shnayimmikra.app'
WIDGET = 'org.shnayimmikra.app.ParshaWidget'
PROFILES = {APP: 'Shnayim Mikra App Store', WIDGET: 'Shnayim Mikra Widget App Store'}


def configuration(text: str, target: str) -> str:
    """The id of a shipped target's Release configuration."""
    return next(id for name, _, id in signing.shipped_targets(text) if name == target)


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

    def test_it_only_adds_the_signing_settings_to_those_two_configurations(self):
        signed = signing.sign(TEXT, TEAM, PROFILES)
        changes = [line for line in difflib.unified_diff(TEXT.splitlines(), signed.splitlines(), n=0, lineterm='')
                   if line[:1] in '+-' and line[:3] not in ('+++', '---')]
        self.assertEqual(len(changes), 10)
        self.assertTrue(all(line.startswith('+\t\t\t\t') for line in changes), changes)
        # Debug and Profile keep automatic signing, for builds in Xcode.
        self.assertEqual(signed.count('PROVISIONING_PROFILE_SPECIFIER'), 2)
        self.assertNotIn('PROVISIONING_PROFILE_SPECIFIER', TEXT)
        # In order among the other settings, as Xcode writes them.
        release = configuration(signed, 'Runner')
        start, end = signing._settings(signed, release)
        keys = [signing._unquote(key) for key in
                re.findall(r'^\t\t\t\t("[^"\n]*"|[^\s=]+) = ', signed[start:end], re.MULTILINE)]
        self.assertIn('CODE_SIGN_IDENTITY[sdk=iphoneos*]', keys)
        self.assertEqual(keys, sorted(keys))

    def test_signing_again_replaces_the_settings(self):
        signed = signing.sign(signing.sign(TEXT, TEAM, PROFILES), 'ZYXWV98765',
                              {APP: 'Renewed', WIDGET: 'Renewed widget'})
        self.assertEqual(signed.count('PROVISIONING_PROFILE_SPECIFIER'), 2)
        self.assertEqual(signed.count('DEVELOPMENT_TEAM'), 2)
        self.assertEqual(signing.setting(signed, configuration(signed, 'ParshaWidget'),
                                         'PROVISIONING_PROFILE_SPECIFIER'), 'Renewed widget')

    def test_names_are_quoted_as_xcode_quotes_them(self):
        name = 'Shnayim "Mikra" \\ App Store'
        signed = signing.sign(TEXT, TEAM, {**PROFILES, APP: name})
        self.assertIn('PROVISIONING_PROFILE_SPECIFIER = "Shnayim \\"Mikra\\" \\\\ App Store";', signed)
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
        with self.assertRaisesRegex(signing.SigningError, 'org.shnayimmikra.app.RunnerTests'):
            signing.sign(TEXT, TEAM, {**PROFILES, 'org.shnayimmikra.app.RunnerTests': 'Tests'})


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
