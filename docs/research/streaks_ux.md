# Streaks, Habits and UX for a Shnayim Mikra App

*Research report, prepared 2026-10-09. Scope: streak and habit mechanics, humane engagement, notifications, onboarding, progress visualization, and exact streak rules for an app that helps users read the weekly parsha twice in Hebrew (Mikra) and once in Targum, usually one aliyah a day from Sunday to Friday. Users don't use devices on Shabbat or Yom Tov.*

---

## 0. Method, limits and evidence key

**How this was researched.** WebFetch could not reach any site from this environment: DNS failures and proxy `403 connect_rejected` on blog.duolingo.com, wikipedia.org and others. So every finding below comes from **WebSearch result summaries** of the cited pages, not from reading the pages in full. The shared web-search budget then ran out partway through. Two points could not be checked as a result: the Tisha B'Av rule for Shnayim Mikra, and community norms on device use during Chol HaMoed. Both are flagged where they come up. Halachic details are cross-checked against the companion file `research/halacha.md`. Have a rav review them before launch.

**Evidence key** (used throughout):
- **[P]**: primary or peer-reviewed source, or an official company or platform document.
- **[C]**: the company's own reported numbers. Usually A/B tests, sometimes correlations. Not independently verified.
- **[S]**: secondary write-up, vendor blog or journalism.
- **[K]**: background knowledge not confirmed by a source in this session.

---

## 1. Executive summary

1. **Make the parsha-week the main unit and the day a support for it.** The mitzvah is weekly. It is ideally finished before the Shabbat day meal, is still valid after the fact through Tuesday (some say Wednesday), and on the most lenient view can be made up until Simchat Torah ([OU](https://outorah.org/p/81536), [OU Timing](https://outorah.org/p/173503)). The **Parsha streak** should be the headline number. **Days on track** is a secondary, hideable number.
2. **Shabbat and Yom Tov are "transparent" days.** They never add to a streak and never break it. Precedent: Duolingo's Weekend Amulet test made learners **4% more likely to return a week later and 5% less likely to lose their streak** [C] ([Duolingo engineering](https://making.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals)). GitHub's streak counter shows the opposite risk: when GitHub removed it, weekend activity and long streaks both dropped, so the counter had been pushing people to work every day, rest days included [P] ([Moldon et al., ICSE 2021](https://arxiv.org/abs/2006.02371v1)).
3. **Keep the daily bar low and the weekly bar real.** Duolingo separated the daily goal from the streak and let one lesson keep a streak alive. That raised D14 retention 3.3% and the share of learners on a streak within 20 days by 10.5%, and Duolingo reports the change grew the number of learners on 7+ day streaks by over 40% [C] ([Duolingo blog](https://blog.duolingo.com/improving-the-streak)). Strava's weekly streak needs only one activity of 60 seconds or more per week [P] ([Strava](https://support.strava.com/hc/en-us/articles/36553427481997-Streaks-on-Strava)).
4. **Build slack in from the start.** Step goals framed with "emergency reserves" (2 skips a week) were reached up to **40% more often** than plain easy or hard goals. After a miss, 55% of reserve users bounced back, against 37% of hard-goal users [P] ([Sharif & Shu](https://anderson-review.ucla.edu/emergency-reserves/)). Use **grace days** that are earned and capped, and never sold.
5. **A broken streak causes drop-off, and repair softens it.** Logged broken streaks reduce later engagement. The effect is weaker when people can repair the streak or blame outside causes [P] ([Silverman & Barasch, JCR 2023](https://www.colorado.edu/business/faculty-research/2023/04/19/or-track-how-broken-streaks-affect-consumer-decisions)). The best of 54 interventions in a 61,293-person gym megastudy rewarded **returning after a missed workout** [P] ([Milkman et al., Nature 2021](https://authors.library.caltech.edu/records/mys88-cc756)). So design the comeback, not just the streak.
6. **Never monetize streak anxiety.** Paid streak repair (Duolingo, Snapchat at $0.99 per restore) is catalogued as a deceptive pattern ([deceptive.design](https://www.deceptive.design/articles/when-a-user-uses-duolingo-on-a-series-of-consecutive-days-this-is-called-a-streak-if-users-miss-a-day-they-can-pay-to-repair-it)). Guilt-laden reminders are the most common complaint about streak apps [S].
7. **Anchor reminders to routines, then fade them.** Reminders help people repeat a behavior but hinder automaticity, while event-based cues build it [P] ([Stawarz et al., CHI 2015](https://discovery.ucl.ac.uk/id/eprint/1468224/)). If-then plans have d ≈ 0.65 across 94 tests [P] ([Gollwitzer & Sheeran 2006](https://www.frontiersin.org/articles/10.3389/fpsyg.2021.565202/full)). Ask "After which routine will you read?" and offer to reduce reminders once a rhythm forms.
8. **Notifications: at most one a day, user-timed, suppressed during Shabbat and Yom Tov using local zmanim, with priming before the OS prompt.** At 2–5 pushes a week, 37% of users say they'd disable them [S] ([Localytics via MarketingProfs](https://www.marketingprofs.com/charts/2018/33486/how-many-mobile-push-notifications-are-too-many)). Android opt-in fell from 85% to 67% after Android 13 made permission explicit [S] ([Batch](https://batch.com/blog/case-studies/benchmark-notifications-push-crm-mobile)).
9. **Onboarding: reading before registration.** Delaying sign-up was associated with about a 20% DAU increase at Duolingo [C] ([First Round](https://review.firstround.com/the-tenets-of-a-b-testing-from-duolingos-master-growth-hacker)). Tutorials don't improve task success (91% with a tutorial, 94% without) [P] ([NN/g](https://www.nngroup.com/articles/mobile-tutorials/)). Ask only what's needed to show the right parsha.
10. **Use Jewish milestones: Chazak, siyum, fresh starts.** Celebrate each sefer with *Chazak, chazak, v'nitchazek* and the annual cycle with a Siyum on Simchat Torah. Treat every new parsha, Rosh Chodesh, Rosh Hashanah and Bereishit as a fresh start, since temporal landmarks prompt new attempts [P] ([Dai, Milkman & Riis 2014](https://faculty.wharton.upenn.edu/wp-content/uploads/2014/06/Dai_Fresh_Start_2014_Mgmt_Sci.pdf)). Keep rewards informational, not controlling, out of respect for *lishmah* and intrinsic motivation [P] ([Deci, Koestner & Ryan 1999](https://depts.washington.edu/techdocs/papers/deciExtrinsicRewardsAndIntrinsicMotivation99.pdf)).

---

## 2. How the practice constrains the design

Full detail is in `halacha.md`. This table covers what drives the streak rules.

| Constraint | What sources say | Design consequence |
|---|---|---|
| Weekly window | Ideally finish before the Shabbat day meal. Otherwise until Shabbat Mincha. After the fact, by Tuesday evening (OU) or Wednesday (SA 285:4). Most lenient: until Shemini Atzeret/Simchat Torah, though MB 285:12 says to prefer finishing before Shabbat ends ([OU 81536](https://outorah.org/p/81536); [OU 173583](https://www.outorah.org/p/173583); [dinonline](https://dinonline.org/2019/10/22/time-for-shnayim-mikra-ve-echad-targum/)) | Weekly states: **on time / late (by Tue) / made up (by Simchat Torah) / missed** |
| Earliest start | MB 285:7: from Shabbat Mincha of the previous week, when the next parsha is first read. Kol Bo and Shulchan Aruch HaRav: from Sunday ([OU Timing](https://outorah.org/p/173503); [SA HaRav](https://shulchanaruchharav.com/?p=1015)) | Next parsha opens for credit after Havdalah. A setting allows "Sunday only" |
| Daily division | Some read one aliyah a day; others read the whole parsha after midday on Erev Shabbat (SA HaRav) ([OU Timing](https://outorah.org/p/173503)) | Plan templates, including a Friday-only plan |
| Reading on Yom Tov | Permitted when Yom Tov falls midweek ([dinonline 2017](https://dinonline.org/2017/05/19/shnayim-mikra-when-yom-tov-is-in-middle-of-the-week/)) | Allow "I'll read on Yom Tov from a Chumash," logged afterward |
| Yom Tov readings | No Shnayim Mikra obligation for festival readings (SA 285:7) ([OU 174227](https://www.outorah.org/p/174227)) | **Holiday weeks with no parsha are transparent** |
| Yom Tov on Shabbat | Creates a "skip week" of two weeks between parshiyot. Poskim differ on when the delayed parsha may start ([OU 81739](https://outorah.org/p/81739)) | Default: the delayed parsha opens Sunday of the week it is read, which satisfies all views |
| Vezot HaBeracha | Best on Hoshana Rabbah (MB 285:18), also fulfilled on Shemini Atzeret. Avudraham records a custom of reading the whole Torah on the night of Hoshana Rabbah to make up a year's missed Shnayim Mikra ([OU 81739](https://outorah.org/p/81739); [dinonline](https://dinonline.org/2011/10/10/best-time-for-shanyim-mikra-of-vezos-haberachah/)) | Special end-of-year item. Hoshana Rabbah works as a **make-up night** for the annual Siyum |
| Bereishit | Starts only after Bereishit is read on Simchat Torah (`halacha.md` §2.3) | The Bereishit week is short and its plan is compressed |
| Targum substitutes | SA 285:2: Rashi counts as Targum, and a yarei shamayim reads both. Translations that follow Chazal and Rashi are accepted by some poskim (`halacha.md` §4.7) | Setting: Onkelos / Rashi / both / approved translation |
| Haftarah | Customary, not obligatory (Rema) ([Wikipedia](https://en.wikipedia.org/wiki/Shnayim_mikra_ve-echad_targum)) | Optional. **Never affects streaks** |
| Israel / Diaspora | Schedules diverge when the 8th day of Pesach or 2nd day of Shavuot falls on Shabbat, sometimes for months, and rejoin at a double parsha ([Sefaria sheet](https://sefaria.org/sheets/339455); [OU 49153](https://outorah.org/p/49153)). A Diaspora resident in Israel during a divergent week reads both. Someone going from Israel to the Diaspora need not repeat (`halacha.md` §4.11) | Two schedules. **Never break a streak because the user switched schedules** |
| Mourning | During shiva, Shnayim Mikra is allowed on Shabbat but weekday Torah study is not (YD 400:1; `halacha.md` §6) | A general "Life happens" pause that needs no explanation |
| Tisha B'Av | Torah study is restricted (OC 554) [K] | Quiet day: no reminders, no requirement |

Two market signals are also relevant:
- **Existing Shnayim Mikra apps** track progress per aliyah or per verse, pin users to a parsha when they fall behind, and offer daily reminders. They don't have humane streak systems ([Shnayim](https://apps.apple.com/app/id1296709500); [Shnayim Mikra Tracker](https://apps.apple.com/app/id6762082339)).
- **The OU's daily email series** sends one aliyah a day ([OU](https://ou.org/news/coming-inbox-near-ou-torah-launches-shanyim-mikra-daily-email-series)).

A Shabbat-aware streak system is therefore room to stand out.

---

## 3. Streak mechanics in successful apps

### 3.1 Duolingo
- **Scale and focus.** Duolingo calls streaks its most effective retention lever. It has run 600+ streak experiments, and more than 9 million users hold a streak of a year or more [C] ([Lenny's Newsletter](https://lennysnewsletter.com/p/behind-the-product-duolingo-streaks)). Learners who reach a 7-day streak are 2.4x more likely to come back the next day. That is a correlation, likely inflated by selection [C] ([Duolingo blog](https://blog.duolingo.com/improving-the-streak)).
- **Low bar, separated from the goal.** See finding 3 in the summary: D14 retention +3.3%, DAU +1%, share on a streak +10.5% (relative), and +19% among new users [C] ([Duolingo blog](https://blog.duolingo.com/improving-the-streak)). The original XP-based streak frustrated people whose goals were too ambitious. Moving to one lesson a day simplified it [S] ([recall.it summary](https://www.recall.it/summary/lennys-podcast/behind-the-product-duolingo-streaks-or-jackson-shuttleworth-group-pm-retention-team)).
- **Commitment framing.** Changing a button from "Continue" to "Commit to my goal" raised retention. Letting users pick their own streak goal created ownership and also raised retention [C] ([Lenny's](https://lennysnewsletter.com/p/behind-the-product-duolingo-streaks)).
- **Streak Freeze.** Bought ahead of time, with gems, and consumed automatically on a missed day. It doesn't work retroactively [S] ([Duolingo wiki](https://duolingo.fandom.com/wiki/Shop/Streak_freeze)).
- **Weekend Amulet.** Offered every Friday, it protected the streak over a skipped weekend. Learners offered it were 4% more likely to return a week later and 5% less likely to lose their streak [C] ([Duolingo engineering](https://making.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals)). The authors concluded that giving learners a break led them to do more over the long run. This is the closest analog to Shabbat.
- **Streak Wager.** Users spent in-app currency to bet on keeping a streak for 7 days and got double back if they did. D1, D7 and D14 retention all rose, D7 most (+14%), because the reward landed on day 7 [C] ([Duolingo engineering](https://making.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals)). Lesson: timing the reward drives behavior up to the reward. A current version, the Streak Challenge (7, 14 or 30 days with no freezes), exists ([Duolingo tips](https://blog.duolingo.com/tips-for-maintaining-streak)).
- **Perfect Streak week, widgets, a 30-day app icon.** These were cited as 2022 experiments that strengthened habit loops [S] ([Lazyweb](https://lazyweb.com/research/duolingo-retention-experiments)).
- **Repair and earn-back.** Paid Streak Repair has existed for years [S]. In June 2026 Duolingo ran a limited event letting users with lost streaks of 30+ days earn them back by doing 3 lessons in a row, after tens of thousands of user requests [S] ([Android Authority](https://androidauthority.com/duolingo-revive-broken-streak-event-3673004/)). **Lesson:** people want a way back, and an effort-based route beats a paid one.
- **Notifications.** A "sleeping, recovering" bandit picks among reminder templates and accounts for novelty decay. It produced +0.5% total DAU and +2% new-user retention [P/C] ([Yancey & Settles, KDD 2020](https://research.duolingo.com/papers/yancey.kdd20.pdf)). After roughly a month of inactivity, Duolingo sends a last message, "These reminders don't seem to be working. We'll stop sending them for now" [S] ([Medium](https://debugger.medium.com/duolingo-needs-to-chill-8f1832745ca0); [Taplytics](https://taplytics.com/blog/duolingo-sends-push-notifications-to-let-users-know-they-know-theyre-not-engaging-with-their-reminders)).
- **What backfired.** Users describe anxiety, keeping streaks alive through illness and bereavement, and "passive-aggressive" reminders. Parent guides recommend turning notifications off. One describes a child waking at night in a panic over a 247-day streak [S] ([Screenwise](https://screenwiseapp.com/guides/managing-duolingo-streaks-when-gamification-becomes-stressful)). Paid repair is listed on deceptive.design ([link](https://www.deceptive.design/articles/when-a-user-uses-duolingo-on-a-series-of-consecutive-days-this-is-called-a-streak-if-users-miss-a-day-they-can-pay-to-repair-it)).

### 3.2 Snapchat
- **Snapstreaks** count consecutive days of two-way Snaps. In 2023 Snap added in-app **Restore**: the first one free, then $0.99 each, with 5 a month on Snapchat+. Sources disagree on whether the restore window is 24 or 48 hours [S] ([Dexerto](https://www.dexerto.com/entertainment/how-to-get-streaks-back-1849331/); [Techpp](https://techpp.com/2023/10/05/snap-streak-lost-recover-guide/)).
- **What backfired.** Teens report pressure and anxiety. Snap had to turn off its friend-ranking "Solar System" feature by default after reports of distress [S] ([TechCrunch](https://techcrunch.com/2024/04/05/snapchat-turns-off-controversial-solar-system-feature-by-default-after-bad-press)). One study links streaks to problematic smartphone use with a small effect [S→P] (van Essen et al. 2023, doi:10.1016/j.teler.2023.100087, via [UBC](https://blogs.ubc.ca/etec523/2024/06/02/snapchat-streaks/)).
- **Lesson:** social streaks that require *both* people every day create obligation to others. Avoid daily pair streaks. If the app adds partners, track the week, not the day.

### 3.3 Headspace and Calm
- **Headspace** shows a "run streak" but lets users **hide streaks**, so they don't see repeated loss if they aren't daily users [S] ([Built for Mars](https://builtformars.com/ux-bites/hiding-your-headspace-streaks)). Its own editorial describes a member who broke his streak on purpose so he wouldn't fixate on the number ([Headspace](https://www.headspace.com/articles/speed-bumps-two-headspacers-learn-to-take-things-in-stride)).
- **Calm** lets users **manually add a missed session** to repair a streak [P] ([Calm Help](https://support.calm.com/hc/en-us/articles/115002473827-How-to-View-Your-Meditation-Stats-History-and-Streak-in-Calm)). That is honor-based logging.
- **Declutter the Mind** keeps a "longest streak" that survives resets and sends no push when a streak breaks [S] ([link](https://declutterthemind.com/features/streaks-and-stats)).

### 3.4 GitHub contribution graph
- GitHub **removed streak counters** in May 2016, saying it wanted to focus on the work rather than how long people stayed active [P] ([GitHub blog](https://github.blog/news-insights/product-news/more-contributions-on-your-profile)).
- A natural-experiment study found that after the removal, long streaks became rarer, **weekend activity dropped**, and days with a single token contribution fell [P] ([Moldon, Strohmaier & Wachs](https://arxiv.org/abs/2006.02371v1)). Lesson: streaks push people to act on rest days and to do token actions just to keep the count. For this app, Shabbat must be structurally exempt, and the "showed up" bar should be a real aliyah, not a single tap.
- The **heatmap** itself remains a widely copied, low-pressure way to show consistency.

### 3.5 Apple Fitness rings
- The rings were designed as "a ring is either closed or not closed." Numbers can always get bigger, but a ring has an endpoint [S] ([MobiHealthNews, Jay Blahnik](https://www.mobihealthnews.com/news/jay-blahnik-what-separates-apple-watch-other-fitness-trackers)). Goals adapt to avoid burnout.
- **watchOS 11** added **Pause Rings** (today, a week, a month, or a custom length up to a month, with the streak kept) and **goals per day of the week** [S] ([Macworld](https://www.macworld.com/article/2446605/how-to-pause-apple-watch-activity-rings.html); [BGR](https://www.bgr.com/tech/watchos-11-activity-rings-have-big-changes-heres-whats-new/)). Paused days don't add to the count but keep the streak. Apple took years to add this, which shows a no-pause design wasn't sustainable.

### 3.6 Strava
- **Weekly streak:** at least one activity of 60 seconds or more between Monday and Sunday. Uploading a missed activity after the week ends **restores the streak**. Milestone banners appear at weeks 2–5, 10, 15, 25, and at years 1–3. Users currently can't disable these banners, which is a minus [P] ([Strava](https://support.strava.com/hc/en-us/articles/36553427481997-Streaks-on-Strava)). This is the strongest precedent for a forgiving, honor-based weekly streak.

### 3.7 Finch
- Missed days don't punish the pet. An official **App Pause** keeps the streak "no guilt, no pressure." Some users say no-consequence design weakened their habit [S] ([Habitbox review](https://habitbox.app/blog/finch-app-review)). Lesson: forgiveness still needs some structure. Use grace days with a cap rather than unlimited forgiveness.

### 3.8 YouVersion (Bible App)
- **Streaks** count consecutive days with any Scripture activity. **Perfect Weeks** count Sunday-to-Sunday weeks of consistent use. Milestone celebrations are built in [S] ([Outreach Magazine](https://outreachmagazine.com/?p=39061)). This weekly metric is a good model.
- **Reading plans** have **"Catch Me Up,"** which resets "today's reading" to the day after the last completed day [S] ([The Sweet Setup](https://thesweetsetup.com/use-catch-feature-youversions-reading-plans/)).
- **Rigid schedules lose people.** Year-plan usage drops by a third by the end of February and by half by May (Bible Gateway). All 10 of the most-completed plans take a week or less [S] ([Christianity Today](https://christianitytoday.com/news/2015/december/most-popular-bible-verses-200-million-youversion-app-2015.html)). That favors a **weekly** cycle like Shnayim Mikra and argues for catch-up tools.

### 3.9 Jewish learning programs and apps
- **929** reads one chapter of Tanakh a day, Sunday to Thursday. **Friday and Shabbat are reserved for catching up or going deeper** [P] ([929.org.il](https://www.929.org.il/pages/aboutEN.html); [Hebcal nine29](https://pkg.go.dev/github.com/hebcal/learning/nine29)). This is the clearest Jewish precedent for buffer days built into the schedule.
- **Sefaria** publishes learning schedules (Daf Yomi, Daf a Week, Tanya Yomi and others) but has no streak mechanics [S] ([Sefaria calendars](https://sefaria.org.il/calendars)). **Hebcal** offers open-source schedule libraries [P] ([hebcal-learning](https://github.com/hebcal/hebcal-learning)).
- **Chabad.org Daily Torah Study** and **The Rambam App** are content-first, with three Rambam tracks and audio. Their listings mention no streak or progress tracking [S] ([App Store](https://apps.apple.com/us/app/chabad-org-daily-torah-study/id1408133263); [Rambam App](https://apps.apple.com/app/id1571859668)). Chabad's daily Chumash study maps one aliyah per day, with Shabbat = Shevi'i (`halacha.md`).
- **OU All Daf** offers a personal learning tracker plus **community siyum events** for finishing a masechta, both live and through the app [S] ([OU](https://ou.org/news/orthodox-unions-torah-initiatives-and-upper-west-side-community-celebrate-siyum-on-maseches-sotah); [All Daf](https://alldaf.org/about-us)). Siyum culture is already the community's milestone language.
- **Mishnah Yomit** (two mishnayot a day, about a 6-year cycle) is supported by calendar feeds and custom calendar builders [S] ([Wikipedia](https://en.wikipedia.org/wiki/Mishnah_Yomis)).

### 3.10 What worked and what backfired

| Worked | Evidence | Backfired | Evidence |
|---|---|---|---|
| Low daily bar, separate from the goal | Duolingo +3.3% D14 [C] | XP-based or high streak bar | Duolingo [S] |
| Built-in breaks (Weekend Amulet, Pause Rings) | +4% return [C]; Apple, Finch [S] | Daily streaks over rest days | GitHub weekend effect [P] |
| Earned or protective freezes | Duolingo [C]; emergency reserves +40% [P] | Selling repair or freezes | deceptive.design; Snapchat [S] |
| Retroactive honest logging | Strava, Calm [P] | Pair streaks that need both people daily | Snapchat teen pressure [S] |
| Rewards timed to a near goal (7 days) | Streak Wager +14% D7 [C] | Guilt or "sad mascot" reminders | Parent guides [S] |
| Weekly metrics (Perfect Weeks, weekly streak) | YouVersion, Strava [S/P] | All-or-nothing loss with no longest streak | Decision Lab [S] |
| Catch-up tools | YouVersion "Catch Me Up" [S] | Rigid year plans | Bible Gateway drop-off [S] |
| Hiding streaks | Headspace [S] | Leaderboards and rankings of friends | Snap Solar System [S] |
| Stopping reminders when ignored | Duolingo [S] | Many generic pushes | Localytics [S] |

---

## 4. Ethical and humane engagement

### 4.1 Principles
- **Center for Humane Technology:** respect human nature rather than exploit it, avoid tactics that exploit attention and emotions, and support well-being [S] ([CHT](https://centerforhumanetechnology.substack.com/p/what-do-we-mean-by-human-tech); [Humane product design](https://www.humanetech.com/humane-product-design)).
- **Deceptive patterns to avoid** (Brignull; Gray et al. taxonomy):
  - **Confirmshaming**, where declining is worded to imply you're irresponsible, e.g. "No thanks, I don't care about Torah" ([deceptive.design](https://deceptive.design/articles/creative-manipulation-a-case-study-of-confirmshaming-as-a-deceptive-design-pattern)).
  - **Nagging**, meaning repeated interruptions ([UW slides on Gray et al.](https://courses.cs.washington.edu/courses/cse340/22sp/slides/wk09/Dark-Patterns-Deceptive-Design.pdf)).
  - **Obstruction** and **sneaking**.
  - The FTC's 2022 staff report includes **fake urgency and countdown timers** ([Venable summary](https://www.venable.com/insights/blogs/2022/09/the-ftc-brings-more-light-to-dark-patterns-in-new)). Streak-loss countdowns are a form of fake urgency.
- **"Streak creep":** growing a streak feels powerful but becomes empty once interest in the activity itself fades [S] ([The Decision Lab](https://thedecisionlab.com/insights/consumer-insights/streak-creep-the-perils-of-too-much-gamification)). The **abstinence-violation / "what the hell" effect** describes how one lapse can turn into quitting. One developer replaced consecutive-day counts with a rolling "10 of the last 14 days" [S] ([Indie Hackers](https://www.indiehackers.com/post/im-removing-the-streak-counter-from-my-habit-app-here-s-why-7d2a6179dd)).

### 4.2 The science of handling a break
- **Broken streaks reduce re-engagement.** The effect is weaker when people can repair the streak or blame outside causes. Barasch notes that "you failed, get back on track" messages don't work and suggests **offering a new goal** instead [P] ([CU Boulder](https://www.colorado.edu/business/faculty-research/2023/04/19/or-track-how-broken-streaks-affect-consumer-decisions); [UDel](https://udspace.udel.edu/handle/19716/34160)).
- **Self-compassion after failure raises effort.** Self-compassion-primed participants studied longer after failing a test than self-esteem controls [P] ([Breines & Chen 2012](https://pubmed.ncbi.nlm.nih.gov/22645164/)).
- **Fresh starts.** People start goals after temporal landmarks: new week, month, year, holidays [P] ([Dai et al. 2014](https://faculty.wharton.upenn.edu/wp-content/uploads/2014/06/Dai_Fresh_Start_2014_Mgmt_Sci.pdf)). The Jewish calendar supplies these weekly: each new parsha.
- **Reward the return.** Micro-rewards for coming back after a miss were the top gym intervention [P] ([Milkman et al.](https://authors.library.caltech.edu/records/mys88-cc756); [Scimex](https://www.scimex.org/newsfeed/which-programs-give-gym-goers-the-biggest-boost)).
- **Keep cumulative records** (longest streak, totals) so a loss is never total ([Declutter the Mind](https://declutterthemind.com/features/streaks-and-stats)).

### 4.3 Motivation and *lishmah*
- **Expected, tangible, contingent rewards undermine intrinsic motivation:** d = −0.40 for engagement-contingent and −0.36 for completion-contingent rewards. **Informational positive feedback enhances it**, as long as it isn't controlling [P] ([Deci, Koestner & Ryan 1999](https://depts.washington.edu/techdocs/papers/deciExtrinsicRewardsAndIntrinsicMotivation99.pdf)).
- **Religious gamification:** a 2025 paper raises concerns about superficiality, commodification and dependence on external motivators in faith apps [S] ([KazNU bulletin](https://bulletin-religious.kaznu.kz/index.php/relig/en/article/view/772)).
- **The Talmudic frame.** Learning *shelo lishmah* (for ulterior motives) is acceptable because it leads to *lishmah* (for its own sake), but only if *lishmah* stays the aim ([Sefaria sheet](https://www.sefaria.org/sheets/315194); [KBY](https://kby.org/english/torat-yavneh/view.asp?id=8847)).
- **Design reading:** treat streaks as scaffolding. Use no points, XP, currency or leaderboards. Milestones should *describe* what was learned ("1,533 pesukim, twice, with Targum") rather than dangle prizes.

### 4.4 Honor-based logging
- Precedents: Calm's manual add, Strava's late upload, YouVersion's Catch Me Up.
- Offline reading from a printed Chumash, often on Shabbat itself, is central to this practice. It must get **equal credit, with no "unverified" label** and no anti-cheat friction. Overstating your own reading only cheats yourself. Adversarial checks would insult the 99% and push them away.

---

## 5. Habit-formation science

- **Lally et al. 2009** [P] ([UCL](https://www.ucl.ac.uk/news/2009/aug/how-long-does-it-take-form-habit); [BPS digest](https://bps.org.uk/research-digest/how-form-habit))
  - Automaticity took a **mean of 66 days** (range **18–254**) in 96 people.
  - **Missing one opportunity didn't materially affect habit formation.** This is the scientific case for grace days.
  - Caveat: automaticity was self-reported.
- **BJ Fogg, Tiny Habits** [S] ([Stanford PDF](https://med.stanford.edu/content/dam/sm/ascend/documents/Introduction_%20Tiny%20Habits%20for%20Self%20Compassion,%20Getting%20Started.pdf))
  - B = MAP (Motivation, Ability, Prompt).
  - Recipe: "After I [anchor], I will [tiny behavior], then I celebrate."
  - The celebration wires the habit.
  - App use: an anchor picker, a tiny fallback ("read at least one aliyah"), and an immediate celebration after each aliyah.
- **Implementation intentions (Gollwitzer & Sheeran 2006)** [P] ([Frontiers citing the meta-analysis](https://www.frontiersin.org/articles/10.3389/fpsyg.2021.565202/full); [record](https://stafforini.com/works/gollwitzer-2006-implementation-intentions-and/))
  - d = 0.65 across 94 tests.
  - App use: have users complete "After I ___, I'll read today's aliyah."
- **Stawarz, Cox & Blandford (CHI 2015)** [P] ([UCL Discovery](https://discovery.ucl.ac.uk/id/eprint/1468224/))
  - Reminders supported repetition but **hindered** habit development.
  - **Event-based cues increased automaticity.**
  - Positive reinforcement alone was ineffective.
  - Of 115 apps reviewed, almost none supported event-based cues.
  - App use: reminder copy names the anchor, and reminders fade as consistency builds.
- **Wendy Wood:** about 43% of daily actions are habitual, cued by context. Reduce friction and give rewards *during* the behavior [S] ([Behavioral Scientist](https://www.behavioralscientist.org/good-habits-bad-habits-a-conversation-with-wendy-wood/)).
  - App use: open straight to today's aliyah, remember the place to the verse, and give an in-reader sense of completion.
- **Flexibility beats rigid routine.** Paying gym-goers for any-time visits produced more visits, during and after the intervention, than paying for visits in a fixed 2-hour window [P] ([Beshears et al. 2021](https://pubsonline.informs.org/doi/fpi/10.1287/mnsc.2020.3706)).
  - App use: reward the day's reading at any hour, not at the reminder time.
- **Goal-gradient and endowed progress.** People speed up as a reward nears [P] ([Kivetz et al. 2006](https://business.columbia.edu/sites/default/files-efs/pubfiles/1200/goalgradient.pdf)). Pre-stamped loyalty cards were redeemed 34% of the time vs 19% for blank ones [S] ([Nunes & Drèze via Coglode](https://coglode.com/nuggets/endowed-progress-effect)).
  - App use: show "2 aliyot to Shabbat," and start new users' rings at their join point, not at an empty Sunday.

---

## 6. Notification best practices

- **Volume.** Localytics surveyed 1,000 US users [S] ([MarketingProfs](https://www.marketingprofs.com/charts/2018/33486/how-many-mobile-push-notifications-are-too-many)).
  - At 1 push a week, 10% would disable notifications.
  - At 2–5 a week, 37% would disable them and 22% would stop using the app.
  - At 6–10 a week, 31% would stop using the app.
  - In Braze research, irrelevance mattered more than volume, and 25% cited "too many" [S] ([Braze](https://www.braze.com/resources/articles/opt-out-of-push-notifications-why-users-do-it)).
- **Opt-in rates** [S] ([Batch](https://batch.com/blog/case-studies/benchmark-notifications-push-crm-mobile); [Pushwoosh](https://www.pushwoosh.com/blog/push-notification-benchmarks/); [Airship 2025](https://growth.airship.com/rs/313-QPJ-195/images/Airship-2025-Push-Notification-Benchmarks-EN.pdf?version=0))
  - iOS is around 56%.
  - Android fell from 85% to 67% within a year of Android 13.
  - The bottom decile of a vertical is under about 30%.
- **Android 13+ (`POST_NOTIFICATIONS`).** Target API 33+ to control timing. Wait until users know the app, and request in response to a user action. Show a rationale when `shouldShowRequestPermissionRationale()` is true [P] ([Android Developers](https://developer.android.com/develop/ui/views/notifications/notification-permission)).
- **iOS.** Give context before requesting. iOS gives you effectively one prompt. **Provisional authorization** (iOS 12+) delivers quietly to Notification Center with Keep / Turn Off buttons [P/S] ([Apple](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications); [Nil Coalescing](https://nilcoalescing.com/blog/TrialNotificationsWithProvisionalAuthorizationOnIOS)).
- **Priming.** Show a custom pre-prompt and fire the OS dialog only on "Yes," which keeps the one-shot iOS prompt for later. The practice is widely recommended, but published lift data is vendor-only [S] ([Braze push primer](https://www.braze.com/resources/articles/whats-a-push-primer)).
- **Novelty and relevance.** Rotating, fresh templates beat a single "best" template [P/C] ([Yancey & Settles](https://research.duolingo.com/papers/yancey.kdd20.pdf)).
- **Back off when ignored.** Duolingo's "we'll stop sending them for now" is the precedent [S].
- **Shabbat and Yom Tov.** A notification that lights up a phone during Shabbat is a real problem for this audience, even if nobody touches it.
  - Schedule local notifications with times computed from local zmanim. Hebcal's default candle-lighting is 18 minutes before sunset, with Jerusalem at 40 and Haifa at 30. Default havdalah is tzeit at 8.5° below the horizon [P] ([@hebcal/core README](https://cdn.jsdelivr.net/npm/@hebcal/core@6.5.3/README.md)).
  - Also block server pushes during those windows.
  - Hebcal provides the `CHAG`, `LIGHT_CANDLES`, `YOM_TOV_ENDS`, `IL_ONLY` and `CHUL_ONLY` flags for detecting rest days.

---

## 7. Onboarding best practices

- **Value before registration.** Duolingo runs the first lesson before asking for an account, and reports about +20% DAU from moving sign-up later [C] ([First Round](https://review.firstround.com/the-tenets-of-a-b-testing-from-duolingos-master-growth-hacker); [Appcues Good UX](https://goodux.appcues.com/blog/duolingo-user-onboarding)). "Gradual engagement" asks for registration only when it's needed, to save or personalize [S] ([Appcues](https://www.appcues.com/blog/gradual-engagement-mobile-app-first-screen); [Auth0](https://auth0.com/blog/should-you-give-users-access-before-they-register/)).
- **Skip the tour.** In a 70-user study of deck-of-cards tutorials, success was 91% for users who read the tutorial and 94% for users who skipped it. Prefer contextual help [P] ([NN/g](https://www.nngroup.com/articles/mobile-tutorials/)).
- **Progressive disclosure.** Ask only what changes the first screen of content.
  - **Required up front:** Israel vs Diaspora, which determines the parsha.
  - **Has sensible defaults:** reading method (verse by verse, Onkelos).
  - **Deferred until used:** haftarah nusach (Ashkenaz, Sefard, Chabad, Teimani), city for Shabbat times, the late-window setting, Chol HaMoed handling.
- **Commitment framing.** Wording like "Commit to my goal," plus a goal the user picks, raised retention at Duolingo [C].

---

## 8. Progress visualization and milestones

- **Rings with endpoints** (Apple) suit a weekly obligation of 3 passes × 7 aliyot. Each pass ring closes by Shabbat.
- **Heatmaps** (GitHub) show consistency at a glance, but avoid red "failure" cells. GitHub's own streak removal shows that the counter, not the heatmap, drove compulsive behavior [P].
- **Badges steer behavior,** but only about 20% of users respond strongly. Most stay indifferent [P] ([Anderson et al. 2013](https://archives.iw3c2.org/www2013/proceedings/p95.pdf); [Hoernle et al. 2020](https://ar5iv.labs.arxiv.org/html/2002.06160)). So keep milestones few, meaningful, and informational.
- **Culturally native milestones:**
  - *Chazak, chazak, v'nitchazek* when finishing each of the five books (said in shul).
  - A **Siyum** on completing the annual cycle at Simchat Torah.
  - Community siyum events, as in OU All Daf.
- **Sharing.** Make it opt-in and content-first ("I completed Sefer Shemot"). Streak numbers stay private by default, out of modesty and respect for *lishmah*.

---

## 9. Defining "daily" vs "weekly" streaks for this practice: options analysis

| Option | Description | Fits the mitzvah | Forgiving | Motivating | Risk of gaming or token actions | Simple |
|---|---|---|---|---|---|---|
| A. Strict daily | Must read the planned aliyah each day | Low (the obligation is weekly) | Low | High early, brittle | Medium | High |
| B. Low-bar daily | Day kept if you read ≥1 aliyah **or** you're on or ahead of plan | Medium-high | High | High | Low (an aliyah is real work) | Medium |
| C. Cumulative on-track only | Kept if cumulative reading ≥ cumulative plan | High | Medium | Medium | Low | Medium |
| D. Rolling consistency | "X of last N days/weeks" | High | High | Medium | Low | High |
| E. Weekly only | Parsha completed on time | Highest | Medium | Lower day-to-day pull | Low | High |

**Recommendation:**
- **E as the headline** ("Parsha streak").
- **B + C with a next-day catch-up as the secondary** ("Days on track").
- **D as a stats line** ("47 of 52 parshiyot this year").
- **Shabbat and Yom Tov transparent** in all of them.
- Daily tracking is hidden for users on the Friday-only plan.

---

## 10. Concrete recommendations for this app

### 10.1 Definitions

| Term | Exact definition |
|---|---|
| **Rest day** | Shabbat, plus every Yom Tov day under the user's *Yom Tov days* setting: 1 (Israel) or 2 (Diaspora). Includes both days of Rosh Hashanah everywhere, Yom Kippur, the first and last days of Pesach, Shavuot, the first days of Sukkot, and Shemini Atzeret/Simchat Torah. Computed with Hebcal (`CHAG` flag, `IL_ONLY`/`CHUL_ONLY`). |
| **Quiet day** | A non-rest day the user has set as a no-requirement, no-reminder day. Defaults: **Tisha B'Av = quiet** (pending rabbinic confirmation), **Chol HaMoed = normal**, user can switch. |
| **Transparent day** | Rest day, quiet day, paused day, or a day with nothing assigned. It neither adds to nor breaks any streak, and is never drawn as "missed." |
| **Plan day** | A non-transparent day in a parsha week with ≥1 aliyah assigned by the user's plan. |
| **Device-day window** of plan day D | **Opens** at 03:00 local on D, or at the end of the preceding rest period if D follows one (so Saturday night after Havdalah belongs to Sunday). **Closes** at 03:00 local on D+1, or at candle-lighting on D if D+1 is a rest day. The 03:00 cutoff is configurable from 00:00 to 05:00. |
| **Parsha week** | For a regular parsha P: from P's opening (default Motzaei Shabbat of the preceding week; setting "Sunday") to the Shabbat on which P is read. |
| **Unit** | One *aliyah-pass*: Mikra I, Mikra II, or Targum (or Rashi or a translation, per settings) of one aliyah. A regular week is 7 × 3 = **21 units**. A double week uses each parsha's own aliyot: 14 × 3 = **42 units**. Verse-by-verse readers complete an aliyah's 3 units together. |
| **Open parsha** | (a) the current week's parsha; (b) the previous parsha until its late deadline; (c) any earlier parsha of this cycle (backlog) until Simchat Torah. |
| **Read-date** | The date the reading actually happened. Defaults to the device-day window when logged; can be set by the user under the backfill rules (§10.7). |

### 10.2 Weekly plans and automatic rebalancing
- **T1, "An aliyah a day" (default):** Sun 1 · Mon 2 · Tue 3 · Wed 4 · Thu 5 · Fri 6+7 (+ optional haftarah).
- **T2, "Shevi'i on Shabbat morning":** Sun–Fri 1–6. Aliyah 7 (+ haftarah) is assigned to Shabbat, read offline, and logged after Havdalah.
- **T3, "Erev Shabbat" (Shulchan Aruch HaRav custom):** everything on Friday. Days on track is hidden; only the Parsha streak shows.
- **T4, "Custom":** drag aliyot onto days, including the Shabbat-morning slot.
- **Rebalancing** when plan days are lost to Yom Tov or quiet days:
  1. Move the lost day's aliyot to the nearest **earlier** plan day in the same week, preferring Erev Yom Tov. If there is none, move them to the nearest later one.
  2. Keep aliyah order.
  3. Balance by verse count so no day exceeds 2× the week's daily average when that's possible.
  4. Offer the toggle "I'll read on Yom Tov from a Chumash." Its aliyot are assigned to the Yom Tov and logged afterward. Reading on a midweek Yom Tov is permitted (dinonline).
- **Short weeks** (Bereishit after Simchat Torah, joining midweek): spread the remaining aliyot over the remaining plan days with the same balancing.
- **Time estimate per aliyah:** verse count × the user's measured seconds per verse, starting from a default. Display it as "~12 min."

### 10.3 Daily rule ("Days on track")

Each plan day D gets exactly one status.

1. **KEPT:** during D's window the user logged **≥ 3 units** (one aliyah's worth) from **any open parsha**, including catch-up of last week's parsha or backlog.
2. **AHEAD:** not KEPT, but at the close of D the current parsha's completed units are ≥ the plan's cumulative target through D. Reading ahead must never cost anything.
3. **CAUGHT_UP:** neither of the above, but by the close of the **next plan day N**, the parsha D belongs to has reached its cumulative target through N (or is complete, if N falls in the next week). In other words, "doubling up the next day repairs yesterday," like 929's built-in catch-up days.
4. **GRACE:** none of the above, and a grace day is available and allowed (§10.5). It is consumed automatically.
5. **PAUSED:** covered by a pause (§10.6).
6. **MISSED:** otherwise.

- **Counting:** KEPT, AHEAD and CAUGHT_UP add **+1**. GRACE, PAUSED and transparent days **hold** the count. MISSED **resets it to 0**.
- **Timing:** status is provisional at the close of D and **final at the close of N**. Until then the day shows as an outlined "open" chip and the streak number doesn't drop.
- **Also kept:** Longest streak, plus a rolling "Days on track: 41 of last 45 plan days."

### 10.4 Weekly rule ("Parsha streak")

For each parsha P (double weeks count as one week; holiday weeks have no P):

| Status | Condition | Streak effect |
|---|---|---|
| **ON_TIME** | All units done with read-dates ≤ Shabbat P. Shabbat reading is logged after Havdalah using the attestation "I finished on Shabbat." | +1. Earns 1 grace day. Eligible for "Perfect week." |
| **LATE** | All units done by the **late deadline**: close of the Tuesday device-day window after Shabbat P. Setting: Tuesday (default) / Wednesday / off. | +1, shown with a small "after Shabbat" dot. No grace day earned. |
| **RESTORED** | Missed the late deadline, but **both** P and the current parsha are completed by the next Shabbat, and a restore token is available. Tokens: **1 per sefer**, reset when Bereishit, Shemot, Vayikra, Bamidbar or Devarim begins. | +1, marked "doubled up." Token consumed. |
| **MADE_UP** | Completed after the windows above, but before the end of Simchat Torah. | Doesn't restore the streak. Counts fully toward the annual Siyum. |
| **MISSED** | Not completed by Simchat Torah. | The streak reset happens when the late deadline passes and no restore is possible: at the late deadline if no token is left, otherwise at the next Shabbat. |
| **TRANSPARENT** | Holiday week with no parsha due, or a paused week (a pause covering Friday's candle-lighting or ≥50% of the week's plan days). | Hold. If the user completes a paused week anyway, it is evaluated normally. **Completing never hurts.** |

- **Vezot HaBeracha** is a parsha item. Its plan is due on **Hoshana Rabbah**, with on-time credit through the end of Shemini Atzeret/Simchat Torah, logged after Yom Tov. Its late window is an open question for the rav (§10.18).
- **Annual Siyum:** all 54 parshiyot of the cycle completed (ON_TIME, LATE, RESTORED or MADE_UP) by the end of Simchat Torah. Users who join mid-cycle get "Siyum from {start parsha}." Suggest the night of Hoshana Rabbah for make-ups, following the custom Avudraham records.

### 10.5 Grace days (the streak freeze)
- **Name:** "Grace days." No ice or fire imagery. Icon: a small shield or olive leaf.
- **Starting balance:** 2.
- **Earning:** +1 per ON_TIME parsha. **Balance cap: 3.** No other sources: no ads, no purchase, no premium tier.
- **Consumption:** automatic when a plan day would finalize as MISSED. At most **2 per parsha week**. A third unkept day in the same week is MISSED.
- **Refund:** if a later backfill inside the backfill window turns that day into KEPT, AHEAD or CAUGHT_UP, the grace day is returned.
- **Scope:** grace days protect **Days on track only**. The Parsha streak is protected by the late window, restore tokens and pause.
- **Visibility:** the balance is shown in the streak sheet, never in notifications.

### 10.6 Pause ("Life happens")
- Starts at any time. Lasts 1–30 days. Can be **backdated up to 3 days**.
- Reasons are optional and private: illness, travel, mourning, new baby, other.
- Paused days and weeks are transparent for both streaks and earn nothing.
- No limit on how many times users pause. The stats screen shows "paused days this year" neutrally, with no judgment.
- All reminders stop during a pause. On return the app shows "Welcome back" and offers **Jump to this week's parsha** (default) or **Catch up**.

### 10.7 Offline and honesty logging (backfill)
- **Logging:** any unit can be marked "Read from a book / elsewhere" in one tap, by aliyah or by pass, with the same credit as in-app reading. There is no "unverified" state.
- **Backfill windows** for choosing a read-date:
  - **Plan days:** until the close of the next plan day.
  - **Rest days** (Shabbat, Yom Tov): until the close of the first plan day after the rest period, e.g. Sunday night 03:00.
  - **Previous parsha:** until its late deadline, after which reading is credited as make-up on the date it is logged.
- **Motzaei Shabbat check-in:** shown on the first app open after Havdalah.
  - "Shavua tov! Did you read on Shabbat?"
  - One-tap toggles for each unlogged aliyah plus the haftarah.
  - A single "I finished Parshat {X} on Shabbat" button.
- **Honor statement, shown once at onboarding:** "Shnayim Mikra runs on the honor system. Log what you read, wherever you read it — a Chumash at shul counts just as much as this app."

### 10.8 Reading ahead
- **Within the current parsha:** unlimited. Later plan days become AHEAD.
- **Next parsha:** credit opens at the *earliest-start* setting.
  - Default: **Motzaei Shabbat**, following MB, which counts from Shabbat Mincha. Reading done on Shabbat afternoon after Mincha may be logged with read-date Shabbat.
  - Alternative: **Sunday**.
  - Before it opens, the reader works in **Preview** with no credit. Banner: "Per the Mishnah Berurah, Shnayim Mikra for {Y} counts from Mincha of Shabbat {X}. We'll keep your place."
- **Holiday ("skip") weeks:** the delayed parsha opens **Sunday of the week it is read**, which satisfies every view. During the holiday week the home card says "Holiday week — no parsha due. A good week to catch up on any earlier parsha" when there is backlog.
- **Bereishit:** opens after Simchat Torah ends, which is one day later in the Diaspora than in Israel.

### 10.9 Special weeks
- **Double parsha** (e.g. Vayakhel–Pekudei, Matot–Masei):
  - 14 aliyot / 42 units, verse-balanced over the plan days. The daily KEPT minimum stays at 3 units.
  - Counts +1 week in the streak and +2 parshiyot on the Torah map.
  - First double week earns a "Double portion" milestone.
- **Midweek Yom Tov:** plans rebalance (§10.2). Erev Yom Tov's window closes at candle-lighting. A Yom Tov + Shabbat chain is one merged rest period.
- **Israel / Diaspora:**
  - **Parsha schedule** (Israel or Diaspora) is set separately from **Yom Tov days** (1 or 2). Both default from the time zone and are confirmed in onboarding.
  - **Travel switch:** "This Shabbat I'll be in Israel / outside Israel," per week.
  - **Diaspora → Israel during divergence:** the week's required parsha is the local one. The other is added as **"Also read this week (recommended)"**, following `halacha.md` §4.11. Doing both earns a "Two-schedule week" note. Skipping the second moves it to backlog with **no streak effect**.
  - **Israel → Diaspora:** if the local parsha was already completed, the week is auto-marked ON_TIME ("already read in Israel"). Re-reading is optional.
  - **No streak may ever break because of a schedule switch.**
  - During divergence the calendar shows both readings, as Hebcal does ([Hebcal](https://hebcal.com/home/help/page/7)). Forum threads are keyed **by parsha, not by date**.
- **Tisha B'Av:** quiet day by default, with no reminders and aliyot rebalanced (to be confirmed with the rav).
- **Chol HaMoed:** normal plan days by default. Setting "Treat Chol HaMoed as quiet days."
- **Time zones:** a plan day is the local calendar date on the device. A date skipped while crossing the date line is transparent. A repeated date merges with its twin. Zmanim follow the current location, or the chosen city if location is off.
- **Joining midweek:** the first week is a **starter week**.
  - Option 1: "Catch up this parsha" (rebalanced over the remaining days; evaluated normally).
  - Option 2: "Start with today's aliyah; full plan from Sunday" (week transparent; today counts as KEPT).
  - Days before the join date are never shown as missed.
- **Leap years** add separately read parshiyot automatically from Hebcal. There are 54 parshiyot every year.

### 10.10 Notification specification
**Types.** Each is its own Android channel and iOS category, and all can be toggled.

| # | Type | Default after opt-in | When | Condition |
|---|---|---|---|---|
| 1 | Daily reading reminder | ON | User-chosen time, anchored to a routine | Plan days only. Skipped if today is already KEPT or AHEAD. |
| 2 | Friday wrap-up | ON | The earlier of the user's time and candle-lighting − 3 h, on the last plan day before Shabbat | Parsha incomplete. Once a week. |
| 3 | Motzaei Shabbat / Yom Tov check-in | ON | Havdalah + 60 min, not after 22:30 local, otherwise Sunday at the reminder time | Shabbat-assigned aliyot unlogged or parsha incomplete. |
| 4 | Evening safety net | **OFF** (opt-in) | User-chosen time | Today not yet kept. Never on a day whose window closes at candle-lighting. |
| 5 | Community replies | **OFF** | Daily digest | Only if enabled. |
| 6 | Weekly preview | OFF (ON for T3 users) | Sunday at the reminder time | "This week: {Parsha}, {n} pesukim, ~{m} min." |

- **Milestones** are celebrated in-app, never pushed.
- **Caps:** **≤ 1 push per day** and **≤ 7 per week**, not counting an opted-in community digest. When pushes conflict, priority is 2 > 3 > 1 > 4.
- **Blackout:** no push, local or remote, inside any rest-period window:
  - **Start:** candle-lighting (user's minutes: 18 default, 30 Haifa, 40 Jerusalem, auto by city) **minus 30 min**. If the user picks "I often accept Shabbat early," start at plag haMincha − 30 min.
  - **End:** max(tzeit at 8.5°, sunset + 72 min) on the last day **plus 15 min**.
  - Adjacent periods merge (2-day Yom Tov, Yom Tov + Shabbat).
  - **Unknown location:** Friday 12:00 local to Sunday 01:00 local. The equivalent applies to Yom Tov.
- **Implementation:**
  - Compute windows on the device for the next 14 days and **pre-schedule only outside them**. Recompute on app open, location change, time-zone change and settings change.
  - Upload the windows to the server. The server **holds or drops** any push inside a window, as a second layer of protection. If the server's copy is more than 8 days old, it uses the unknown-location window.
  - Pushes that were held are released 15–45 min (jittered) after the window ends, or dropped if stale.
- **Backoff:**
  - After 5 consecutive reminders with no app open within 6 h, daily reminders drop to Sun/Tue/Thu.
  - After 14 days with no reading, send one final message (copy in §10.15), then send **nothing** until the user returns. On return, restore their settings with a toast.
- **Fading reminders as the habit forms:** after 8 consecutive ON_TIME parshiyot (about 56 days, near Lally's 66-day average), offer: "You've got a rhythm. Keep daily reminders, or switch to a weekly preview?"
- **Content:** rotate at least 12 templates per type so the same text isn't repeated within 7 days. Include concrete details: aliyah name, pesukim count, estimated minutes, and a one-line teaser of the content.

**Permission flow**
1. **Never ask on first launch.** The trigger is completing the **first aliyah**, then the "Make it a habit" anchor screen.
2. Custom priming screen (copy in §10.15). "Yes" fires the OS prompt. "Not now" does nothing, which keeps the one-shot iOS prompt.
3. If the user tapped "Not now," re-offer **once**, after their first full parsha. Never automatically after that. Settings always has the toggle.
4. If the OS prompt was denied, the settings row explains how to re-enable and deep-links to system settings. No nagging.
5. On Android 13+, use the same flow with `POST_NOTIFICATIONS`, plus a rationale when `shouldShowRequestPermissionRationale()` is true. On older Android, the in-app choice is still honored.
6. iOS provisional authorization: optional, and only for the weekly preview. Daily reminders need explicit consent.

### 10.11 Onboarding flow
**Target:** the user is reading the first aliyah within 60–90 seconds, after at most 3 decision screens.

1. **Welcome.** "Read the parsha twice, Targum once — one aliyah a day, done before Shabbat." Buttons: **Start this week's parsha** and *I have an account*.
2. **"Where will you be this Shabbat?"** Israel / Outside Israel, pre-selected from time zone and locale. Required. Includes a "Why we ask" link.
3. **"How do you read?"** Verse by verse (pasuk, pasuk, Targum) is the default, with Section by section and Whole parsha as options. Targum choices: Onkelos (default), Rashi, both, a translation following Rashi. "Change anytime."
4. **"Your plan this week."** A week strip from Sunday to Friday plus a Shabbat candle, with T1 pre-selected. If joining midweek, show the starter-week options (§10.9).
5. **The reader opens on today's aliyah.** No account required.
6. **After the first aliyah:**
   - **Celebration:** "Yasher koach! First aliyah done — {n} pesukim, twice, with Targum."
   - **"Make it a habit":** "After I ___ (finish Shacharit / my commute / dinner / before bed / pick a time), I'll read today's aliyah."
   - Then the **notification priming screen**.
7. **Account** is requested only when needed: syncing or backup, posting in forums, or after the first full parsha ("Save your progress"). Offer Apple, Google and email magic link, and migrate local data.
8. **Asked later, when relevant:** haftarah nusach (when haftarah is turned on), city for Shabbat times (when enabling reminders, via city search with GPS optional), candle-lighting minutes, late window, earliest start, Chol HaMoed handling, display options (nikud, ta'amim, font size), audio nusach.

### 10.12 Progress UI
- **Parsha ring** on the home card:
  - Three concentric rings: outer **Mikra I**, middle **Mikra II**, inner **Targum** (labeled "Rashi" if chosen).
  - Each ring has 7 arcs (14 in double weeks), sized by verse count.
  - A **plan tick** on the outer ring marks where today's target is.
  - The **center** shows "4 of 7 aliyot," "Shabbat in 2 days · candles 6:42 pm," and a haftarah dot (hollow if off).
  - Verse-by-verse readers fill all three rings together.
- **Week strip** with chips for Sunday to Friday plus Shabbat:
  - Filled = KEPT. Filled with an arrow = AHEAD. Half-filled = CAUGHT_UP. Shield = GRACE. ‖ = paused. Outline = open or upcoming. Dotted gray = missed.
  - **Never red.** Shabbat and Yom Tov always show candle or holiday icons.
- **Streak header:** "Parsha streak 12" first, then "Days on track 47," with Longest and "This year 31/54" in the detail sheet.
  - Toggles: **Hide streak numbers**, and **Focus mode** (ring and Torah map only).
- **Year of Torah heatmap:**
  - Rows are parsha weeks from Bereishit to Vezot HaBeracha. Columns are Sunday to Friday plus Shabbat.
  - Intensity is units logged. Rest days show icons, never blank.
  - Can switch to a Gregorian view.
- **Torah map:** five rows (one per book) of parsha tiles.
  - Tile states: solid = on time; solid with a dot = late or restored; striped = made up; outline = missed; faint = upcoming.
  - Tapping a missed tile offers "Make it up before Simchat Torah." It is optional and never pushed.
- **Totals:** "{done}/54 parshiyot · {pesukim} pesukim," computed from data, never hard-coded.

### 10.13 Milestones (informational: no points, XP or currency)
- **Firsts:**
  - First aliyah.
  - First parsha.
  - First **Perfect week**: every plan day KEPT or AHEAD, no grace days, ON_TIME.
- **Parsha streak:** 4, 13, 18 (*chai*), 26, 36 (*double chai*), and 54 (a full cycle's worth).
- **Days on track:** 7, 30, 66, 100, 180, 365.
- **Sefer complete:** a ***Chazak, chazak, v'nitchazek!*** animation and an optional share card.
- **Siyum HaTorah:**
  - A dated certificate with both the Hebrew and Gregorian dates.
  - An invitation to the community Siyum thread.
  - Suggested Hoshana Rabbah night make-up if a few parshiyot are still missing.
- **Week types:** double portion, two-schedule week, haftarah every week for a full sefer.
- **Comeback:** first parsha completed after a missed week or a pause. "Welcome back" is celebrated as warmly as a long streak.

### 10.14 Community and sharing
- **Weekly parsha threads** are keyed by parsha, and Israel/Diaspora dates are both shown.
- **Anonymous aggregate:** "1,240 readers finished Vayera this week." It is shown after the user's own completion, framed as community, not competition.
- **Chavruta circle** (opt-in, up to 5 people):
  - Members see each other's **weekly** ring completion only, never daily status.
  - At most one preset nudge per week ("Thinking of you — Shabbat's coming!"), never inside a blackout.
- **Siyum board** for sefer and cycle completions.
- **No leaderboards.** Streak numbers are never public by default. A forum badge is opt-in.

### 10.15 Copy library

| Moment | Use | Never |
|---|---|---|
| Daily reminder | "Today: Revi'i of Lech Lecha · 26 pesukim · ~12 min. After {anchor}, it's yours." | "Don't lose your 40-day streak!" |
| Behind midweek | "You're 2 aliyot behind — very normal midweek. Catch-up plan: Shlishi + Revi'i today, or spread over Thu–Fri?" | "You're falling behind!" |
| Friday wrap-up | "Shabbat begins at 6:42 pm. 2 aliyot left (~20 min). Or finish Shabbat morning from your Chumash and log it after Havdalah." | Countdown timers |
| Motzaei Shabbat | "Shavua tov! Did you read anything on Shabbat? Tap to log it." | "You didn't finish." |
| Grace day used | "Wednesday was covered by a grace day — your rhythm continues. You'll earn another when you finish this parsha." | "You used a freeze. 1 left!" |
| Daily streak reset | "Your day count reset, but your learning didn't: 31 parshiyot this year, 6,210 pesukim. Tomorrow's aliyah is ready whenever you are." | "You lost your streak." / sad mascot |
| Late completion | "Parshat Noach complete — after Shabbat, and it still counts. Your parsha streak continues." | "Late!" in red |
| Restore offer | "Noach is still open. Finish Noach and Lech Lecha by Shabbat to keep your 12-week streak — one double-up per sefer." | "Last chance!!" |
| Parsha streak reset | "A new parsha, a fresh start. Vayera begins tonight — 7 aliyot, ~85 min this week." | "Start over from zero." |
| Pause | "Life comes first. Pause for up to 30 days — nothing resets while paused." | "Are you sure? You'll fall behind." |
| Notification priming | "Want a gentle daily nudge? At {time}, after {anchor}. **Never on Shabbat or Yom Tov.** At most one a day — change anytime." [Yes, remind me] [Not now] | "Enable notifications or you'll forget!" |
| Final backoff message | "We'll pause reminders for now. Your place in Parshat {X} is saved — come back anytime." | "We miss you 😢" |
| Sefer complete | "Chazak, chazak, v'nitchazek! Sefer Bereishit — {n} pesukim, twice, with Targum." | "You earned 500 points!" |
| Siyum | "Mazel tov — you've completed Shnayim Mikra for the entire Torah this year." | (no upsell on this screen) |

### 10.16 Anti-patterns this app will never ship
1. Paid or ad-gated grace days, streak repair or restores. Compassion features are never behind a premium tier.
2. Any notification during a rest-period blackout, or "streak at risk" pushes the user didn't opt into.
3. Countdown timers, red "missed" marks, sad or disappointed mascots, confirmshaming.
4. Requiring an account before the first aliyah. Re-asking for notification permission more than once.
5. Leaderboards, public streak numbers by default, daily pair streaks.
6. Treating offline or printed-book reading as second-class, or adding anti-cheat friction.
7. Streak rules that make reading ahead, Shabbat, Yom Tov or a schedule switch cost anything.
8. Points, XP or currency attached to Torah reading.

### 10.17 Metrics and experiments
- **North star:** the **weekly on-time completion rate**, the share of weekly-active users with the parsha ON_TIME.
- **Retention:** W1, W4, W12, W26 weekly retention. Weekly fits this practice better than DAU.
- **Resilience:**
  - **Rebound rate:** the share returning within 7 days after a MISSED day or week (compare Sharif & Shu's 55% vs 37%).
  - Grace-day and restore-token usage.
- **Guardrails:**
  - Notification disable rate (target < 10% per month).
  - Opt-out of streak visibility.
  - A quarterly one-item survey, "Using this app makes me feel pressured" (1–7), trending down.
  - Support tickets about Shabbat notifications: **must be 0**.
- **Experiments:**
  1. Starting grace balance of 2 vs 3.
  2. Daily KEPT minimum of 3 units vs "any unit."
  3. Reminders anchored to a routine vs time-only.
  4. Content-rich vs plain reminder copy.
  5. Friday wrap-up at candle-lighting − 3 h vs − 5 h.
  6. Days on track shown vs hidden by default for new users.
  7. Offering to fade reminders at 8 vs 12 ON_TIME weeks.

### 10.18 Reference pseudocode

```ts
type DayStatus = 'KEPT'|'AHEAD'|'CAUGHT_UP'|'GRACE'|'PAUSED'|'MISSED'|'TRANSPARENT'|'OPEN';

function evaluatePlanDay(D: PlanDay, N: PlanDay | null, u: User): DayStatus {
  if (isPaused(u, D.date)) return 'PAUSED';
  const p = D.parsha;
  // Logged = units logged with read-date inside D's device-day window, from any open parsha
  if (unitsLoggedInWindow(u, D.window, openParshiyot(u, D)) >= 3) return 'KEPT';
  if (completedUnits(u, p, D.window.close) >= cumulativeTarget(u.plan, p, D)) return 'AHEAD';
  if (!N || now() < N.window.close) return 'OPEN';            // not final yet
  const targetN = N.parsha === p ? cumulativeTarget(u.plan, p, N) : totalUnits(p);
  if (completedUnits(u, p, N.window.close) >= targetN) return 'CAUGHT_UP';
  if (u.grace.balance > 0 && u.grace.usedInWeek(p) < 2) { u.grace.consume(D); return 'GRACE'; }
  return 'MISSED';
}

function dailyStreak(statuses: DayStatus[]): number {          // chronological, plan days only
  let s = 0;
  for (const st of statuses) {
    if (st === 'KEPT' || st === 'AHEAD' || st === 'CAUGHT_UP') s++;
    else if (st === 'MISSED') s = 0;                            // GRACE/PAUSED/OPEN/TRANSPARENT hold
  }
  return s;
}

type WeekStatus = 'ON_TIME'|'LATE'|'RESTORED'|'MADE_UP'|'MISSED'|'TRANSPARENT'|'OVERDUE'|'IN_PROGRESS';

function evaluateParsha(P: Parsha, u: User): WeekStatus {
  if (P.isHolidayWeek) return 'TRANSPARENT';
  const doneAt = completionReadDate(u, P);                      // null if incomplete
  if (doneAt && doneAt <= P.shabbat) return 'ON_TIME';          // incl. "finished on Shabbat" attestation
  if (doneAt && doneAt <= lateDeadline(P, u.settings)) return 'LATE';
  if (!doneAt && now() <= lateDeadline(P, u.settings)) return 'IN_PROGRESS';
  if (isPausedWeek(u, P)) return 'TRANSPARENT';                 // never hurts: completed weeks evaluated above
  const next = nextParsha(P);
  if (u.restoreTokens(P.sefer) > 0) {
    const nextDone = completionReadDate(u, next);
    if (doneAt && nextDone && max(doneAt, nextDone) <= next.shabbat) return 'RESTORED';
    if (now() <= next.shabbat) return 'OVERDUE';                // streak number held, restore offered
  }
  if (doneAt && doneAt <= simchatTorahEnd(P.cycle, u.settings)) return 'MADE_UP';
  return 'MISSED';                                              // becomes MADE_UP if completed before Simchat Torah
}
```

Worked example of a regular Diaspora week on plan T1:
- **Sunday:** reads Rishon → KEPT.
- **Monday:** reads nothing → OPEN.
- **Tuesday:** reads Sheni + Shlishi → Tuesday KEPT. Monday becomes CAUGHT_UP, because the cumulative target through Tuesday (3) was reached.
- **Wednesday:** reads nothing.
- **Thursday:** reads only Revi'i → Thursday KEPT. Wednesday was not caught up (4 of 5 done by Thursday's close), so it becomes GRACE (balance 2 → 1).
- **Friday:** reads Chamishi + Shishi → KEPT.
- **Shabbat morning:** reads Shevi'i from a Chumash and logs it at Motzaei Shabbat with "finished on Shabbat."
- **Result:** the parsha is **ON_TIME** (grace balance back to 2), Days on track +5 (Wednesday held), Parsha streak +1.

### 10.19 Open questions for the rabbinic advisor
1. Late-window default: Tuesday nightfall vs all of Wednesday. Is "end of the Tuesday device day" acceptable wording?
2. Vezot HaBeracha: on-time window, and is any late window meaningful after Simchat Torah?
3. Skip weeks: confirm "the delayed parsha opens Sunday of its week" as the safe default.
4. Tisha B'Av: confirm it is a quiet day with no Shnayim Mikra. Chol HaMoed: confirm the default.
5. Traveler logic (`halacha.md` §4.11): should "also read this week" be *recommended* (current proposal) or *required*?
6. Wording of the "translation following Rashi" option, and its default visibility.

---

## 11. References (grouped)

**Duolingo:**
- [Improving the streak](https://blog.duolingo.com/improving-the-streak)
- [How the streak builds habit](https://blog.duolingo.com/how-duolingo-streak-builds-habit)
- [How streaks keep learners committed (engineering)](https://making.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals)
- [Tips for maintaining streak](https://blog.duolingo.com/tips-for-maintaining-streak)
- [Lenny's: Behind the product](https://lennysnewsletter.com/p/behind-the-product-duolingo-streaks)
- [recall.it summary](https://www.recall.it/summary/lennys-podcast/behind-the-product-duolingo-streaks-or-jackson-shuttleworth-group-pm-retention-team)
- [Lazyweb experiments](https://lazyweb.com/research/duolingo-retention-experiments)
- [Streak Freeze wiki](https://duolingo.fandom.com/wiki/Shop/Streak_freeze)
- [Android Authority: revive event](https://androidauthority.com/duolingo-revive-broken-streak-event-3673004/)
- [Yancey & Settles KDD'20](https://research.duolingo.com/papers/yancey.kdd20.pdf)
- [Medium: "Duolingo needs to chill"](https://debugger.medium.com/duolingo-needs-to-chill-8f1832745ca0)
- [Taplytics: reminder stop](https://taplytics.com/blog/duolingo-sends-push-notifications-to-let-users-know-they-know-theyre-not-engaging-with-their-reminders)
- [First Round: A/B tenets](https://review.firstround.com/the-tenets-of-a-b-testing-from-duolingos-master-growth-hacker)
- [Appcues: Duolingo onboarding](https://goodux.appcues.com/blog/duolingo-user-onboarding)
- [Screenwise parent guide](https://screenwiseapp.com/guides/managing-duolingo-streaks-when-gamification-becomes-stressful)
- [Business of Apps: Busuu +15% sessions after streaks](https://www.businessofapps.com/news/duolingos-streak-feature-drives-record-17-million-daus)

**Other apps:**
- Snapchat: [Dexerto](https://www.dexerto.com/entertainment/how-to-get-streaks-back-1849331/), [Techpp](https://techpp.com/2023/10/05/snap-streak-lost-recover-guide/), [TechCrunch](https://techcrunch.com/2024/04/05/snapchat-turns-off-controversial-solar-system-feature-by-default-after-bad-press), [UBC summary of van Essen et al.](https://blogs.ubc.ca/etec523/2024/06/02/snapchat-streaks/)
- Headspace: [Built for Mars](https://builtformars.com/ux-bites/hiding-your-headspace-streaks), [Headspace article](https://www.headspace.com/articles/speed-bumps-two-headspacers-learn-to-take-things-in-stride)
- [Calm Help](https://support.calm.com/hc/en-us/articles/115002473827-How-to-View-Your-Meditation-Stats-History-and-Streak-in-Calm)
- [Declutter the Mind](https://declutterthemind.com/features/streaks-and-stats)
- GitHub: [GitHub blog 2016](https://github.blog/news-insights/product-news/more-contributions-on-your-profile), [Moldon et al.](https://arxiv.org/abs/2006.02371v1)
- Apple: [Macworld](https://www.macworld.com/article/2446605/how-to-pause-apple-watch-activity-rings.html), [BGR](https://www.bgr.com/tech/watchos-11-activity-rings-have-big-changes-heres-whats-new/), [MobiHealthNews / Blahnik](https://www.mobihealthnews.com/news/jay-blahnik-what-separates-apple-watch-other-fitness-trackers)
- [Strava streaks](https://support.strava.com/hc/en-us/articles/36553427481997-Streaks-on-Strava)
- [Finch review](https://habitbox.app/blog/finch-app-review)
- YouVersion: [Outreach](https://outreachmagazine.com/?p=39061), [Catch Me Up](https://thesweetsetup.com/use-catch-feature-youversions-reading-plans/), [Christianity Today](https://christianitytoday.com/news/2015/december/most-popular-bible-verses-200-million-youversion-app-2015.html)

**Jewish learning:**
- 929: [929 About](https://www.929.org.il/pages/aboutEN.html), [929 Wikipedia](https://en.wikipedia.org/wiki/929:_Tanakh_B%27yachad), [Hebcal nine29](https://pkg.go.dev/github.com/hebcal/learning/nine29)
- [Sefaria calendars](https://sefaria.org.il/calendars)
- Hebcal: [hebcal-learning](https://github.com/hebcal/hebcal-learning), [Hebcal leyning API](https://www.hebcal.com/home/4277/leyning-torah-reading-api), [@hebcal/leyning](https://www.npmjs.com/package/@hebcal/leyning), [@hebcal/core README](https://cdn.jsdelivr.net/npm/@hebcal/core@6.5.3/README.md)
- Shnayim Mikra apps: [Shnayim app](https://apps.apple.com/app/id1296709500), [Shnayim Mikra Tracker](https://apps.apple.com/app/id6762082339)
- [OU Shnayim Mikra emails](https://ou.org/news/coming-inbox-near-ou-torah-launches-shanyim-mikra-daily-email-series)
- Chabad: [Chabad Daily Study](https://apps.apple.com/us/app/chabad-org-daily-torah-study/id1408133263), [Rambam App](https://apps.apple.com/app/id1571859668)
- All Daf: [All Daf](https://alldaf.org/about-us), [OU siyum](https://ou.org/news/orthodox-unions-torah-initiatives-and-upper-west-side-community-celebrate-siyum-on-maseches-sotah)
- [Mishnah Yomis](https://en.wikipedia.org/wiki/Mishnah_Yomis)

**Halacha:**
- OU Torah: [When to learn](https://outorah.org/p/81536), [Weekly completion](https://www.outorah.org/p/173583), [Timing](https://outorah.org/p/173503), [Twenty Questions Pt 2](https://outorah.org/p/81739), [Yom Tov readings](https://www.outorah.org/p/174227)
- dinonline: [Time](https://dinonline.org/2019/10/22/time-for-shnayim-mikra-ve-echad-targum/), [Midweek Yom Tov](https://dinonline.org/2017/05/19/shnayim-mikra-when-yom-tov-is-in-middle-of-the-week/), [Vezot HaBeracha](https://dinonline.org/2011/10/10/best-time-for-shanyim-mikra-of-vezos-haberachah/)
- [Shulchan Aruch HaRav: When to read](https://shulchanaruchharav.com/?p=1015)
- [Kol Torah basics](https://www.koltorah.org/halachah/shnayim-mikrah-vechad-targum-basics-by-rabbi-chaim-jachternbsp)
- [Wikipedia](https://en.wikipedia.org/wiki/Shnayim_mikra_ve-echad_targum)
- Israel/Diaspora: [Sefaria sheet](https://sefaria.org/sheets/339455), [OU 49153](https://outorah.org/p/49153), [Hebcal changelog](https://hebcal.com/home/help/page/7)
- [Chabad: double portions](https://www.chabad.org/library/article_cdo/aid/3779325/jewish/Why-Do-We-Sometimes-Read-a-Double-Torah-Portion.htm)
- Companion file `research/halacha.md`

**Behavioral science:**
- Lally: [UCL](https://www.ucl.ac.uk/news/2009/aug/how-long-does-it-take-form-habit), [BPS](https://bps.org.uk/research-digest/how-form-habit)
- [Fogg / Tiny Habits (Stanford)](https://med.stanford.edu/content/dam/sm/ascend/documents/Introduction_%20Tiny%20Habits%20for%20Self%20Compassion,%20Getting%20Started.pdf)
- Gollwitzer & Sheeran: [Frontiers](https://www.frontiersin.org/articles/10.3389/fpsyg.2021.565202/full), [record](https://stafforini.com/works/gollwitzer-2006-implementation-intentions-and/)
- [Stawarz et al.](https://discovery.ucl.ac.uk/id/eprint/1468224/)
- [Wood interview](https://www.behavioralscientist.org/good-habits-bad-habits-a-conversation-with-wendy-wood/)
- [Dai, Milkman & Riis](https://faculty.wharton.upenn.edu/wp-content/uploads/2014/06/Dai_Fresh_Start_2014_Mgmt_Sci.pdf)
- Silverman & Barasch: [CU Boulder](https://www.colorado.edu/business/faculty-research/2023/04/19/or-track-how-broken-streaks-affect-consumer-decisions), [UDel](https://udspace.udel.edu/handle/19716/34160)
- Sharif & Shu: [UCLA Anderson](https://anderson-review.ucla.edu/emergency-reserves/), [Wharton PDF](https://marketing.wharton.upenn.edu/wp-content/uploads/2016/10/Designing-More-Effective-Goals-by-Using-Emergency-Reserves-A-Field-Experiment.pdf)
- Milkman megastudy: [Caltech](https://authors.library.caltech.edu/records/mys88-cc756), [Scimex](https://www.scimex.org/newsfeed/which-programs-give-gym-goers-the-biggest-boost)
- [Beshears et al.](https://pubsonline.informs.org/doi/fpi/10.1287/mnsc.2020.3706)
- [Breines & Chen](https://pubmed.ncbi.nlm.nih.gov/22645164/)
- [Deci, Koestner & Ryan](https://depts.washington.edu/techdocs/papers/deciExtrinsicRewardsAndIntrinsicMotivation99.pdf)
- [Kivetz et al.](https://business.columbia.edu/sites/default/files-efs/pubfiles/1200/goalgradient.pdf)
- [Nunes & Drèze (Coglode)](https://coglode.com/nuggets/endowed-progress-effect)
- Badges: [Anderson et al.](https://archives.iw3c2.org/www2013/proceedings/p95.pdf), [Hoernle et al.](https://ar5iv.labs.arxiv.org/html/2002.06160)
- [Decision Lab: streak creep](https://thedecisionlab.com/insights/consumer-insights/streak-creep-the-perils-of-too-much-gamification)
- [Indie Hackers: removing streak counter](https://www.indiehackers.com/post/im-removing-the-streak-counter-from-my-habit-app-here-s-why-7d2a6179dd)
- [Religious gamification](https://bulletin-religious.kaznu.kz/index.php/relig/en/article/view/772)
- Lishmah: [Sefaria sheet](https://www.sefaria.org/sheets/315194), [KBY](https://kby.org/english/torat-yavneh/view.asp?id=8847)

**Ethics, notifications and onboarding:**
- Ethics: [CHT](https://centerforhumanetechnology.substack.com/p/what-do-we-mean-by-human-tech), [CHT design](https://www.humanetech.com/humane-product-design), [deceptive.design: confirmshaming](https://deceptive.design/articles/creative-manipulation-a-case-study-of-confirmshaming-as-a-deceptive-design-pattern), [deceptive.design: Duolingo repair](https://www.deceptive.design/articles/when-a-user-uses-duolingo-on-a-series-of-consecutive-days-this-is-called-a-streak-if-users-miss-a-day-they-can-pay-to-repair-it), [Gray et al. slides](https://courses.cs.washington.edu/courses/cse340/22sp/slides/wk09/Dark-Patterns-Deceptive-Design.pdf), [FTC report (Venable)](https://www.venable.com/insights/blogs/2022/09/the-ftc-brings-more-light-to-dark-patterns-in-new)
- Platform permissions: [Android permission](https://developer.android.com/develop/ui/views/notifications/notification-permission), [Apple permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications), [Provisional auth](https://nilcoalescing.com/blog/TrialNotificationsWithProvisionalAuthorizationOnIOS)
- Push benchmarks: [Airship 2025](https://growth.airship.com/rs/313-QPJ-195/images/Airship-2025-Push-Notification-Benchmarks-EN.pdf?version=0), [Pushwoosh](https://www.pushwoosh.com/blog/push-notification-benchmarks/), [Batch](https://batch.com/blog/case-studies/benchmark-notifications-push-crm-mobile), [Localytics/MarketingProfs](https://www.marketingprofs.com/charts/2018/33486/how-many-mobile-push-notifications-are-too-many), [Braze opt-out](https://www.braze.com/resources/articles/opt-out-of-push-notifications-why-users-do-it), [Braze primer](https://www.braze.com/resources/articles/whats-a-push-primer)
- Onboarding: [NN/g tutorials](https://www.nngroup.com/articles/mobile-tutorials/), [Appcues gradual engagement](https://www.appcues.com/blog/gradual-engagement-mobile-app-first-screen), [Auth0](https://auth0.com/blog/should-you-give-users-access-before-they-register/)
