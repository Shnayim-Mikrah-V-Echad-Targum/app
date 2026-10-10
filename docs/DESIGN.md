# Design decisions

This document summarizes the decisions behind the app and the reasons for them. The research behind each decision, with sources, is in [research/](research/):

- [halacha.md](research/halacha.md): the practice itself
- [streaks_ux.md](research/streaks_ux.md): habits, streaks, notifications and onboarding
- [accessibility.md](research/accessibility.md): standards and Flutter implementation
- [forums.md](research/forums.md): community design, store rules and Supabase
- [typography.md](research/typography.md): Hebrew fonts and rendering

## 1. Principles

1. **Serve the practice; don't gamify it.** The goal is that people finish the parsha each week, *lishmah*. Streaks are there to help with consistency. They are never a currency to protect. The app has no points, XP, leaderboards or loss-framed copy ("You'll lose your streak!").
2. **Shabbat and Yom Tov are first-class.** On those days nobody reads from a device, so they can never cost a streak or trigger a notification. Reading from a printed chumash on Shabbat is normal and can be logged afterwards.
3. **Honesty over surveillance.** Reading is self-reported, including reading done without the app. The app takes the reader at their word, and the onboarding states the honor system once.
4. **Accessible by construction.** Every screen is designed for screen readers, large text, keyboards and high contrast from the start, and CI enforces this.
5. **Calm by default.** One reminder a day at most, none on Shabbat, and gentle copy. Forgiveness is built in.

## 2. The calendar

**The portion is computed on the device and never fetched.** A pure-Dart Hebrew calendar uses fixed-day arithmetic. The parsha schedule comes from 28 tables, one for each combination of year type and Israel or Diaspora. Each table was generated from hebcal and validated for every year from 5700 to 5900. The app works fully offline and does not depend on a server staying online.

**A reading week runs from the day after the previous public reading through the next one.** That makes the week the halachic window for the obligation. When a holiday displaces Shabbat, the week is simply longer. A double portion is one week of seven aliyot spanning both portions, following the standard leyning divisions.

**The day rolls over at 3 a.m.** Reading done late at night counts for the evening it began. Using the app on Shabbat or Yom Tov (after Havdalah, for example) counts toward the next weekday.

**Israel and the Diaspora are a per-user setting**, asked during onboarding as "Where will you be this Shabbat?". The answer sets two things that Settings keeps apart:
- **the reading** heard in synagogue, which decides each week's portion;
- **the days of Yom Tov** kept, one or two, which decide the days without reading or reminders.

A visitor usually hears the local reading but keeps their home custom for Yom Tov, so a visitor to Israel still has no reading and no reminder on the second day of Yom Tov. When the two schedules diverge after Pesach or Shavuot, the user sees the portion of the reading they hear. If their two settings follow different places, Today names both portions. A visitor to Israel is told that visitors usually read both, with a link to the home portion, and that someone who davens with a Diaspora minyan reads only that one and should set the reading they hear to match. Someone who hears the Diaspora's reading but keeps one day of Yom Tov is told that Israel is a parsha ahead.

## 3. Reading

**Three methods**, with sources shown in the app:
- verse by verse (Arizal, Magen Avraham)
- section by section, between the parasha breaks of the Torah scroll (Shelah, Gra)
- aliyah by aliyah

Verse by verse is the default because it is the easiest to follow on a phone.

**The second reading can be:**
- Targum Onkelos (the default)
- Rashi (SA 285:2)
- both
- Rashi in English, with "ask your rav" copy

The JPS translation is offered only as a study aid and is labelled so. It never counts as the Targum.

**Edge cases from the research are handled explicitly:**
- **Bamidbar 32:3:** Onkelos is mostly names, so the reader suggests a third Mikra reading after the Targum, in every reading method.
- **Verses with no Rashi** get a third Mikra reading too when Rashi replaces the Targum. Both suggestions can be turned off.
- **The last verse of the parsha** can optionally be repeated so the reading ends with Mikra. It is on by default, except for Chabad, whose custom is not to repeat it; until the reader sets it, the switch follows the haftarah custom.
- **Ketiv/qere:** the qere is read and the ketiv is shown on request.
- **The scroll's text:** the Hebrew is Miqra according to the Masorah, which follows the Aleppo Codex. Where Ashkenazi and Sephardi Torah scrolls differ from it, the Torah follows the scrolls the reader hears in synagogue: nine words, two section breaks and the small yod of Pinchas. A note at each word and break gives the Codex's reading.

**The haftarah follows the reader's custom:** Ashkenazi, Sephardi or Chabad. Special haftarot differ by custom too: when Re'eh falls on Rosh Chodesh Elul, Sephardim and Chabad read Re'eh's own haftarah with the first and last verses of the Rosh Chodesh haftarah, and Ki Teitzei's alone two weeks later, and they read Kedoshim's own haftarah after a special Shabbat. When a special haftarah displaces the portion's own, the haftarah page offers the regular one too, folded, or open for Chabad, whose custom is to read both. Where a Chabad haftarah has not yet been sourced, the page shows the Ashkenazi one and says so.

**Progress is stored per unit:** (aliyah × pass), plus the haftarah. The guided reader saves the reader's position within each pass. This makes resuming exact, and lets the streak engine see partial days.

**Three default plans:**
- an aliyah a day, with two on the last day before Shabbat
- an aliyah a day and Shevi'i on Shabbat morning, logged afterwards (Gra, MB 285:8)
- everything on Erev Shabbat: after Shacharit (Arizal) or after midday (Shelah, Shulchan Aruch HaRav)

Tisha B'Av is always a quiet day. Chol HaMoed can optionally be quiet.

## 4. Streaks

The research weighed what works in Duolingo, Apple Fitness, YouVersion, Headspace, Finch and similar apps. It compared those against the evidence on how people handle a broken streak, and landed on **two streaks with built-in forgiveness**.

### Days on track (daily)
A planned day counts if any of these is true:
- it is **kept**: at least one aliyah's worth of reading was logged that day, from any open portion
- it is **ahead**: the reader was already at or ahead of plan
- it is **caught up**: the reader was back on plan by the end of the next planned day ("doubling up tomorrow repairs today")

Rest days and quiet days are skipped entirely. They neither count nor break the streak.

### Parsha streak (weekly)
A portion can end in one of these states:

| Status | Meaning | Streak |
|---|---|---|
| On time | Finished by its Shabbat | Continues |
| Late | Finished by Tuesday night. SA 285:4 allows "until Wednesday"; the window is configurable as Tuesday, Wednesday or none | Continues |
| Restored | Finished together with the next portion by the next Shabbat. Allowed once per book of the Torah | Continues |
| Made up | Finished any time before Simchat Torah | Counts for the year, but the streak restarts |
| Missed | Not finished | Breaks |

### Grace days
- The reader starts with 2 grace days and can hold at most 3. Finishing a portion on time earns one more.
- A grace day is spent automatically on a missed planned day.
- At most 2 grace days can be spent in one week, so a fully missed week still shows as missed. The point is to absorb a bad day, not to hide a pattern.

### Pause
"Life happens" is for illness, travel, mourning or a new baby. Days and weeks inside a pause are transparent. A pause can be ended early.

### Join date
Nothing before the day the reader started counts against them. In the week they join, only what was planned from that day on is expected (see [Onboarding](#6-onboarding)). If they joined after that week began and don't finish it, it is transparent; a week they joined on its first day counts like any other. Resetting all progress starts the reader again from the day of the reset, on every device the reset reaches.

The join date is backed up with the progress, and syncing keeps the earliest, so a new phone counts the history it restores instead of starting the streaks again from the day it was set up. A backup saved by a version that didn't keep the join date counts from its earliest reading. A join date from before the latest reset has no say, and nor does a reading logged for a day before it.

### Changing the plan
Changing the plan, the quiet days, the late window or whether the haftarah counts never rewrites the past. The app remembers the day each change was made, and every day is planned by the settings in force on it: a change midweek keeps what was planned for the days before and spreads the rest of the portion over the days left. A change made after reading that day applies from the next day, so the day keeps the plan it was read by. Each week is judged by the late window and haftarah rule in force when it was read in synagogue. So a change can't spend a grace day or break a streak after the fact, and the settings screen says that it applies from this week on.

The engine is a pure function of (progress, join date, today, pauses, and the plan settings over time). It is unit-tested against the worked examples in the research and recomputed on every change.

**Syncing keeps every change, removals included.** Each reading, the haftarah, each saved place and each pause records when it last changed, and a removal keeps that time instead of disappearing. Merging two devices gives the same result in any order: where one device marked a reading as not read, cleared a week or ended a pause after the other last saw it, that change wins, and a reading marked again afterwards keeps its new day. Where both devices logged the same reading independently, the earliest date wins, so a sync never lowers a streak. With backup on and an account signed in, resetting all progress erases it everywhere, but keeps anything logged on another device after the reset. Signed out, a reset stays on the device, so it can't erase the backup of whoever signs in next.

## 5. Notifications

The planner is a pure function. Its rules come from the research:
- never on Shabbat or Yom Tov
- nothing after midday on the eve of Shabbat or Yom Tov, or on Erev Tisha B'Av
- at most one notification a day, chosen by priority: Erev Shabbat, then check-in, then daily
- after two weeks without the app opened, one last message that reminders have paused, and then nothing until it is opened again; a "Life happens" pause longer than that is followed by two weeks of reminders before the message

The copy is informational ("Revi'i is today's reading"), never guilt-based.

Permission is requested in context, after the reader finishes their first aliyah, not at launch. Restoring a backup's settings with reminders on asks for it then, since the OS's permission doesn't come with the backup; refused, the reminders are turned off and the reader is told why.

## 6. Onboarding

The goal is to reach the first verse in under a minute. Onboarding has four screens:
1. Welcome, with a language toggle.
2. Location: Israel or Diaspora, guessed from the device's time zone, with "Why we ask" a tap away.
3. Reading method and second reading.
4. Plan, with the honor statement, and for a reader who joins midweek, how to read the first week.

Each step after the welcome is a page of its own, so Back, the system's or the app bar's, returns a step rather than leaving the app, and screen readers announce each step as a new screen. Every choice is saved as it is made, so going back loses nothing. Everything else is a setting with a sensible default.

**A reader who already uses the app restores from the welcome** ("I already use Shnayim Mikra"), on a new phone say. Signing in turns on backup and syncs: with progress in the account, onboarding is done and Today shows the streaks as they were; with none, onboarding carries on, with backup on. A backup file can be restored instead, settings and all. Signing in is offered only with a real community backend: the demo keeps nothing from one run to the next.

**Israel is guessed from the time zone's IANA name** (Asia/Jerusalem, or the older Asia/Tel_Aviv), which every platform gives, the web included. Abbreviations such as IST are not used: India and Ireland have one too. The guess is made on the welcome, and never overrides a choice the reader has made: once they choose, or go on past the question, it is not made again, even if the app is closed before onboarding ends. It is right for those who live in Israel; "Why we ask" tells a visitor that the days of Yom Tov they keep can be set apart in Settings.

**The first week starts on the day the reader does.** Most people join midweek. Rather than finding half the portion already due, they have the whole portion spread over the reading days left before it is read in synagogue: joining on Wednesday gives Rishon and Sheni that day, Shlishi and Revi'i on Thursday, and the rest on Friday, and joining on Friday gives all seven aliyot that day. The plan step says how long that is ("153 verses · about 64 min over 3 days"). Onboarding then opens the reader on Rishon, and the first week can still be finished on time. From the next week on, the usual plan applies.

A reader who would rather not can choose instead to start with today's reading: the usual plan applies from that day on, the aliyot planned before it are not expected, and onboarding opens the reader on today's aliyah. Joining on the week's first day of reading, or with a plan that reads everything on Friday, the two are the same, and the plan step doesn't ask.

## 7. Community

**Weekly threads per parsha (the 929 model).** Each week's thread is created on demand by a security-definer function, and its title is built on the server from reference data. Clients can't create duplicate threads or spoof their titles. A week's thread belongs to the year its cycle began, and a double portion shares its first parsha's thread. The app names each weekly thread in the reader's language and spelling ("פרשת בראשית תשפ״ז"); the server's title stays the one searched and moderated. There are general forums for questions, the haftarah, accessibility, and announcements (moderator-only).

**Weekly threads are not pinned.** The "This week" card on the Community screen opens the current one. Pinned, a year of past weeks would crowd every other discussion off the first page of the Parsha forum. Moderators can still pin any thread by hand.

**Long lists come a page at a time.** A forum lists its pinned threads, then 30 others at a time, newest activity first. A thread opens on its latest 100 posts, so the newest reply is never cut off, and earlier posts are a tap away. Each post comes with the post it answers, so a reply quotes it even when it is on a page not loaded. Pages follow on from the last row shown (keyset paging), at the exact time the server gave, with ties broken by id, so none repeats or skips a row. A thread's post count leaves out deleted posts. While earlier posts are not loaded, the thread shows that count and numbers its posts within it; once all are, it counts those shown, since the server's count includes posts the reader can't see, such as a blocked member's.

**Sign-in is a six-digit email code.** It needs no password and no deep links, which matters on Windows and in desktop browsers. The code arrives through Supabase's magic-link template, edited to show `{{ .Token }}`.

**Safety follows Apple guideline 1.2 and Google Play's user-generated-content (UGC) policy:**
- guidelines to accept before the first post
- reporting with a reason the reporter chooses, once per post
- blocking, and a list of blocked users
- auto-hide after 3 reports
- a moderation queue with logged actions
- a word filter that folds Hebrew vowels and final letters, so it can't be evaded with nikud
- rate limits, plus slower limits for new accounts
- in-app account deletion

**Everything is enforced in the database**, by row-level security, column grants and triggers. The client is not trusted. The author of a post is stamped by a trigger and can't be set by the client.

**Posting on Shabbat** can optionally be blocked on the server, using a per-region table of Shabbat times. It is off by default: users span time zones, and the forum's moderators should make that call.

**Without a backend**, a demo repository runs on the device. The app is fully usable without any server.

## 8. Accessibility

See [ACCESSIBILITY.md](ACCESSIBILITY.md). The key decisions:

- **Verse labels for screen readers.** Each verse is exposed as one node with a curated label: "Verse 9." (or "Targum, verse 9.") followed by the Hebrew with cantillation removed and tagged `he`. Screen readers read raw cantillation marks badly or skip the words. Users can switch to letters only, or to every mark for braille displays. The Divine Name is spoken as "Adonai" or "Hashem", as the user chooses, in the Torah, Onkelos' יְיָ and Rashi's ה'.
- **Language tagging that each platform can use.** TalkBack and VoiceOver switch voice partway through a label, so there only the Hebrew span is tagged and "Verse 9." stays in the interface language. The web engine reads only a node's own language (its `lang` attribute), so on the web the whole label is in Hebrew ("פסוק 9.") and the node is tagged. Rashi's comments are tagged the same way, and the English translation is tagged `en`. Flutter's Windows bridge passes no language at all, so Narrator and NVDA read with the voice they are set to; there the label is as on Android and iOS, so that "Verse 9." is read in the interface language.
- **The extraordinary points stay on the page.** The dots written over some words in the scroll are part of the text, not cantillation, so hiding cantillation keeps them. Speech leaves them out.
- **Reading size multiplies the system text size**, up to 5× for scripture only. The interface follows the system setting alone, so layouts stay usable.
- **Five display themes:** light, dark, sepia, and high-contrast light and dark. They can follow the system or be set manually. Colour is never the only signal: statuses also have icons and text.
- **Line height of at least 1.6, split evenly above and below.** Lower vowels and cantillation marks must never be clipped. Typography details: a non-breaking space before a paseq, and a word joiner after a maqaf.
- **Keyboard shortcuts** for every reader action, with a visible focus ring everywhere: Ctrl chords in the app, and on the web single keys that can be turned off, because the browser keeps the chords. The text scrolls by keyboard, and the focus is never lost when a page changes in place.

## 9. Typography

- **Noto Serif Hebrew (OFL)** is the default because it renders nikud and cantillation reliably on every platform.
- **Taamey Frank** gives a classic chumash look. Only its Medium weight is bundled, because its Bold file draws empty cantillation glyphs.
- **Ezra SIL** covers SBL-style typesetting.
- **The interface type is bundled, so the app looks the same on every platform.** Titles and headings are set in EB Garamond in the English UI and Frank Ruhl Libre in the Hebrew UI; everything else is Noto Sans or Noto Sans Hebrew. Native builds used to fall back to the platform font, so the brand changed from one OS to the next. The Hebrew UI has its own text theme, with letter spacing 0 and line heights tall enough for nikud. Details are in [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) §4.
- **Only bundled weights are requested.** A weight that isn't bundled silently renders as the nearest one, which is how button labels once came out Bold.
- **Interface fonts:** Atkinson Hyperlegible Next, Lexend and OpenDyslexic are options for low vision and dyslexia. They replace the serif headings too, in bold. The research on dyslexia fonts is mixed, so they are choices rather than defaults. "Device font" uses the platform's own font for the sans text's Latin letters instead, while Hebrew still falls back to the bundled Noto Sans Hebrew; the web can't reach device fonts, so there it keeps the bundled one.
- **The web build serves the CanvasKit engine and all fonts itself.** In testing it made no third-party requests. The engine fetches a fallback font from Google Fonts only to draw a character the bundled fonts lack, such as an emoji in a forum post.
- **Brand assets that contain Hebrew are generated by `tool/branding/make_icon.py`** with HarfBuzz shaping and a glyph-order assertion; a Hebrew reader checks them before every release. Hebrew placed letter by letter comes out reversed: the first icon read ת״ומש.

## 10. Architecture

- **Pure-Dart core.** Calendar, plans, streaks and the reminder planner have no Flutter imports and are tested exhaustively.
- **Riverpod providers** connect settings, today's date, the schedule, progress and the streak summary. Everything else is derived from those.
- **Local-first storage.** Settings and progress are versioned JSON in shared preferences, with tolerant parsing. A week or pause that can't be read is kept untouched rather than dropped, and copied aside before a readable copy or a merge replaces it. Stored progress that can only be read by fixing part of it, or that a newer version wrote, is copied aside before anything can overwrite it. Export and import are available in settings. An export is a file, `shnayim-mikra-backup-YYYY-MM-DD.json`: shared through the share sheet on phones, downloaded in a browser, and saved where the reader chooses on Windows (copied to the clipboard if none of that works). An import opens such a file, or takes its text pasted, which is how earlier versions shared backups, and says what it holds (when it was made, the weeks logged, the pauses) before anything changes. By default it merges with the progress on the device, as a sync does, except that neither side's reset erases the other's progress, and the earlier join date wins; the reader can choose to replace instead. Its settings come too if the reader asks, which on a new install, with no settings of its own to keep, is the default. An export keeps what this version can't read apart from the rest, so the file can always be imported, and an import restores that part too. An import is all or nothing, and counts as a new change, so the next sync keeps it. Cloud backup is optional and merges rather than overwrites (see [Streaks](#4-streaks)), and it pauses (asking for an update) if a newer version of the app wrote the backup.
- **Bundled texts.** About 9 MB of JSON, loaded per book on demand.
- **Localization.** English is the source language. The Hebrew ARB is generated from a dictionary, and the build fails if any key is missing.

## 11. Things for the rabbinic advisor

These defaults should be reviewed before a public release. Each is a setting:

- The late window: Tuesday or Wednesday.
- Whether restoring by doubling up should be allowed, and how often.
- Whether Rashi in English is acceptable, and the wording of the "ask your rav" copy.
- Whether Chol HaMoed should be quiet by default.
- How the Divine Name is spoken by text-to-speech and screen readers.
- Whether posting on Shabbat should be blocked on the server.
