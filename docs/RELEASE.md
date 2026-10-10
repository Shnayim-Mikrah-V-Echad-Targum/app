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
  - The app id and bundle id are `org.shnayimmikra.app`. Change them now if you won't control that domain; they can't be changed after publishing.
  - The display name is "Shnayim Mikra".
- [ ] **Support address.** Set `SUPPORT_EMAIL`. Both stores and the accessibility statement need a working contact.
- [ ] **Public pages.** Both stores need a public URL for each of these:
  - the privacy policy
  - a support page
  - for Google Play, a page where users can **request account deletion**

  The texts are in `lib/features/about/legal_screen.dart`, in English and Hebrew. Publish them on the web build or a simple site. The web build shows them to every visitor, before onboarding too, at `/#/legal/privacy`, `/#/legal/terms`, `/#/legal/guidelines` and `/#/legal/accessibility`.
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
  - Tapping a reminder, with the app running and with it closed, opens Today. The Erev Shabbat reminder opens the week instead, and going back from it leads to Today.
  - Reminders survive a reboot (Android).
  - On Android, the status-bar icon is the three rules of the mark (two long over a shorter one), not a white square or a menu icon, and the Erev Shabbat reminder expands to show its whole message.
- [ ] Listen is audible with the Silent switch on; music ducks and comes back up, and a paused podcast resumes, both when speech finishes and when it is stopped part-way or the reader is left (iOS).
- [ ] Offline: reading, logging and streaks all work in airplane mode.
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

- [ ] Run `flutter build appbundle --release` with the dart-defines from the README, or take the `android` artifact from CI.

**Play Console**

- [ ] **Data safety:**
  - Collected only when the user uses the community: email address (account management), user-generated content (posts) and user IDs.
  - Collected only if the user opts in: app activity (reading progress, for backup).
  - Encrypted in transit.
  - Users can delete their data in the app, and through the account-deletion URL.
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

- [ ] Run `flutter build windows --release`, or take the `windows` artifact from CI.
- [ ] Package it as MSIX for the Microsoft Store or for sideloading (for example with the `msix` package), or wrap it in an installer.
- [ ] Sign it with a code-signing certificate; unsigned apps trigger SmartScreen warnings. Store submissions are signed by Microsoft.
- [ ] Check with Narrator and NVDA, using the keyboard only, at 200% display scaling.
- [ ] Launching the app while it is already running brings the open window forward, restoring it if minimized, and opens no second window. Closing it and launching it again at once opens it.
- [ ] A reminder toast carries the three-rule mark as its icon.

## Web

- [ ] Run `flutter build web --release --no-web-resources-cdn --base-href /<path>/`. The CI job does the same, and can deploy to GitHub Pages when `DEPLOY_WEB=true`.
- [ ] Serve it over HTTPS. Cache `canvaskit/` and fonts for a long time. Don't cache `index.html`, `flutter_bootstrap.js` or `flutter_service_worker.js`.
- [ ] If you use a Content-Security-Policy, allow:
  - `'wasm-unsafe-eval'` for CanvasKit
  - your Supabase URL in `connect-src`
  - `fonts.gstatic.com` in `connect-src` if you want emoji fallback fonts (see [DESIGN.md §9](DESIGN.md#9-typography))
- [ ] Check with NVDA + Chrome and VoiceOver + Safari.
