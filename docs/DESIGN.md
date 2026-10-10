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
- section by section, between the MAM parasha breaks (Shelah, Gra)
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
- **The last verse of the parsha** can optionally be repeated so the reading ends with Mikra.
- **Ketiv/qere:** the qere is read and the ketiv is shown on request.

**Progress is stored per unit:** (aliyah × pass), plus the haftarah. The guided reader saves the reader's position within each pass. This makes resuming exact, and lets the streak engine see partial days.

**Three default plans:**
- an aliyah a day, with Friday doubled (Gra)
- Shevi'i on Shabbat morning, logged afterwards
- everything on Erev Shabbat (Arizal, Shulchan Aruch HaRav)

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

### Changing the plan
Changing the plan, the quiet days, the late window or whether the haftarah counts never rewrites the past. The app remembers the day each change was made, and every day is planned by the settings in force on it: a change midweek keeps what was planned for the days before and spreads the rest of the portion over the days left. A change made after reading that day applies from the next day, so the day keeps the plan it was read by. Each week is judged by the late window and haftarah rule in force when it was read in synagogue. So a change can't spend a grace day or break a streak after the fact, and the settings screen says that it applies from this week on.

The engine is a pure function of (progress, join date, today, pauses, and the plan settings over time). It is unit-tested against the worked examples in the research and recomputed on every change.

**Syncing keeps every change, removals included.** Each reading, the haftarah, each saved place and each pause records when it last changed, and a removal keeps that time instead of disappearing. Merging two devices gives the same result in any order: where one device marked a reading as not read, cleared a week or ended a pause after the other last saw it, that change wins, and a reading marked again afterwards keeps its new day. Where both devices logged the same reading independently, the earliest date wins, so a sync never lowers a streak. With backup on and an account signed in, resetting all progress erases it everywhere, but keeps anything logged on another device after the reset. Signed out, a reset stays on the device, so it can't erase the backup of whoever signs in next.

## 5. Notifications

The planner is a pure function. Its rules come from the research:
- never on Shabbat or Yom Tov
- nothing after midday on the eve of Shabbat or Yom Tov
- at most one notification a day, chosen by priority: Erev Shabbat, then check-in, then daily

The copy is informational ("Revi'i is today's reading"), never guilt-based.

Permission is requested in context, after the reader finishes their first aliyah, not at launch.

## 6. Onboarding

The goal is to reach the first verse in under a minute. Onboarding has four screens:
1. Welcome, with a language toggle.
2. Location: Israel or Diaspora, with the time zone guessed.
3. Reading method and second reading.
4. Plan, with the honor statement.

It ends by opening the reader on today's aliyah. Everything else is a setting with a sensible default.

**The first week starts on the day the reader does.** Most people join midweek. Rather than finding half the portion already due, they have the whole portion spread over the reading days left before it is read in synagogue: joining on Wednesday gives Rishon and Sheni that day, Shlishi and Revi'i on Thursday, and the rest on Friday. The first reading opens on Rishon, and the first week can still be finished on time. From the next week on, the usual plan applies.

## 7. Community

**Weekly threads per parsha (the 929 model).** Each week's thread is created on demand by a security-definer function, and its title is built on the server from reference data. Clients can't create duplicate threads or spoof their titles. A week's thread belongs to the year its cycle began, and a double portion shares its first parsha's thread. The app names each weekly thread in the reader's language and spelling ("פרשת בראשית תשפ״ז"); the server's title stays the one searched and moderated. There are general forums for questions, the haftarah, accessibility, and announcements (moderator-only).

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

- **Verse labels for screen readers.** Each verse is exposed as one node with a curated label: "Verse 9." followed by the Hebrew with cantillation removed and tagged `he`. Screen readers read raw cantillation marks badly or skip the words. Users can switch to letters only, or to every mark for braille displays. The Divine Name is spoken as "Adonai" or "Hashem", as the user chooses.
- **Reading size multiplies the system text size**, up to 5× for scripture only. The interface follows the system setting alone, so layouts stay usable.
- **Five display themes:** light, dark, sepia, and high-contrast light and dark. They can follow the system or be set manually. Colour is never the only signal: statuses also have icons and text.
- **Line height of at least 1.6, split evenly above and below.** Lower vowels and cantillation marks must never be clipped. Typography details: a non-breaking space before a paseq, and a word joiner after a maqaf.
- **Desktop keyboard shortcuts** for every reader action, with a visible focus ring everywhere.

## 9. Typography

- **Noto Serif Hebrew (OFL)** is the default because it renders nikud and cantillation reliably on every platform.
- **Taamey Frank** gives a classic chumash look. Only its Medium weight is bundled, because its Bold file draws empty cantillation glyphs.
- **Ezra SIL** covers SBL-style typesetting.
- **Interface fonts:** Atkinson Hyperlegible Next, Lexend and OpenDyslexic are options for low vision and dyslexia. The research on dyslexia fonts is mixed, so they are choices rather than defaults.
- **The web build serves the CanvasKit engine and all fonts itself.** In testing it made no third-party requests. The engine fetches a fallback font from Google Fonts only to draw a character the bundled fonts lack, such as an emoji in a forum post.

## 10. Architecture

- **Pure-Dart core.** Calendar, plans, streaks and the reminder planner have no Flutter imports and are tested exhaustively.
- **Riverpod providers** connect settings, today's date, the schedule, progress and the streak summary. Everything else is derived from those.
- **Local-first storage.** Settings and progress are versioned JSON in shared preferences, with tolerant parsing. A week or pause that can't be read is kept untouched rather than dropped, and copied aside before a readable copy or a merge replaces it. Stored progress that can only be read by fixing part of it, or that a newer version wrote, is copied aside before anything can overwrite it. Export and import are available in settings. An export keeps what this version can't read apart from the rest, so the file can always be imported, and an import restores that part too. An import is all or nothing, and counts as a new change, so the next sync keeps it. Cloud backup is optional and merges rather than overwrites (see [Streaks](#4-streaks)), and it pauses (asking for an update) if a newer version of the app wrote the backup.
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
