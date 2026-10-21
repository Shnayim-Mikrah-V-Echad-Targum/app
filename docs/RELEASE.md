# Release checklist

## Decisions to make before the first public release

- [ ] **Rabbinic review.** A rav reviews:
  - the defaults and copy listed in [DESIGN.md §11](DESIGN.md#11-things-for-the-rabbinic-advisor)
  - the in-app guide (*Settings → How it works*)
  - the halachic notes shown in settings
  - the places where the Torah text departs from MAM to follow Ashkenazi and Sephardi scrolls, and the notes that give the Aleppo Codex's reading there ("The scribal tradition" in `tool/data/build_data.mjs`)
- [ ] **License for the app's source code.** No license has been chosen yet; choose one and add a `LICENSE` file. The bundled texts keep their own licenses:
  - The MAM Hebrew text is CC BY-SA 4.0. Its attribution is shown under *About → Texts & sources*, and changes to that text must stay under the same license.
  - Taamey Frank is GPL-2.0 with a font exception. It is shipped as an unmodified separate file. If you'd rather ship only OFL fonts, remove it; [assets/fonts/licenses/README.md](../assets/fonts/licenses/README.md) lists every place to change.
- [x] **Identity:**
  - The domain is `shnayimmikrah.org`.
  - The app id, bundle id and MSIX identity name follow it: `org.shnayimmikrah.app`. They can't be changed after publishing.
  - The iOS widget extension is `org.shnayimmikrah.app.ParshaWidget`, and its App Group is `group.org.shnayimmikrah.app`.
  - The display name is "Shnayim Mikrah", spelled with an h everywhere.
- [ ] **The web address.** Serve the web build at `https://shnayimmikrah.org/`, in this order:
  - Verify the domain for the organization first, so no one else can claim it on GitHub Pages: *Organization settings → Pages → Add a domain*, then add the `TXT` record GitHub shows (`_github-pages-challenge-shnayim-mikrah-v-echad-targum.shnayimmikrah.org`) at the registrar and click *Verify*.
  - In the repository's *Settings → Pages*, set *Source* to *GitHub Actions* (CI deploys with `actions/deploy-pages`), set the custom domain to `shnayimmikrah.org`, and tick *Enforce HTTPS* once the certificate is issued.
  - At the registrar, point the apex at GitHub Pages with four `A` records (`185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`) and four `AAAA` records (`2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153`), and add a `CNAME` record for `www` to `shnayim-mikrah-v-echad-targum.github.io`.
  - Set the repository variables `DEPLOY_WEB=true`, `WEB_BASE_HREF=/` and `WEB_URL=https://shnayimmikrah.org/`.
  - The store listings' privacy, support and account-deletion URLs are then `https://shnayimmikrah.org/legal/privacy.html`, `…/legal/support.html` and `…/legal/delete-account.html`.
  - With the site at the domain's root, Android App Links and iOS Universal Links for discussion URLs become possible (`/.well-known/assetlinks.json` and `/.well-known/apple-app-site-association`).
- [ ] **Builds from before the rename are a different app.** Test builds made before the name took its h (`org.shnayimmikra.app`, "Shnayim Mikra") don't upgrade to the new one: it installs beside them, with its own data. Before switching, export a backup from the old build (*Settings → Your data*) or turn on cloud backup; then uninstall the old build, so its reminders and widget stop; then import the file in the new one (a backup from the old build still imports) or sign in again.
- [ ] **Never change the Windows data folder's names.** On Windows, settings, progress and notes live in `%APPDATA%\<CompanyName>\<ProductName>`, from `windows/runner/Runner.rc` (now `Shnayim Mikrah\Shnayim Mikrah`). Changing either after publishing loses every reader's local data; `test/app/windows_package_test.dart` pins them.
- [ ] **Support address.** Set up mail for the domain (for example `support@shnayimmikrah.org`) and set `SUPPORT_EMAIL` to it, as a repository variable for CI and the [Release workflow](#the-release-workflow), which builds nothing without it. Both stores and the accessibility statement need a working contact, and without one the account-deletion page offers no way to ask by email.
- [ ] **Public pages.** Both stores need a public URL for each of these, and the web build has them as static pages that work without JavaScript, in English and in Hebrew (add `.he` before `.html`):
  - the privacy policy: `<web address>/legal/privacy.html`
  - a support page: `<web address>/legal/support.html`
  - for Google Play, a page where users can **request account deletion**: `<web address>/legal/delete-account.html`
  - also the terms of use, the community guidelines and the accessibility statement: `legal/terms.html`, `legal/guidelines.html` and `legal/accessibility.html`

  CI writes them after the web build with `node tool/legal/build_html.mjs build/web`. All the texts are in `assets/legal/legal.json`: the policies, which the app shows too, and the support and account-deletion pages, which only the web has. When a policy changes, also update the month it was last updated (`updated`), which the app and the pages show under its title. The web app itself also shows the policies to every visitor, before onboarding too, at `/legal/privacy`, `/legal/terms`, `/legal/guidelines` and `/legal/accessibility`. Before its service worker is in (a first visit), GitHub Pages answers those addresses with the static pages, which say the same: it serves `legal/privacy.html` for `/legal/privacy`. Once it is in, the app shows them offline too, as the service worker precaches their text.
- [ ] **Community backend.** Set it up per [BACKEND.md](BACKEND.md):
  - custom SMTP
  - the OTP email template
  - at least two moderators appointed
  - a mailbox for the stores' reviewers, all three of them (*Review access*, under [iOS](#ios-app-store))
- [ ] **Moderation commitment.** Someone checks reports at least daily. Both stores expect timely action on user-generated content.

## Every release

### Version
- [ ] Write this release's notes in English and Hebrew, and commit them before tagging: the workflow uploads the tagged commit's with the bundle. Google Play's are `store/play/whatsnew/whatsnew-en-US` and `whatsnew-iw-IL`, up to 500 characters each (`tool/store` checks them); the Release workflow stops before it builds anything if they haven't changed since the last release's tag. Give the App Store's *What's New* the same text when submitting. The draft GitHub release lists the merged pull requests: write its notes over them before publishing it.
- [ ] Bump the version name in `pubspec.yaml`, merge, then push tag `vX.Y.Z`. The Release workflow checks the configuration, then uploads to Play internal testing (draft), TestFlight, and a draft GitHub release with the MSIX. Promote from there.
  - The tag is the version name, the `X.Y.Z` of `version: X.Y.Z+N`; if they differ, the workflow stops before it builds anything.
  - Every release needs a new version name: Windows installs an update only over a lower version, and the App Store reviews each version once.
  - The workflow numbers each build 1000 plus its run number, as Android's version code and iOS's build number, which each store wants higher with every upload. The `+N` in `pubspec.yaml` is only for builds made by hand; keep it below 1000. If a job fails, re-run only the failed jobs: a re-run keeps the run's number, and a store refuses a build number it already has. Don't rename `release.yml`: its run numbers would start again from 1.

### The Release workflow
`.github/workflows/release.yml` builds only with the production configuration. Its first job checks that everything below is set, names each setting that isn't, and stops before any build, so that no store build ships the on-device demo community, without backup or a support address. Set them under *Settings → Secrets and variables → Actions*.
- [ ] **Repository variables:**
  - `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`: the production community ([BACKEND.md](BACKEND.md)).
  - `SUPPORT_EMAIL`: the support address.
  - `WEB_URL`: the site's public address ([Web](#web)), which the stores' support and privacy URLs are on, and which a discussion's *Copy link* begins with.
  - `IOS_TEAM_ID`, `IOS_PROFILE_NAME` and `IOS_WIDGET_PROFILE_NAME`: the Apple team, and the names of the App Store profiles of the app and its widget ([iOS](#ios-app-store)).
  - `INSTALL_URL` is optional, as in CI.
- [ ] **Repository secrets:**
  - `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`: the upload key ([Android](#android-google-play)).
  - `PLAY_SERVICE_ACCOUNT_JSON`: the service account that uploads to Google Play ([Android](#android-google-play)).
  - `IOS_DIST_CERT_P12_BASE64` and `IOS_DIST_CERT_PASSWORD`: the Apple Distribution certificate ([iOS](#ios-app-store)).
  - `IOS_PROVISIONING_PROFILE_BASE64` and `IOS_WIDGET_PROVISIONING_PROFILE_BASE64`: the App Store profiles themselves ([iOS](#ios-app-store)).
  - `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_PRIVATE_KEY`: the App Store Connect API key that uploads to TestFlight ([iOS](#ios-app-store)).
  - `WINDOWS_CERTIFICATE_BASE64` and `WINDOWS_CERTIFICATE_PASSWORD`: the code-signing certificate ([Windows](#windows)).
- [ ] **The first release** on Google Play is uploaded by hand, because the Play Developer API can't create an app's first release: that run's upload to Google Play fails, and its `android-release-aab` artifact holds the AAB to upload in Play Console (*Testing*, under [Android](#android-google-play)). Every later release uploads itself. On iOS, create the app in App Store Connect before the first run.
- CI's artifacts (`.github/workflows/ci.yml`, its Android one named `android-ci`) are never for the stores: CI builds with whatever configuration it has, pull requests from forks in demo mode and without signing, and doesn't number its builds. Besides what it uploads, a release run keeps the Android debug symbols (`android-symbols`), for `flutter symbolize`, and the IPA (`ios`), which Transporter can upload if the TestFlight step fails.

### Automated checks
- [ ] CI is green on the release commit: analysis, all tests, SQL tests, and builds for all four platforms.
- [ ] `python3 tool/l10n/build_he.py` produces no diff. Every new string has a Hebrew translation.

### Calendar and content spot-checks
- [ ] For the coming year, compare the app's parsha for 10 or so Shabbatot against a printed luach, for both Israel and the Diaspora. Include any weeks where the two diverge and every double portion.
- [ ] Special haftarot for the coming year: Shekalim, Zachor, Parah, HaChodesh, HaGadol, Shabbat Rosh Chodesh, Machar Chodesh, Chanukah and Shuva.
- [ ] Simchat Torah: Vezot HaBerachah opens and closes correctly in Israel and the Diaspora.
- [ ] Bamidbar 32:3 shows the third-reading prompt.

### Design checks
The goldens in `test/goldens/` hold the main screens in every theme and in both languages, and CI fails when they change. These checks cover what they can't see ([DESIGN_SYSTEM.md §11.6](DESIGN_SYSTEM.md#11-tests-and-qa)):
- [ ] **The icon,** on a device, at 48 px and at 1024 px: a Hebrew reader checks that every icon reads שמו״ת with ש on the right. Regenerate icons only with `tool/branding/make_icon.py` (see the comment above `flutter_launcher_icons` in `pubspec.yaml`).
- [ ] **The name under the icon,** on a Pixel at the launcher's default grid and on an iPhone at the default text size, in English and Hebrew: it isn't cut off. Check the installed web app's too, on the same Pixel (Chrome) and iPhone (Safari's *Add to Home Screen*). If the English is cut off, set a shorter label as `app_name` in `android/app/src/main/res/values/strings.xml` (the widget's title before onboarding, too), as `CFBundleDisplayName` in `ios/Runner/en.lproj/InfoPlist.strings` (and in `ios/Runner/Info.plist`, its fallback), and for the web app as `short_name` in `web/manifest.json` (Android's) and `apple-mobile-web-app-title` in `web/index.html` (iOS's); keep "Shnayim Mikrah" as the name in the stores.
- [ ] **TalkBack and VoiceOver on the reader's aliyah ribbon and PassTrack,** in English and Hebrew:
  - Each tab of the ribbon is read as one button, with its name, its number and how far it is read ("Shlishi, aliyah 3 of 7, …"), and the open one as selected. Swiping moves through the tabs in reading order, right to left in Hebrew, and scrolls the ribbon to keep each in view.
  - The PassTrack itself is silent. Its step is read once, as it changes, in the step's announcement ("Read the Hebrew again. Reading 2 of 3. Verse 1 of 14"), never twice.
- [ ] **Windows Contrast Themes** (*Settings → Accessibility → Contrast themes*), with the app's theme following the system: choosing any of them (Aquatic, Desert, Dusk, Night sky) switches the app at once to its high-contrast theme, dark or light as Windows's own mode is, and choosing None switches it back. Text, focus rings, switches and the reader stay legible, and the title bar follows.
- [ ] **The home-screen widget's preview** for older Android launchers (`android/app/src/main/res/drawable-nodpi/widget_preview.png`, written by `tool/branding/make_widget_preview.py`): a Hebrew reader checks that בְּרֵאשִׁית is whole and reads right to left.
- [ ] **Every `he_*` screen of the capture harness** (`CAPTURE=1 MODES=he flutter test test/screens/capture_test.dart`, then `build/screens/he_*.png`), reviewed by a Hebrew reader: chevrons and arrows point the Hebrew way, rules stand at the start (the right), pips run right to left, and the ribbon's underline sits under the open aliyah.

### Store listing
The stores' text, screenshots and Google Play's feature graphic come from the app and the repository, never by hand:
- [ ] After any visible change to the screens they show, take the screenshots again. The capture harness renders them in the light theme, in English and Hebrew, at the stores' sizes: the App Store's 6.9" iPhone (1320 × 2868) and 13" iPad (2064 × 2752), and Google Play's phone (1080 × 1920) and 10" tablet (1600 × 2560). They show a reader some weeks into the year, with nothing overdue and no streak counts, each page scrolled to end between its cards where the screen allows, and never through a line of text (`store_*` in `test/screens/capture_test.dart`), and each device only what can be done on it: the Targum beside each verse on the iPad alone. `tool/store/frame.py` sets each on Klaf under its headline, without alpha, in `build/store/<ios|ipad|play|playtab>/<en-US|he>/`, numbered in their order. The feature graphic is the link preview's title block:
  ```sh
  CAPTURE=1 MODES=storeios,storeioshe,storeipad,storeipadhe,storeplay,storeplayhe,storeplaytab,storeplaytabhe flutter test test/screens/capture_test.dart
  python3 tool/store/frame.py
  python3 tool/branding/make_icon.py --feature-graphic
  ```
- [ ] The text is in `store/`, in fastlane's layout: `store/play/<en-US|iw-IL>/` as supply reads it, `store/ios/<en-US|he>/` as deliver does; and the Microsoft Store's descriptions, entered by hand, in `store/windows/<en-us|he-il>/description.txt`. `python3 -m unittest discover -s tool/store` (in CI) checks every field against the stores' limits. Before uploading, replace `<WEB_URL>` in `store/ios/*/support_url.txt` and `privacy_url.txt` with the site's address, the repository variable `WEB_URL` (`https://shnayimmikrah.org/`).
- [ ] The text describes the app as it is, with no endorsement claimed, and names its options as the app does (the plans, say): update it when a feature it names changes. A Hebrew reader approves the Hebrew text, and the Hebrew headlines on the screenshots with where each line breaks, before upload.

### Behaviour on real devices
- [ ] Fresh install: onboarding reaches the first verse, and that aliyah can be read to completion.
- [ ] Upgrading from the previous version keeps settings and progress.
- [ ] **Reminders across a real Shabbat**, on Android and iOS, in two time zones:
  - The daily reminder arrives.
  - The Erev Shabbat reminder arrives before midday.
  - Nothing fires on Shabbat.
  - With the city for Shabbat times set to where the device is: a daily reminder set for the evening arrives on Friday between two and a half hours and an hour and a half before candle-lighting (Android may deliver it up to an hour late), never later, Today shows candle-lighting that Friday, and the check-in arrives on Motzaei Shabbat an hour after Shabbat ends.
  - With the city set elsewhere, as when travelling, Today shows the countdown to Shabbat rather than candle-lighting, and reminders keep to midday.
  - Tapping a reminder, with the app running and with it closed, opens Today. The Erev Shabbat reminder opens the week instead, and going back from it leads to Today.
  - Android: after the Erev Shabbat reminder has opened the app from closed, press Home, stop the app in the background (*Don't keep activities* in the developer options, or `adb shell am kill org.shnayimmikrah.app`), and come back to it through Recents: Today shows, with no week over it. The same again, coming back from the plain icon, shows Today too.
  - Reminders survive a reboot (Android), and one missed while the phone was off doesn't come late: switch the phone off before a reminder is due and on again more than an hour after it. Nothing is posted as it starts, and the next reminder still arrives. Switched on within the hour, the missed one arrives at once.
  - On Android, the status-bar icon is the three rules of the mark (two long over a shorter one), not a white square or a menu icon, and the Erev Shabbat reminder expands to show its whole message.
- [ ] Listen, on Android, iOS, Windows and the web: the highlight follows the voice verse by verse, in the full text with each Targum; pause and play go on from the same verse; back and on a verse, and a new speech rate, take effect at once, with no verse skipped or cut short; and Listen along reads Mikrah, Mikrah and Targum hands-free and stops at the aliyah's last step.
- [ ] Listen is audible with the Silent switch on; music ducks and comes back up, and a paused podcast resumes, both when speech finishes and when it is stopped part-way, paused or the reader is left, and music stays ducked from one verse to the next and through Listen along's breath between readings (iOS).
- [ ] While listening, lock the phone or switch apps: speech pauses at its verse, and Play continues from the start of that verse.
- [ ] Android: music ducks under Listen and comes back up when it stops, staying ducked from verse to verse; an incoming call pauses Listen (Android and iOS).
- [ ] Offline: reading, logging and streaks all work in airplane mode.
- [ ] Launch and system bars, from a cold start, in light and dark mode: iOS, Android 11, and Android 14 or later.
  - The launch screen is the mark's tile on cream (light) or lamplight brown (dark), with no white flash before or after it.
  - With the app's theme set to Dark on a light system (and Light on a dark one), a cold start on Android 12 or later shows the dark (light) launch screen, and with it following the system again, the system's. iOS and Android 11 and earlier show the system's launch screen, which is accepted.
  - The status and navigation bars are the colour of the screen beneath them, and their icons are legible: dark on Welcome's cream. Check three-button navigation on Android 9 and 10, gesture navigation on Android 14 or later, and an app theme that differs from the system's.
- [ ] Predictive back, Android 15 or later (or Android 14 with *Developer options → Predictive back animations* on): a back gesture on Today previews the home screen, also while another tab has a page open; on Parsha, Progress, Community or Settings it returns to Today without previewing the home screen, and leaves a page open in Today as it was. With this week's page opened from Today, then Progress tapped and Back pressed (or Today tapped), Back and a back gesture each close the week before anything else, and only then does a back gesture preview the home screen. A back gesture over a dialog closes the dialog alone.
- [ ] Shortcuts on the app's icon, on Android and iOS, in English and Hebrew: long-pressing the icon shows Continue reading, Log a Chumash reading and This week's parsha, in the app's language and with the app's icon (on iOS, the mark). Each opens its page with back leading to Today: from a cold start, with the app in the background, and with its process stopped in the background (on Android, *Don't keep activities* in the developer options). Afterwards, the plain icon opens the app where it was left, not the shortcut's page again.
- [ ] **The home-screen widget**, on Android (a launcher of Android 12 or later, and one of Android 11 or earlier) and iOS, small and medium, in English and Hebrew, in light and dark mode ([DESIGN_SYSTEM.md §6.30](DESIGN_SYSTEM.md#630-home-screen-widgets-android-and-ios)):
  - The picker or gallery shows its preview, with its name and description in the device's language.
  - Added after onboarding, it shows this week's parsha, its three bars and today's reading at once; before onboarding, "Open Shnayim Mikrah to begin."
  - Marking a reading, or changing the language, the transliteration, vowels or Israel/Diaspora, changes it within a few seconds, and it follows the app's language, mirrored in Hebrew, whatever the device's.
  - Tapping it opens Today, and Continue opens the reader where Today's button leads, with back leading to Today: from a cold start, with the app in the background, and with its process stopped (on Android, *Don't keep activities*). Afterwards the plain icon opens the app where it was left.
  - Without opening the app, it turns to the next day after 3 a.m., and on Erev Shabbat to Shabbat Shalom with no bars or Continue (with a city for Shabbat times, at candle-lighting), back to the reading after Shabbat; on Android after a reboot too.
  - Left for longer than its days (set the clock two weeks on, to a weekday), it shows the parsha and asks to open the app; set to a Shabbat three weeks on, it shows only the candles and Shabbat Shalom.
  - On iOS, with the iPhone's calendar set to Buddhist, and then to Japanese (*Settings → General → Language & Region → Calendar*), it still shows today's reading, turns to the next day after 3 a.m., and shows Shabbat Shalom on Shabbat.
  - On the night the clocks go forward (set the zone and date just before a change), it turns to the new day three hours after midnight, at 4 o'clock on the new clock, not a day late.
  - TalkBack and VoiceOver read the widget as one sentence (the parsha, how far each reading has come and today's reading), and Continue as a button of its own.
  - Nothing is cut short at the largest text size, nor at its smallest height (two rows, in landscape; Android 14 at 200%): the names shrink to fit, a long greeting (G'mar Chatimah Tovah, גמר חתימה טובה) takes two lines (three in the narrowest Android widget), and on Android lines that don't fit are left out, the aliyot read first. On iOS its text grows with the text size up to xxxLarge and stays there at the accessibility sizes, set smaller where the small widget has no room.
- [ ] Android system backup: after `adb shell bmgr backupnow org.shnayimmikrah.app`, reinstalling the app restores its settings and progress.
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
- [ ] For the Release workflow, and CI's signed builds, add these repository secrets:
  - `ANDROID_KEYSTORE_BASE64` (the output of `base64 -w0 upload-keystore.jks`)
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`
- [ ] Enrol in Play App Signing.
- [ ] For the Release workflow's uploads, create a service account in Google Cloud, with a JSON key. In Play Console, under *Users and permissions*, invite its email address, with permission to release this app to testing tracks. Add the key file's contents as the repository secret `PLAY_SERVICE_ACCOUNT_JSON`.

**Build**

- [ ] The Release workflow builds the bundle and uploads it to internal testing as a draft: roll it out there, then promote it. To build one by hand, run `flutter build appbundle --release` with the dart-defines from the README, the backend's and `SUPPORT_EMAIL` all set. A build without the keystore ends with "RELEASE BUILD SIGNED WITH DEBUG KEY" (as CI's `android-ci-debug-signed` artifact is): Google Play refuses it. Never upload CI's `android-ci` artifact, which has whatever configuration CI has: the demo community, if a variable is missing.

**Play Console**

- [ ] **Testing:** if the developer account is a personal account created after 13 November 2023, run a closed test with at least 12 testers opted in for 14 consecutive days before applying for production access. Otherwise start with internal testing. Upload the first AAB by hand in Play Console: the Play Developer API can't create an app's first release. Take it from the Release workflow's `android-release-aab` artifact (that run's own upload fails for the same reason); later releases upload themselves.
- [ ] **App content:**
  - Privacy policy: `<web address>/legal/privacy.html`.
  - Ads: no.
  - App access: all or some functionality is restricted; give the reviewer mailbox, as under *Review access* for [iOS](#ios-app-store).
  - Advertising ID: not used (no ads or analytics, and no `AD_ID` permission).
  - Government app: no. Financial features: none. Health: none. News app: no.
  - Data safety, the content rating and the target audience, below.
- [ ] **Data safety:**
  - Collected only when the user uses the community: email address (account management), user-generated content (posts) and user IDs.
  - Collected only if the user opts in, for backup: app activity (reading progress) and user-generated content (bookmarks, and the notes the user writes on verses, up to 2,000 characters each). Neither is shared or shown to anyone else.
  - Encrypted in transit.
  - Users can delete their data in the app, and through the account-deletion URL (`legal/delete-account.html`).
  - No data is shared with third parties.
  - No ads and no analytics.
- [ ] **Content rating questionnaire:** users can interact and share content (forums), with moderation, reporting and blocking.
- [ ] **Target audience:** not designed for children. If you list it for under-13s, the forum needs a review under the Families policy.
- [ ] **Permissions:**
  - Notifications: requested in context, after the first reading.
  - Boot completed: so reminders, and the home-screen widget's turn to each new day, survive a reboot.
  - No exact-alarm permission: from Android 12 reminders and the widget's updates use inexact scheduling, which the planner allows an hour for, and before it exact alarms, which need no permission there. No special declaration is needed.
- [ ] **Store listing,** in en-US and iw-IL (Hebrew), from the [store listing kit](#store-listing):
  - the title, short and full description in `store/play/en-US/` and `store/play/iw-IL/`
  - the feature graphic, `store/play/feature-graphic.png` (1024 × 500, no alpha)
  - six phone screenshots (1080 × 1920) from `build/store/play/`, and six 10" tablet screenshots (1600 × 2560) from `build/store/playtab/`: `en-US/` for English, `he/` for iw-IL

## iOS (App Store)

**Xcode setup**

- [ ] Open `ios/Runner.xcworkspace` and set the development team and bundle id, for both targets: **Runner** (`org.shnayimmikrah.app`) and **ParshaWidget** (`org.shnayimmikrah.app.ParshaWidget`), the home-screen widget's extension, which is embedded in the app and must be signed by the same team. Its version follows the app's, from Flutter's generated settings, which `ios/ParshaWidget/ParshaWidget.xcconfig` includes. Keep that file as its base configuration rather than `Flutter/Debug.xcconfig` or `Release.xcconfig`: `flutter build` adds the app's CocoaPods settings to those, which would link the extension against the app's frameworks and the Flutter engine. CI checks that it links none of them.
- [ ] **App Group** `group.org.shnayimmikrah.app`, through which the app hands the widget what it shows: register it in the Apple developer portal (*Identifiers → App Groups*), enable the App Groups capability for both App IDs with that group, and make sure both provisioning profiles (the app's and the extension's) include it. Xcode's automatic signing does all of this once the team is set. Both targets' entitlements already name the group (`ios/Runner/Runner.entitlements`, `ios/ParshaWidget/ParshaWidget.entitlements`). Without it the app still runs, but the widget never gets its days and shows "Open Shnayim Mikrah to begin." CI's build is unsigned and needs none of this.
- [ ] Enable the push notification capability only if you add remote push. Local notifications don't need it.
- [ ] **Privacy manifests:** the widget extension's `ios/ParshaWidget/PrivacyInfo.xcprivacy` declares the one required-reason API it calls, reading the App Group's user defaults (`NSPrivacyAccessedAPICategoryUserDefaults`, reason `1C8F.1`), and that it collects and tracks nothing; without it App Store Connect refuses the upload (ITMS-91053). Declare there any such API the extension comes to call (`test/app/home_widget_platform_test.dart` checks the ones it knows). The app's own come from Flutter and its plugins, each with a manifest of its own; home_widget, which saves the widget's timeline in the App Group, has none, but shared_preferences declares the same category and reason in the app. If an upload is ever refused for the Runner binary's user defaults, add a `PrivacyInfo.xcprivacy` to Runner's resources declaring them with `1C8F.1`.

**Signing for the Release workflow**

- [ ] An **Apple Distribution certificate**, from *Certificates* in the developer portal or from Xcode. Export it with its private key from Keychain Access, as a `.p12` with a password, and add the repository secrets `IOS_DIST_CERT_P12_BASE64` (the output of `base64 -i distribution.p12`) and `IOS_DIST_CERT_PASSWORD`.
- [ ] Two **App Store provisioning profiles** (*Profiles → Distribution → App Store Connect*), both with that certificate and the App Group: one for `org.shnayimmikrah.app`, one for the widget, `org.shnayimmikrah.app.ParshaWidget`. Add each profile's name as a repository variable, `IOS_PROFILE_NAME` and `IOS_WIDGET_PROFILE_NAME`, and its file as a secret, `IOS_PROVISIONING_PROFILE_BASE64` and `IOS_WIDGET_PROVISIONING_PROFILE_BASE64` (`base64 -i <file>.mobileprovision`). The workflow stops if a profile has another name, team or bundle id, or isn't an App Store profile.
- [ ] `IOS_TEAM_ID`: the team id, under *Membership details* in the developer account.
- [ ] An **App Store Connect API key** (*Users and Access → Integrations → App Store Connect API*), with the App Manager role: add `ASC_KEY_ID` (the key's id), `ASC_ISSUER_ID` (the issuer id above the list of keys) and `ASC_PRIVATE_KEY` (the contents of the `.p8` file, which can be downloaded only once).
- [ ] The certificate and the profiles expire after a year. Renew them, and their secrets, before then.
- The project in the repository signs automatically, for builds in Xcode. In its own checkout, the workflow switches the Release configuration of the app and its widget to manual signing with those profiles (`tool/ios/sign_for_app_store.py`), and exports the archive with `ios/ExportOptions.plist`. An extension added to the app needs an App Store profile of its own, in the workflow and in `ios/ExportOptions.plist`; until it has one, the script stops the build.

**Build**

- [ ] The Release workflow builds the IPA and uploads it to TestFlight. To build one by hand, run `flutter build ipa --release` with the dart-defines from the README, the backend's and `SUPPORT_EMAIL` all set, then upload it with Transporter or Xcode.

**App Store Connect**

- [ ] **TestFlight:** before the first upload, create the app (*Apps → New App*, bundle id `org.shnayimmikrah.app`). Once the Release workflow's build has been processed, add internal testers, and run the [checks on real devices](#behaviour-on-real-devices) on the TestFlight build.
- [ ] **Localizations:** English (U.S.), from `store/ios/en-US/`, and Hebrew, from `store/ios/he/`: the name (שניים מקרא in Hebrew), subtitle, keywords, promotional text, description and support and privacy URLs, from the [store listing kit](#store-listing). Screenshots for each: six for the 6.9" iPhone (1320 × 2868) from `build/store/ios/`, and six for the 13" iPad (2064 × 2752) from `build/store/ipad/`, from `en-US/` and `he/`.
- [ ] **App Privacy ("nutrition labels"):**
  - Contact info: email address, used for app functionality, linked to the user.
  - User content: posts, used for app functionality, linked to the user.
  - Identifiers: user ID, linked to the user.
  - Usage data (reading progress): only with opt-in backup, linked to the user.
  - User content, other user content (bookmarks and notes on verses): only with opt-in backup, used for app functionality, linked to the user.
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
- [ ] **Review access.** Signing in takes a six-digit code sent by email, and reviewers sign in only with what the review notes give them, on every store. Without a way in, expect a rejection under Guideline 2.1 on iOS, for App access on Google Play, and in the Microsoft Store's certification for content that can't be tested.
  - Create a reviewer mailbox on the support domain (such as `review@shnayimmikrah.org`) whose webmail the reviewer can open. Use it for nothing else, and give it no two-step verification or new-device challenge, which a reviewer can't pass.
  - In App Store Connect, under *App Review Information*, tick *Sign-in required*, enter the address as the user name and the mailbox's password as the password, and put the webmail URL and the steps below in the notes. In Play Console, give the same under *App content → App access* ("All or some functionality is restricted"), and in Partner Center under *Submission options → Notes for certification* ([Windows](#windows)). They belong there only, never in this repository.
  - The steps to give: open *Community → Sign in*, enter the address, read the six-digit code in the mailbox and type it, and the first time, choose a display name.
  - The account has no moderator role. If a reviewer deletes it, as they may to check account deletion, signing in again with the same address makes a new one.
  - Before each submission, sign in with it once to confirm the code arrives.
- [ ] **Review notes:** with the review access above, say that the community is moderated and how to reach the moderators.

## Windows

The app ships as an MSIX package. Its settings are `msix_config` in `pubspec.yaml`, and its icons are in `windows/msix`, written by `tool/branding/make_icon.py --post`.

**Version**

- [ ] The package's version is `version:` from `pubspec.yaml` as `major.minor.patch.0`: the `+N` build number is ignored. Windows only installs an update over a lower version, so every Windows release needs a new `major.minor.patch`.

**Signing**

- [ ] For sideloading, get a code-signing certificate (`.pfx`). Its subject becomes the package's publisher, and must stay the same from release to release, or Windows treats the update as a different app.
- [ ] For the Release workflow, and CI's signed builds, add these repository secrets:
  - `WINDOWS_CERTIFICATE_BASE64` (the output of `base64 -w0 certificate.pfx`)
  - `WINDOWS_CERTIFICATE_PASSWORD`
- [ ] Without the certificate, the package is signed with the msix tool's public test certificate, and CI names its artifact `windows-msix-test-signed`. Windows installs it only where that certificate is trusted. On a test machine, never a user's: open the `.msix` file's *Properties → Digital Signatures → Details → View Certificate → Install Certificate*, and place it in *Local Machine → Trusted People*.
- [ ] For the Microsoft Store, reserve the app's name in Partner Center. Then package it with `--store` and the values under *Product identity*. The Store signs the package itself.
  ```sh
  bash tool/windows/make_msix.sh --store --identity-name … --publisher "CN=…" --publisher-display-name …
  ```

**Build**

- [ ] The Release workflow packages the MSIX, signed with the certificate, and attaches it to a draft GitHub release for the tag: publish the release once the installer is checked.
- [ ] To build one by hand, run `flutter build windows --release` with the dart-defines from the README, the backend's and `SUPPORT_EMAIL` all set. Then, in Git Bash, run `bash tool/windows/make_msix.sh`, adding `--certificate-path certificate.pfx --certificate-password …` to sign it. The installer is `build/windows/msix/ShnayimMikrah.msix`. The folder still runs as it is on any PC afterwards: the msix tool deletes the Visual C++ runtime from `build/windows/x64/runner/Release` once it has packed it, and the script puts it back, even when signing fails (`test/app/windows_package_test.dart` runs the script with stand-ins for the tool).
- CI's `windows-msix` artifact (and `windows`, the same build unpackaged) has whatever configuration CI has: release the draft's installer, not CI's.

**Checks**

- [ ] Install the MSIX on Windows 10 and Windows 11:
  - Start, the taskbar and *Settings → Apps* show the app's icon. At small sizes, such as the taskbar at 100% scaling, the icon is the three rules alone.
  - They name the app in Windows's display language: Shnayim Mikrah, or שניים מקרא with Hebrew first in *Settings → Time & language → Language*, as does the header of a reminder's notification. (`tool/windows/make_msix.sh` stops if the package's `resources.pri` lacks the Hebrew name.)
  - The window first opens centred on the screen it was launched from, and no larger than 90% of it; after that it reopens where it was closed, maximized if it was, fitted to its screen's work area if part of it would no longer be on it, and centred again if that screen is gone. Check each: move and resize it, close it and launch it again; close it maximized, and minimized from maximized (it reopens maximized, never minimized); close it snapped to half the screen, or into a snap layout (it reopens there, no longer snapped); close it on a second screen at another scaling (it reopens there, the same size), then disconnect that screen and launch it; close it large on a laptop's larger external screen, then undock (or lower the resolution) and launch it: it lies wholly on the screen, clear of the taskbar, its bottom bar and resize corner within reach; move it, then restart Windows with the app open and launch it (it reopens where it was moved to). It can't be made smaller than 380 × 560 at 100% scaling, and scales that minimum at 150% and 200%.
  - The title bar, the taskbar button and Alt+Tab name the window in the app's language: choosing Hebrew in the app's *Settings → Language* renames it שניים מקרא at once, and English back to Shnayim Mikrah; following the system, it takes Windows's display language.
  - The title bar follows the app's theme: choosing *Dark* in the app darkens it, even when Windows is light, and the reverse. With the app following the system, switching Windows between light and dark switches it too. Check this on a Windows 10 older than version 2004 as well (1809, as in Enterprise LTSC 2019, up to 1909), which numbers the setting differently.
  - A reminder's notification opens the app on the reminder's page: Today, or the week for the Erev Shabbat reminder (set one a couple of minutes ahead in *Settings → Reminders*). Check it with the app closed, and with it running, both minimized and behind another window: the window comes forward, restored if it was minimized (maximized, if it was before). (`bringWindowForward` in `lib/app/window_title_bar.dart`, answered in `windows/runner/flutter_window.cpp`; `test/services/notification_response_test.dart`.)
  - The mouse's back button, Alt+← and a keyboard's Back key go back, as Back does on Android: they close a sheet, a dialog or a page (the reader too), and from the root of another tab return to Today. On Today they do nothing, and the app stays open. They go back from a text field too, such as Search's. The reader's shortcuts (F1) list Alt+←, as closing the reader.
- [ ] Check with Narrator and NVDA, using the keyboard only, at 200% display scaling.
- [ ] Launching the app while it is already running brings the open window forward, restoring it if minimized, and opens no second window. Closing it and launching it again at once opens it, even launched the moment its window vanishes, while the app is still shutting down. (A closing window is marked with `kClosingProperty`, and a launch waits for it to go: `windows/runner/main.cpp`; `test/app/windows_instance_test.dart`.)
- [ ] **It opens, whatever has become of its preferences.** With the app closed, replace its preferences file, `shared_preferences.json` in `%APPDATA%\Shnayim Mikrah\Shnayim Mikrah` (for the MSIX, in `%LOCALAPPDATA%\Packages\<the package's family name>\LocalCache\Roaming\Shnayim Mikrah\Shnayim Mikrah`), with one cut short (delete its second half in Notepad) or, as a power cut can leave it, one of NUL bytes (in PowerShell, `[IO.File]::WriteAllBytes("<the file>", (New-Object byte[] 4096))`). Launch the app: it opens on Welcome, the damaged file lies beside the new one as `shared_preferences.json.corrupt`, and About offers *Copy details for support*, whose text says the preferences were set aside. Progress logged then is still there after closing the app and launching it again. (`lib/services/preferences_recovery.dart`; `test/services/preferences_recovery_test.dart` and `test/app/main_test.dart`.)
- [ ] **No hidden window.** The window appears with the app's first frame, and even should the app never draw one, about 10 seconds after launch, blank, so that it can be closed: check once with a build for this alone, with `await Completer<void>().future;` as the first line of `_start` in `lib/main.dart`. Launching it again in those seconds opens no second window; once it has appeared and been closed, the app launches again. (`FlutterWindow::ShowOnce` in `windows/runner/flutter_window.cpp`; `test/app/windows_start_test.dart` checks the source.)
- [ ] A reminder toast carries the three-rule mark as its icon.
- [ ] **Reminders from the folder.** Run the app unpackaged, from CI's `windows` artifact, on a PC without the MSIX (which shares its toast activator, and may be the app a click launches). Set a reminder a couple of minutes ahead and close the app: clicking the notification launches it, on the reminder's page. Move the folder, launch the app from its new place once, close it and check again. (`RegisterToastActivatorServer` in `windows/runner/main.cpp`; `test/app/windows_package_test.dart`.)

**Microsoft Store (Partner Center)**

- [ ] Store listings in en-us and he-il, the package's two languages: the description from `store/windows/en-us/description.txt` and `store/windows/he-il/description.txt` (Google Play's, with Windows's screen readers and without the home-screen widget; `tool/store` checks them), and at least one desktop screenshot of 1366 × 768 or larger: `build/screens/desktop_today.png` and `build/screens/deskhe_today.png` (1366 × 860), from `CAPTURE=1 SCREENS=today MODES=desktop,deskhe flutter test test/screens/capture_test.dart`.
- [ ] *Submission options → Notes for certification:* the reviewer mailbox's webmail URL, its address and password, and the steps to sign in, as under *Review access* for [iOS](#ios-app-store), so that Microsoft's testers reach the community (reporting, blocking and account deletion among it). Say too that the community is moderated, and how to reach the moderators.
- [ ] The privacy policy URL: `<web address>/legal/privacy.html`.
- [ ] The age rating (IARC) questionnaire: users can interact and share content (forums), with moderation.
- [ ] The support contact: the support address, or `<web address>/legal/support.html`.

## Web

- [ ] Run `flutter build web --release --no-web-resources-cdn --base-href /` (the site is at the domain's root), then `node tool/web/preload_fonts.mjs build/web` to preload every start-up font from `index.html`, `node tool/legal/build_html.mjs build/web` for the static pages, `cp build/web/index.html build/web/404.html` so that every page's address opens the app and, last, `npx --yes workbox-cli@7.4.1 generateSW workbox-config.cjs` for the offline service worker (`sw.js`), then `node tool/web/sw_build.cjs check build/web`, which fails if the worker leaves out a file the app needs to open offline (Workbox only warns). The CI job does the same, and can deploy to GitHub Pages when `DEPLOY_WEB=true`.
- [ ] The first load is within its budget. CI's *Build web* job fails when `main.dart.js`, gzipped, is larger than the repository variable `BUDGET_MAIN_JS_GZIP` (in bytes), or without it `1527297` bytes: the size measured once the time-zone database was deferred to its own part (1454568 bytes, built with Flutter 3.47.7 and the backend configured; some 35 KB less without it), plus 5%. The job's summary gives the size, with the deferred parts and the start-up fonts. Raise the budget only for a change worth what it adds to every first visit: set the variable, or change the number here and in `ci.yml` together (the web tests check that they agree).
- [ ] Set the repository variable `WEB_URL` to the site's public address, `https://shnayimmikrah.org/`. CI then makes the link previews' URLs absolute, as most sites that show previews require, and a discussion's menu offers *Copy link*, its address on the site, in every build with the community backend (not in the on-device demo, whose discussions are each device's own).
- [ ] Each page has an address of its own, such as `<web address>/community/thread/<id>`. GitHub Pages answers an address it has no file for with `404.html`, a copy of `index.html`, so the app opens there; on another host, serve `index.html` for any address that isn't a file. Check that a discussion's address, pasted into a new tab, opens it, and in a browser that has never opened the app, opens it once onboarding is done (beneath the reader onboarding ends on); that a page reloaded stays where it was; that the site's address with what a link adds to it (`<web address>/?fbclid=abc`, `?utm_source=x`) or `<web address>/index.html` opens Today; that a link from before path URLs, `<web address>/#/progress`, opens Progress at `<web address>/progress`; and that the installed app's shortcuts (Today, Progress) open their pages, in its open window too.
  - On GitHub Pages, those addresses are answered with status 404, though the page is the app. Some sites show no preview for a link that answers so (Facebook's debugger reports a bad response code; X's cards need 200), so a shared discussion may have no preview card there, where the site's own address has one. A host that serves `index.html` for unknown addresses with status 200 (a rewrite on Cloudflare Pages or Netlify, say) avoids this. `404.html` also names the site's own address as every page's `og:url`.
- [ ] Serve it over HTTPS. Let browsers keep `canvaskit/` and `assets/` only if they revalidate them (`Cache-Control: no-cache`, with an ETag or Last-Modified): their URLs stay the same from one release to the next, and the service worker keeps them for offline use anyway. So too `main.dart.js` and its deferred parts, `main.dart.js_*.part.js` (the time-zone database among them), which must always come from the same release: a part that doesn't match the main script fails to load, and with it a city's times and the list of cities. GitHub Pages serves everything with `max-age=600`, so for ten minutes after a deploy a visitor whose page the service worker doesn't control (a first visit, a private window) may mix them; a host that sets the headers avoids it. Don't cache `index.html`, `404.html`, `flutter_bootstrap.js`, `sw.js` or `flutter_service_worker.js` (the browsers of earlier visitors still check it, and Flutter's version now unregisters itself). The scripts `sw.js` imports, `workbox-<hash>.js` and `sw_update.<hash>.js`, are named after their content, so a copy the browser keeps is always the right one: a new version's worker never runs an older version's update script, even within GitHub Pages' ten minutes.
- [ ] In Chrome DevTools (*Application → Manifest*), the app has no installability errors, and installing it shows the richer dialog, with screenshots. The screenshots, `web/screenshots/`, are written by `test/goldens/screens_golden_test.dart` and updated with `--update-goldens` along with the other goldens.
- [ ] Offline: install the app, choose a city for Shabbat times, open a book, then in DevTools (*Network → Offline*) reload. The app opens, and so does that book; Today's candle-lighting (on Erev Shabbat) and the times under *Settings → Reading & customs* still show, from the time-zone database's own part, which the service worker keeps. A discussion's address, reloaded offline, opens the app too (the service worker serves `index.html` for every page that isn't a file). So do the policies, though never opened online: *About → Privacy policy*, and `/legal/terms` reloaded, show their text, not "Something went wrong" (the service worker precaches `assets/assets/legal/legal.json`).
- [ ] Offline after an update: with that version installed, deploy one built with a newer Flutter or changed texts. Open the app online, and close it once *Application → Service workers* shows the new worker waiting; then open it offline. The new version opens, and so does the book. (While it installs, an update downloads again the engine and every book read so far, into caches named after its engine and texts, and it finishes installing only with them: tool/web/sw_update.js.) Check it once with the app reloaded just before the deploy and opened online again within ten minutes of that, while GitHub Pages lets the browser keep its files: *Application → Cache storage* then holds the new version's `canvaskit-…` and `content-…` caches, filled, and the new worker imports the new build's `sw_update.<hash>.js`, not the old build's.
- [ ] A new version while the app is open: with the installed app open, deploy a new version, then bring the window back to the front once an hour has passed since it opened: restore it from the taskbar, or click it from behind another window. Today offers Restart, and so does About, and Restart reloads into the new version with the progress and settings kept. A window opened after the deploy offers it as soon as the new version has installed. A second window of the app restarts with the first, into the new version, keeping what was changed in it just before. A window hard-reloaded (Ctrl+Shift+R) before the deploy, which the service worker doesn't control (*Application → Service workers* lists no client for it), offers Restart too, and restarts with the others; alone, with no window of the old version open to hold the new one back, it restarts by itself once the new version has installed.
- [ ] With the app's theme set to Dark, the installed app's title bar (and the browser's toolbar on Android) turns dark once the app has drawn its first frame. The loading screen before it already shows the app's theme and language.
- [ ] The loading screen fades into the app over about a quarter of a second, and the welcome or Today can be tapped as it does; with Reduce Motion on (in the app, or in the system), it gives way at once.
- [ ] **It opens, whatever happens.** In a browser that blocks the site's storage (Chrome: *Settings → Privacy and security → Site settings → Additional content settings → On-device site data*, the site under *Not allowed to save data on your device*), the app opens on Welcome, works through the session, and About offers *Copy details for support*; nothing is kept once the tab is closed. On a first visit with the parshiyot's data blocked (DevTools: *Network*, right-click `parshiyot.json`, *Block request URL*, then reload), the loading screen gives way to "Shnayim Mikrah couldn’t open." in the browser's language (in Hebrew too), with Try again, which reloads the page, and *Copy details for support*, never to "Still loading…" for good.
- [ ] Sharing the address in a messaging app shows the preview card (`web/og.png`).
- [ ] Once the store ids exist, point the web app at the apps:
  - in `web/index.html`, `<meta name="apple-itunes-app" content="app-id=<App Store id>">`, for Safari's banner on iOS
  - in `web/manifest.json`, `"related_applications": [{"platform": "play", "url": "https://play.google.com/store/apps/details?id=org.shnayimmikrah.app", "id": "org.shnayimmikrah.app"}]`, keeping `"prefer_related_applications": false` so that browsers still offer to install the web app
- [ ] If you use a Content-Security-Policy, allow:
  - `'wasm-unsafe-eval'` for CanvasKit
  - your Supabase URL in `connect-src`
  - `fonts.gstatic.com` in `connect-src` if you want emoji fallback fonts (see [DESIGN.md §9](DESIGN.md#9-typography))
- [ ] Check with NVDA + Chrome and VoiceOver + Safari.
