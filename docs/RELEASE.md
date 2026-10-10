# Release checklist

## Decisions to make before the first public release

- [ ] **Rabbinic review.** A rav reviews:
  - the defaults and copy listed in [DESIGN.md §11](DESIGN.md#11-things-for-the-rabbinic-advisor)
  - the in-app guide (*About → About Shnayim Mikra*)
  - the halachic notes shown in settings
- [ ] **License for the app's source code.** No license has been chosen yet; choose one and add a `LICENSE` file. The bundled texts keep their own licenses:
  - The MAM Hebrew text is CC BY-SA 4.0. Its attribution is shown under *About → Texts & sources*, and changes to that text must stay under the same license.
  - Taamey Frank is GPL-2.0 with a font exception. It is shipped as an unmodified separate file. If you'd rather ship only OFL fonts, remove it; [assets/fonts/licenses/README.md](../assets/fonts/licenses/README.md) lists every place to change.
- [ ] **Identity:**
  - The app id, bundle id and MSIX identity name are `org.shnayimmikra.app`. Change them now if you won't control that domain; they can't be changed after publishing.
  - The display name is "Shnayim Mikra".
- [ ] **Support address.** Set `SUPPORT_EMAIL`, as a repository variable for CI. Both stores and the accessibility statement need a working contact, and without one the account-deletion page offers no way to ask by email.
- [ ] **Public pages.** Both stores need a public URL for each of these, and the web build has them as static pages that work without JavaScript, in English and in Hebrew (add `.he` before `.html`):
  - the privacy policy: `<web address>/legal/privacy.html`
  - a support page: `<web address>/legal/support.html`
  - for Google Play, a page where users can **request account deletion**: `<web address>/legal/delete-account.html`
  - also the terms of use, the community guidelines and the accessibility statement: `legal/terms.html`, `legal/guidelines.html` and `legal/accessibility.html`

  CI writes them after the web build with `node tool/legal/build_html.mjs build/web`. The texts the app shows come from `lib/features/about/legal_screen.dart`; the support and account-deletion pages, which only the web has, are in `assets/legal/legal.json`.
- [ ] **Community backend.** Set it up per [BACKEND.md](BACKEND.md):
  - custom SMTP
  - the OTP email template
  - at least two moderators appointed
- [ ] **Moderation commitment.** Someone checks reports at least daily. Both stores expect timely action on user-generated content.

## Every release

### Version
- [ ] Bump `version:` in `pubspec.yaml`. The `+N` build number must increase for every store upload.
- [ ] Write release notes in English and Hebrew.

### Automated checks
- [ ] CI is green on the release commit: analysis, all tests, SQL tests, and builds for all four platforms.
- [ ] `python3 tool/l10n/build_he.py` produces no diff. Every new string has a Hebrew translation.

### Calendar and content spot-checks
- [ ] For the coming year, compare the app's parsha for 10 or so Shabbatot against a printed luach, for both Israel and the Diaspora. Include any weeks where the two diverge and every double portion.
- [ ] Special haftarot for the coming year: Shekalim, Zachor, Parah, HaChodesh, HaGadol, Shabbat Rosh Chodesh, Machar Chodesh, Chanukah and Shuva.
- [ ] Simchat Torah: Vezot HaBerakhah opens and closes correctly in Israel and the Diaspora.
- [ ] Bamidbar 32:3 shows the third-reading prompt.
- [ ] A Hebrew reader checks every icon on a device at home-screen size and at 1024 px: it reads שמו״ת with ש on the right. Regenerate icons only with `tool/branding/make_icon.py` (see the comment above `flutter_launcher_icons` in `pubspec.yaml`).

### Behaviour on real devices
- [ ] Fresh install: onboarding reaches the first verse, and that aliyah can be read to completion.
- [ ] Upgrading from the previous version keeps settings and progress.
- [ ] **Reminders across a real Shabbat**, on Android and iOS, in two time zones:
  - The daily reminder arrives.
  - The Erev Shabbat reminder arrives before midday.
  - Nothing fires on Shabbat.
  - Reminders survive a reboot (Android).
- [ ] Offline: reading, logging and streaks all work in airplane mode.
- [ ] Launch and system bars, from a cold start, in light and dark mode: iOS, Android 11, and Android 14 or later.
  - The launch screen is the mark's tile on cream (light) or lamplight brown (dark), with no white flash before or after it.
  - The status and navigation bars are the colour of the screen beneath them, and their icons are legible: dark on Welcome's cream. Check three-button navigation on Android 9 and 10, gesture navigation on Android 14 or later, and an app theme that differs from the system's.
- [ ] Predictive back, Android 15 or later (or Android 14 with *Developer options → Predictive back animations* on): a back gesture on Today previews the home screen.
- [ ] Shortcuts on the app's icon, on Android and iOS, in English and Hebrew: long-pressing the icon shows Continue reading, Log reading from a book and This week's parsha, in the app's language and with the app's icon (on iOS, the mark). Each opens its page with back leading to Today: from a cold start, with the app in the background, and with its process stopped in the background (on Android, *Don't keep activities* in the developer options). Afterwards, the plain icon opens the app where it was left, not the shortcut's page again.
- [ ] Android system backup: after `adb shell bmgr backupnow org.shnayimmikra.app`, reinstalling the app restores its settings and progress.
- [ ] Community against the production backend:
  - sign in with a code
  - post, edit and delete
  - report and block
  - process a report as a moderator
  - delete an account
- [ ] Cloud backup: sign in on two devices and confirm progress merges both ways, and that marking an aliyah as not read, clearing a week, ending a pause and resetting all progress reach the other device.
- [ ] Data export and import round-trip.

### Accessibility
- [ ] Run the manual checklist in [ACCESSIBILITY.md](ACCESSIBILITY.md#manual-before-each-release) on at least one device per platform, with that platform's screen reader. Record who tested what.

## Android (Google Play)

**Signing**

- [ ] Create an upload keystore once and keep it backed up somewhere safe:
  ```sh
  keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
- [ ] For local builds, put the keystore in `android/app/` and create `android/key.properties`. Both are git-ignored.
  ```
  storeFile=upload-keystore.jks
  storePassword=…
  keyAlias=upload
  keyPassword=…
  ```
- [ ] For CI builds, add these repository secrets:
  - `ANDROID_KEYSTORE_BASE64` (the output of `base64 -w0 upload-keystore.jks`)
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`
- [ ] Enrol in Play App Signing.

**Build**

- [ ] Run `flutter build appbundle --release` with the dart-defines from the README, or take the `android` artifact from CI. A build without the keystore ends with "RELEASE BUILD SIGNED WITH DEBUG KEY", and CI names its artifact `android-debug-signed`: Google Play refuses it.

**Play Console**

- [ ] **Data safety:**
  - Collected only when the user uses the community: email address (account management), user-generated content (posts) and user IDs.
  - Collected only if the user opts in: app activity (reading progress, for backup).
  - Encrypted in transit.
  - Users can delete their data in the app, and through the account-deletion URL (`legal/delete-account.html`).
  - No data is shared with third parties.
  - No ads and no analytics.
- [ ] **Content rating questionnaire:** users can interact and share content (forums), with moderation, reporting and blocking.
- [ ] **Target audience:** not designed for children. If you list it for under-13s, the forum needs a review under the Families policy.
- [ ] **Permissions:**
  - Notifications: requested in context, after the first reading.
  - Boot completed: so reminders survive a reboot.
  - No exact alarms: reminders use inexact scheduling, so no special declaration is needed.
- [ ] **Store listing:**
  - screenshots in English and Hebrew, for phone and tablet
  - feature graphic
  - a description that mentions the accessibility features

## iOS (App Store)

**Xcode setup**

- [ ] Open `ios/Runner.xcworkspace` and set the development team and bundle id.
- [ ] Enable the push notification capability only if you add remote push. Local notifications don't need it.

**Build**

- [ ] Run `flutter build ipa --release` with the dart-defines, then upload with Transporter or Xcode.

**App Store Connect**

- [ ] **App Privacy ("nutrition labels"):**
  - Contact info: email address, used for app functionality, linked to the user.
  - User content: posts, used for app functionality, linked to the user.
  - Identifiers: user ID, linked to the user.
  - Usage data (reading progress): only with opt-in backup, linked to the user.
  - No tracking.
- [ ] **Guideline 1.2 (user-generated content):** all of these are in the app. Mention them in the review notes:
  - content filtering
  - reporting
  - blocking
  - published contact information
  - acceptance of the terms before posting
- [ ] **Guideline 5.1.1(v), account deletion:** available under *Community → Account → Delete my account*.
- [ ] **Sign in with Apple** isn't required, because the app has no third-party social login (email code only).
- [ ] **Export compliance:** the app uses only standard HTTPS. `ITSAppUsesNonExemptEncryption` is set to `false` in Info.plist.
- [ ] **Age rating:** answer the user-generated-content questions honestly. Expect 12+ or 13+.
- [ ] **Review notes:** a demo account isn't needed, because sign-in creates an account. Say that the community is moderated and how to reach the moderators.

## Windows

The app ships as an MSIX package. Its settings are `msix_config` in `pubspec.yaml`, and its icons are in `windows/msix`, written by `tool/branding/make_icon.py --post`.

**Version**

- [ ] The package's version is `version:` from `pubspec.yaml` as `major.minor.patch.0`: the `+N` build number is ignored. Windows only installs an update over a lower version, so every Windows release needs a new `major.minor.patch`.

**Signing**

- [ ] For sideloading, get a code-signing certificate (`.pfx`). Its subject becomes the package's publisher, and must stay the same from release to release, or Windows treats the update as a different app.
- [ ] For CI builds, add these repository secrets:
  - `WINDOWS_CERTIFICATE_BASE64` (the output of `base64 -w0 certificate.pfx`)
  - `WINDOWS_CERTIFICATE_PASSWORD`
- [ ] Without the certificate, the package is signed with the msix tool's public test certificate, and CI names its artifact `windows-msix-test-signed`. Windows installs it only where that certificate is trusted. On a test machine, never a user's: open the `.msix` file's *Properties → Digital Signatures → Details → View Certificate → Install Certificate*, and place it in *Local Machine → Trusted People*.
- [ ] For the Microsoft Store, reserve the app's name in Partner Center. Then package it with `--store` and the values under *Product identity*. The Store signs the package itself.
  ```sh
  bash tool/windows/make_msix.sh --store --identity-name … --publisher "CN=…" --publisher-display-name …
  ```

**Build**

- [ ] Run `flutter build windows --release` with the dart-defines from the README. Then, in Git Bash, run `bash tool/windows/make_msix.sh`, adding `--certificate-path certificate.pfx --certificate-password …` to sign it. The installer is `build/windows/msix/ShnayimMikra.msix`.
- [ ] Or take the `windows-msix` artifact from CI. The `windows` artifact is the same build unpackaged.

**Checks**

- [ ] Install the MSIX on Windows 10 and Windows 11:
  - Start, the taskbar and *Settings → Apps* show the app's icon. At small sizes, such as the taskbar at 100% scaling, the icon is the three rules alone.
  - They name the app in Windows's display language: Shnayim Mikra, or שניים מקרא with Hebrew first in *Settings → Time & language → Language*, as does the header of a reminder's notification. (`tool/windows/make_msix.sh` stops if the package's `resources.pri` lacks the Hebrew name.)
  - The window opens centred on the screen it was launched from, and no larger than 90% of it. It can't be made smaller than 380 × 560 at 100% scaling, and scales that minimum at 150% and 200%.
  - The title bar follows the app's theme: choosing *Dark* in the app darkens it, even when Windows is light, and the reverse. With the app following the system, switching Windows between light and dark switches it too. Check this on a Windows 10 older than version 2004 as well (1809, as in Enterprise LTSC 2019, up to 1909), which numbers the setting differently.
  - A reminder's notification opens the app, also when it is already running.
- [ ] Check with Narrator and NVDA, using the keyboard only, at 200% display scaling.

## Web

- [ ] Run `flutter build web --release --no-web-resources-cdn --base-href /<path>/`, then `node tool/legal/build_html.mjs build/web` for the static pages and, last, `npx --yes workbox-cli@7.4.1 generateSW workbox-config.cjs` for the offline service worker (`sw.js`). The CI job does the same, and can deploy to GitHub Pages when `DEPLOY_WEB=true`.
- [ ] Set the repository variable `WEB_URL` to the site's public address, such as `https://example.org/app/`. CI then makes the link previews' URLs absolute, as most sites that show previews require.
- [ ] Serve it over HTTPS. Cache `canvaskit/` and fonts for a long time. Don't cache `index.html`, `flutter_bootstrap.js`, `sw.js` or `flutter_service_worker.js` (the browsers of earlier visitors still check it, and Flutter's version now unregisters itself).
- [ ] In Chrome DevTools (*Application → Manifest*), the app has no installability errors, and installing it shows the richer dialog, with screenshots. The screenshots are `web/screenshots/`, taken from the capture harness; after a redesign, take them again:
  ```sh
  CAPTURE=1 SCREENS=today,reader MODES=phone,desktop flutter test test/screens/capture_test.dart
  cp build/screens/phone_today.png web/screenshots/today-narrow.png
  cp build/screens/phone_reader.png web/screenshots/reader-narrow.png
  cp build/screens/desktop_today.png web/screenshots/today-wide.png
  ```
- [ ] Offline: install the app, open a book, then in DevTools (*Network → Offline*) reload. The app opens, and so does that book.
- [ ] With the app's theme set to Dark, the installed app's title bar (and the browser's toolbar on Android) turns dark once the app has drawn its first frame. The loading screen before it already shows the app's theme and language.
- [ ] Sharing the address in a messaging app shows the preview card (`web/og.png`).
- [ ] If you use a Content-Security-Policy, allow:
  - `'wasm-unsafe-eval'` for CanvasKit
  - your Supabase URL in `connect-src`
  - `fonts.gstatic.com` in `connect-src` if you want emoji fallback fonts (see [DESIGN.md §9](DESIGN.md#9-typography))
- [ ] Check with NVDA + Chrome and VoiceOver + Safari.
