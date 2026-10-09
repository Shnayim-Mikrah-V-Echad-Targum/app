# Shnayim Mikra v'Echad Targum: halachic and practical research for product design

Prepared 2026-10-09. Scope: the halachic and customary details that should drive features in a cross-platform app for reading the weekly parsha twice in Hebrew (Mikra) and once in Targum Onkelos.

---

## 0. Method, limits and confidence key

**How this was researched.** WebFetch could not reach any of the target sites from this environment. The network policy refused sefaria.org, halachipedia.com, koltorah.org, outorah.org, chabad.org, dinonline.org and wikipedia.org (DNS failures or proxy `403 connect_rejected`). So **no primary text was read verbatim**: not the Shulchan Aruch, Mishnah Berurah, Gemara or Kitzur. Every finding below comes from WebSearch summaries of the pages listed (URLs given), plus background knowledge, which is flagged where used. Late in the session the shared web-search budget ran out too, so a few points remain open. They are listed in section 7.

**Before shipping**, have a rav or knowledgeable editor check the siman/se'if katan numbers against a printed Mishnah Berurah. Some numbers below are secondhand and may be off by one.

**Confidence key**
- **[S+]**: several independent secondary sources agree.
- **[S]**: one secondary source supports it (URL given).
- **[K]**: background knowledge, not confirmed by any source in this session.
- **[U]**: uncertain, disputed, or sources conflict. Treat as an open question.

---

## 1. Core obligation and who is obligated

### 1.1 Source and wording
- **Gemara, Berakhot 8a–b.** Rav Huna bar Yehuda, in the name of R. Ami: *"לעולם ישלים אדם פרשיותיו עם הציבור שנים מקרא ואחד תרגום, ואפילו עטרות ודיבון, שכל המשלים פרשיותיו עם הציבור מאריכין לו ימיו ושנותיו"*. In English: always complete your parshiyot with the congregation, twice Mikra and once Targum, even "Atarot v'Divon"; whoever does so is granted length of days and years. **[S+]** (sefaria.org/sheets/20854; jewishpress.com 2013/12/20; Wikipedia)
- The same sugya tells of Rav Bibi bar Abaye, who wanted to finish all the year's parshiyot on Erev Yom Kippur. This is the basis for later discussion of making up missed weeks. **[S]** (sefaria.org/sheets/20854)
- **Shulchan Aruch OC 285:1** (following Rambam, Hilchot Tefillah 13:25 **[K]**): *"אף על פי שאדם שומע כל התורה כולה כל שבת בציבור, חייב לקרות לעצמו בכל שבוע פרשת אותו שבוע שנים מקרא ואחד תרגום, ואפילו עטרות ודיבון"*. **[S]** (yeshiva.org.il wiki "שניים מקרא ואחד תרגום")
- **Status.** The obligation is rabbinic (Aruch HaShulchan 285:2). **[S]** (koltorah.org, Jachter)
  - The Shulchan Aruch rules it a real obligation (חייב).
  - Minority Rishonim disagree. Ra'avan limited it to someone without a minyan. Shibolei HaLeket held it is not an obligation. **[S]** (yeshiva.org.il wiki)
  - Rav Moshe Feinstein: a talmid chacham busy with other learning is not exempt. **[S]**
  - Rav Dov Lior: a soldier with little time may prioritize halacha and emunah over it. **[S]** (yeshiva.org.il wiki)
- **Rationale.**
  - Levush: so that every Jew becomes fluent in the Torah. **[S]** (yeshiva.org.il wiki; koltorah.org Frazer)
  - Others: the two readings parallel the Torah given at Sinai and at the Ohel Moed. **[S]** (koltorah.org Frazer)
- **Segulah:** length of days and years (Berakhot 8b). The Ba'al HaTurim also calls it a segulah for long life. **[S+]**

### 1.2 Men
- Adult men are obligated (SA 285:1). **[S+]**
- Kaf HaChaim 285:9–10: someone ill or with eye pain is exempt but should make it up after recovering. A blind person is exempt, though listening to someone else read is meritorious. **[S]** (outorah.org, via search summary)
- **Mourners.** SA Yoreh De'ah 400:1 allows a mourner during shiva to do Shnayim Mikra on Shabbat, even though Torah study is otherwise forbidden to him. **[S]** (koltorah.org, Jachter) On weekdays of shiva he does not learn (general aveilut laws). **[K]**

### 1.3 Women
- **Most sources: women are exempt.**
  - OU "Twenty Questions Part 1" grounds the exemption in women's general exemption from Talmud Torah (Rambam, Talmud Torah 1:1), noting that voluntary study is rewarded (ibid. 1:13). **[S]** (outorah.org/p/81738)
  - Yalkut Yosef OC 285:12 gives a different reason: it is a time-bound positive mitzvah. **[S]** (koltorah.org, Jachter)
  - A yeshiva.org.il responsum: "we have not heard that women are obligated". **[S]**
- **A woman who wishes may fulfill it.** **[S]** (shulchanaruchharav.com/?p=1012)
- Related: MB 282:12 cites Masechet Soferim on women hearing the public Torah reading and concludes that the practice is not to be stringent. **[S]** (outorah.org/p/81738)

### 1.4 Minors and bar mitzvah
- Boys old enough for chinuch, who can read the parsha fluently and understand it, should be trained to do Shnayim Mikra. **[S]** (shulchanaruchharav.com/?p=1012)
- **Mid-year bar mitzvah.** Rav Yaakov Kamenetsky ruled that the boy need not restart the annual cycle. Parshiyot he completed as a minor count, since a minor already has an obligation of Torah study. **[S]** (outorah.org/p/81738)

---

## 2. Timeline

### 2.1 Summary table

| Stage | Rule | Source | Conf. |
|---|---|---|---|
| Earliest start | "From Sunday onward" counts as "with the congregation" (SA 285:3). **MB 285:7:** this really means from **Shabbat Mincha of the previous week**, when the congregation starts reading the next parsha. Other authorities hold Sunday means Sunday, and one should optimally not start on Shabbat afternoon. The Shulchan Aruch HaRav (Chabad) site says not before Sunday. | outorah.org/p/81536; dinonline 2019/10/22; shulchanaruchharav.com/?p=1015; ph.yhb.org.il | [S+] |
| Not too early | Reading more than a week ahead does not count as "with the congregation". The Rav Bibi story is about making up past parshiyot, not reading future ones. | Berakhot 8b; Tosafot cited in etzion.org.il doc | [S] |
| Ideal deadline | **Before the Shabbat-day meal** (SA 285:4). Source: Tosafot, citing Rebbi's instruction to his household. MB: do not push the meal past chatzot (midday) for this. Chazon Ish reportedly reads it as the third meal. | outorah.org/p/173503; etzion.org.il; dinonline | [S] (Chazon Ish: [U]) |
| Second-best | If not before the meal, then **after the meal until Mincha**, when the next parsha begins (SA 285:4). | yeshiva.org.il/midrash/6696; outorah.org/p/173503 | [S+] |
| Bedieved 1 | SA 285:4: "some say **until Wednesday**" (יש אומרים עד רביעי; Hagahot Maimoniyot citing Maharam of Rothenburg). It is usually applied as **"by Tuesday night"** (before Wednesday begins). Kol Bo 37 draws the parallel to Havdalah, which may be said bedieved through Tuesday. Hidabroot: "עד יום שלישי בלילה". Shulchan Aruch HaRav site: "at the very least prior to Tuesday night". | outorah.org/p/173503; hidabroot.org/question/276789; shulchanaruchharav.com/?p=1015 | [S] (exact cutoff: [U]) |
| Bedieved 2 | "Some say **until Shemini Atzeret**" (SA 285:4), i.e., Simchat Torah, when the congregation finishes the Torah. In Israel that is Shemini Atzeret. **MB 285:12:** this is only bedieved; lechatchila the reading belongs to the same week. After Simchat Torah the missed parshiyot are lost. | outorah.org/p/173583; shulchanaruchharav.com/?p=1015 | [S+] |
| Priority when behind | The current week's parsha comes first; then make up the missed ones. | shulchanaruchharav.com/?p=1015 (summary) | [S] |
| General | Completing it at any point during the week fulfills the obligation (Peninei Halakha). | ph.yhb.org.il/en/01-05-10/ | [S] |

### 2.2 Ideal time of day and week (customs)

| Custom | Practice | Source | Conf. |
|---|---|---|---|
| **Shelah**, cited by Taz | Friday **after midday** | etzion.org.il doc | [S] |
| **Arizal** | Friday **morning, right after Shacharit, still in tallit and tefillin**, whole parsha straight through without interruption. If missed on Friday, then on Shabbat. Some read the Arizal as Friday after midday; the Chida rejects that and says morning. | halachayomit.co.il/en/pdf/6376.pdf; ph.yhb.org.il (Kaf HaChaim 285:3; Shelah; Tur) | [S] |
| **Chabad** (Shulchan Aruch HaRav; Sefer HaMinhagim cited in footnotes) | **Entire** parsha **after midday on Erev Shabbat**. No need to start exactly at midday, but do not delay once it has passed. If missed, before the Shabbat meal, and at least before Mincha. | shulchanaruchharav.com/?p=1015 and ?p=18294 | [S] |
| **Vilna Gaon** | **One aliyah per day**, finishing the parsha on Shabbat (MB 285:8). One source instead reports the Gra reading a whole open/closed section at a time. | ph.yhb.org.il/en/01-05-10/; sheilot.com guide | [S] (Gra details: [U]) |
| **Rav Soloveitchik** | The primary time is Shabbat. | koltorah.org (Jachter) | [S] |

A popular ranking (Wikipedia): Friday after midday, then Friday after Shacharit, then Shabbat morning before the meal, then before Mincha, then bedieved through Tuesday. **[S]**

**Rav Ovadia Yosef / Yalkut Yosef: not confirmed.** The search found Chazon Ovadia only on the question of reading on Yom Tov that falls on Friday: Rama MiPano discouraged it, and Chazon Ovadia says it is not an absolute prohibition. Searches did not reach Yalkut Yosef on the preferred weekday. **[U]**

### 2.3 End of the year: Vezot HaBeracha and Bereishit
- **Vezot HaBeracha**
  - **MB 285:18:** best on the **day of Hoshana Rabbah**; one also fulfills it on Shemini Atzeret. **[S+]** (outorah.org/p/81739; dinonline 2011/10/10)
  - **MB 669:4** (per dinonline): best on the **night of Simchat Torah**. The two MB passages are not obviously consistent. **[U]**
  - The night of Hoshana Rabbah is valid but not named as ideal. **[S]**
  - Piskei Teshuvot 285:4 cites a view that one does not fulfill it before Hoshana Rabbah; others disagree. **[S]**
  - **Chabad:** on Hoshana Rabbah night, Devarim (including Vezot HaBeracha) is read as usual in the Mishneh Torah reading, but Vezot HaBeracha is read as Shnayim Mikra on the day before Simchat Torah. **[S]** (shulchanaruchharav.com Hoshana Rabbah page)
- **Bereishit**
  - Starts **only after Bereishit is read on Simchat Torah**. Until then the week's parsha is still Vezot HaBeracha. **[S]** (dinonline 2011/10/08 and 2014/10/15)
  - When Simchat Torah falls on Shabbat (possible in Israel), the Mishnah Acharona holds one may start right after Chatan Bereishit, without waiting for Mincha. **[S]**
  - The window before Shabbat Bereishit is therefore short, and in the diaspora it opens on Yom Tov, so in practice the user can start only after Yom Tov.
- **Yom Tov on Shabbat ("skip week").** When a Yom Tov reading displaces the parsha, two weeks pass between the Shabbat Mincha that begins a parsha and the Shabbat it is read. The OU article (Mishnah Acharona) says the start time is still that earlier Shabbat Mincha, but the full conclusion was cut off in search results. **[U]** (outorah.org/p/81739)
- **Festival readings themselves** (Yom Tov, Shabbat Chol HaMoed) carry **no Shnayim Mikra obligation**. Terumat HaDeshen limits the obligation to the Shabbat parshiyot. **[S]** (sheilot.com guide; etzion.org.il)

---

## 3. Methods of reading

### 3.1 Order and unit
- **MB 285:2** permits both:
  - **(a) Verse by verse:** each pasuk twice, then its Targum (or Rashi).
  - **(b) Section by section:** read up to a break, a parasha **petucha/setuma** (marked פ/ס in the Chumash) or the end of a topic, twice, then its Targum.
  - **[S+]** (outorah.org/p/173224; ph.yhb.org.il; sheilot.com/en/articles/shabbos/view/6327)
- Aruch HaShulchan 285:7 also accepts both. **[S]** (koltorah.org)
- **Who prefers which:**
  - Verse by verse: Arizal and Magen Avraham.
  - Section by section: Shelah and Vilna Gaon.
  - **[S+]** (ph.yhb.org.il/en/01-05-10/; outorah.org/p/173224)
- **Mikra before Targum** lechatchila (MB 285:6). **[S]** (outorah.org/p/81739)
- **Mikra–Targum–Mikra** variant:
  - The Chavot Yair suggests Mikra, then Targum/Rashi, then Mikra again, since the second reading is better understood after the commentary.
  - The Levush allows it. Aruch HaShulchan 285:3 cites the Levush as permitting it even lechatchila.
  - Most authorities differ.
  - **[S]** (outorah.org/p/173224)
- **Letter of the law:** any order works. With no Targum at hand, one may read the Mikra twice now and the Targum later. **[S]** (shulchanaruchharav.com/?p=1016)
- **Do not split a pasuk** (Taanit 27b; Megillah 22a). Section readers break at petucha/setuma markers. **[S]** (outorah.org/p/173224)

### 3.2 Daily division
- **Legally, the whole parsha need not be read in one sitting.** One section one day and another the next is fine. **[S]** (shulchanaruchharav.com/?p=1016)
- **Gra: one aliyah per day** (MB 285:8), finishing on Shabbat. **[S]**
- **Where to stop each day** (sheilot.com guide, following the Gra's view that a reading may be divided at the end of a topic):
  - Stop at the petucha/setuma nearest the aliyah boundary.
  - Or stop at the aliyah break itself if it ends a topic.
  - **[S]**
- **Is there one widespread Shnayim Mikra schedule? No single universal schedule was found.** **[U]** The two dominant patterns are:
  1. **Aliyah-a-day**
     - Sunday = 1st aliyah … Friday = 6th.
     - The 7th aliyah (and haftarah) then goes either on Friday with the 6th, or Shabbat morning before the meal (which SA 285:4 still treats as ideal).
     - The "finish on Shabbat" wording in Peninei Halakha implies the second option. **[S]**
     - Chabad's daily Chitas Chumash-with-Rashi study uses Sunday = Rishon … Shabbat = Shevi'i (chayenu.org/explore-chayenu/chumash). That is daily Chumash study, a separate practice from Shnayim Mikra, but it is the best-known daily aliyah map. **[S]**
  2. **Whole parsha on Friday** (Arizal: morning; Shelah/Chabad: after midday).
- **The Arizal custom of no interruption**
  - Some do not speak at all during the reading, and restart if they did. Many poskim treat this as custom, not law. **[S]** (shulchanaruchharav.com/?p=1016; dinonline 2020/04/01)
  - One may answer Amen without restarting. **[S]** (shulchanaruchharav.com/?p=27118)
  - Do not stop in the middle of a verse of curses (e.g., Bechukotai) to answer Amen. **[S]**
  - Those strict about interruption should not study other commentaries in the middle. **[S]**

---

## 4. Special cases

### 4.1 Verses with no Targum: "Atarot v'Divon" (Bamidbar 32:3)
- **Rishonim**
  - Rashi: a pasuk with no Onkelos is read **three times in Hebrew**.
  - Tosafot: use another Targum (Yerushalmi / Yonatan).
  - Rishonim dispute whether three Hebrew readings are needed or two suffice.
  - Some are stringent to read Targum Yerushalmi.
  - **[S+]** (sheilot.com/…/view/5343; Tur/SA 285:1 as cited; rabbiavishafran.com/?p=4866)
- **Practical:** printed Chumashim already carry a rendering of these names in the Targum column. R. Avi Shafran notes that our Chumashim render all the names except the last, Be'on. **[S]** (sheilot.com 5343; rabbiavishafran.com) The exact printed Onkelos text was not checked. **[U]**
- One source says SA 285:1 itself rules "read three times; for Atarot v'Divon read Targum Yerushalmi". This may be the Shulchan Aruch HaRav rather than the Mechaber. **[U]**

### 4.2 Verses "read but not translated" (Reuven, Bereishit 35:22, etc.)
- Mishnah Megillah 4:10, "מעשה ראובן נקרא ולא מתרגם", concerns the **public** meturgeman in shul (out of respect for Reuven). **[S]** (he.wikisource Mishnah Megillah 4:10; yeshiva.org.il)
- Onkelos does translate 35:22 in printed editions. **[K]**
- **No source was found** applying this restriction to private Shnayim Mikra. **[U]** Default: read Onkelos for every verse, including 35:22, Birkat Kohanim and Ma'aseh HaEgel. Do **not** treat these as "no Targum" verses.

### 4.3 Using Rashi instead of Targum: verses with no Rashi
- **MB 285:5:** someone using Rashi as the Targum should read **three times** any pasuk on which Rashi does not comment. **[S]** (outorah.org/p/237343; dinonline)
- The source chain (Shaar HaTziyun, Knesset HaGedolah, Maharam Mintz) has been questioned:
  - The Aruch HaShulchan omits it.
  - Rashi often comments on only part of a pasuk.
  - The Lechem Chamudot (MA, MB 285:2) offers a lenient angle.
  - **[S]** (jewishlink.news, Aug 2026)

### 4.4 Ending with Mikra: repeating the final pasuk
- **Section by section:** many hold one should read the **last pasuk of the sedra a third time** after the Targum, so the reading ends with Mikra. Sources: Magen Avraham 285:1; Kaf HaChaim 285:3; Kitzur SA 72:11 (number as cited in the OU summary; not checked against the text). **[S]** (outorah.org Q&A)
- **Verse by verse:** Aruch HaShulchan 285:6 says to repeat the last pasuk in this method too. **[S]**
- A rarer practice reads the last pasuk twice (Chida, Moreh BeEtzba 131). **[S]**
- The reason given is to end with Scripture, as when the Targum used to be read aloud in shul. **[S]**
- **Chabad:** the Alter Rebbe's Shulchan Aruch rules to repeat it, but **Chabad custom is not to**. The Rebbe (Likkutei Sichot 24) calls it what "those who are stringent" do. **[S]** (shulchanaruchharav.com/?p=1016)

### 4.5 Haftarah
- **Rema (cited as 285:7):** reading the haftarah too is customary, not obligatory. Wikipedia reports an Ashkenazi custom of reading it with its Targum. **[S]** (en.wikipedia.org) The text of the Rema was not checked. **[U]**
- **Chabad:** the haftarah is read **once, in Hebrew**. When a special haftarah replaces the regular one, **both** are read. **[S]** (chayenu.org/explore-chayenu/haftarah)
- The Kitzur also mentions the haftarah custom. **[S]**

### 4.6 Double parshiyot
- "With the congregation" means following the congregation's reading schedule. **[S]** (koltorah.org) So in a combined week (e.g., Matot–Masei) one reads **both**. This is an inference; no explicit statement was found. **[U]**
- Chabad's Chitas schedule spreads both parshiyot across the week. **[S]** (chayenu.org)
- When the parsha is delayed (Yom Tov on Shabbat), the same parsha stays current for two weeks, sometimes three. **[S]** (chayenu.org)

### 4.7 Rashi or a translation in place of Onkelos
- **SA 285:2:** studying the parsha with Rashi counts like Targum. A yarei shamayim reads **both** Targum and Rashi. **[S+]**
- **Which is better if only one:**
  - Beit Yosef (following Rav Amram Gaon and Rav Natronai Gaon) prefers Targum, said to have been given at Sinai.
  - Maharshal prefers Rashi.
  - **[S]** (Wikipedia; yeshiva.org.il wiki)
- **Someone who doesn't understand Aramaic or Rashi's Hebrew:**
  - **MB 285:5** (per yeshiva.org.il): he may read a translation **in a language he understands**, provided it follows Rashi and Chazal. **[S]**
  - **A plain literal translation does not count.** Onkelos is also a commentary, not just a word-for-word rendering. OU Halacha Yomis cites MB (285:4). **[S]** (outorah.org/p/237343 and /p/173159)
  - Rav Moshe Feinstein: **Rashi in English is fine.** Dirshu MB 285, note 15. **[S]**
  - An elucidated translation that weaves in Chazal and Rashi (e.g., ArtScroll) is acceptable, though Rashi itself is preferred. **[S]** (outorah.org; dinonline 2016/10/30)
  - Dinonline (citing MB and Rav Moshe via Yagel Yaakov): read Rashi if you understand it; otherwise a reliable English rendering. **[S]**
  - One source attributes to Michtavei Chafetz Chaim, letter 18, that "nowadays" one should use Rashi rather than Targum. The wording is unclear and possibly misreported. **[U]**

### 4.8 Does hearing the Torah reading in shul count?
- **SA 285:5** (per OU) allows doing Shnayim Mikra along with the ba'al koreh. **MB 285:14:** read quietly **along with him, word for word**. Many do this. **[S]** (outorah.org/p/173835)
- **Listening only, without reading along:**
  - Magen Avraham 285:8 and Shaarei Teshuvah 285:6 (citing Radvaz): bedieved, careful listening to every word counts as **one** Mikra. **[S]**
  - The OU (following MB) is stricter: do not rely on listening alone. **[S]**
- **Doing it during the reading at all:** some say this is not proper. Peninei Halakha: better to read quietly with the reader and count that as one reading. **[S]** (ph.yhb.org.il)

### 4.9 Cantillation (ta'amim)
- If you know how to lein, read the **Mikra with trop**, but **not the Targum**. Reading without trop still fulfills the obligation. **[S]** (OU Q&A via search summary)

### 4.10 Shabbat morning, before davening
- Shabbat morning before the meal is a valid and even ideal window (SA 285:4). **[S+]**
- **No source was found** on reading specifically **before Shacharit**. **[U]**
- Background **[K/U]**: Torah study before Shacharit is generally allowed if it will not make you miss the zman or the minyan, and Birchot HaTorah must be said first. Peninei Halakha (cited above) assumes some people finish during the Torah reading itself.

### 4.11 Israel / diaspora weeks that diverge
- **Diaspora resident in Israel during a divergent week:** read **both** parshiyot.
  - The Israeli one, because that is the local congregation's reading.
  - The diaspora one, so it is not skipped this year.
  - **[S]** (shulchanaruchharav.com/?p=2997; yeshiva.co/midrash/49796)
  - Which to read first is left open. **[U]**
  - If he davens with a minyan of **bnei chutz la'aretz** reading the diaspora parsha, he reads only that one. **[S]**
  - After returning to the diaspora, he need not repeat the parsha the diaspora is now reading, which he already read in Israel. **[S]**
- **Israel to diaspora:** if the diaspora is now reading a parsha already read in Israel, he **need not repeat** its Shnayim Mikra, though he must hear the Torah reading again. **[S]**
- **Why the calendars diverge:** SA OC 428:4 sets which parshiyot are combined; misalignments can last more than three months. **[S]** (outorah.org/p/49153; jewishlink.news "out-of-sync")

---

## 5. Practical customs

- **Aloud.** The Mikra must be **spoken aloud**, not read with the eyes. For Targum/Rashi the authorities dispute it, but aloud is better, certainly for Targum. **[S]** (a dinonline Q&A from search; exact page not confirmed)
- **No interruption** (Arizal custom). See 3.2.
- **Attire.** The Arizal read on Friday morning still wearing tallit and tefillin. **[S]** (halachayomit.co.il)
- **From a Sefer Torah.** Possible, but then you cannot read the Targum after each verse. **[S]** (shulchanaruchharav.com)
- **Special prayer before or after: none found.** No source turned up for a Yehi Ratzon or other text before or after Shnayim Mikra. **[U]**
  - Background **[K]**: no special beracha is said; the morning Birchot HaTorah cover it.
  - Do not ship a "Shnayim Mikra prayer" without a sourced siddur text.
- **"Reading the pasuk Shema" and similar: nothing found** that is specific to Shnayim Mikra. **[U]**

---

## 6. Shabbat, Yom Tov and streak design

- **The ideal deadlines fall on Shabbat** (before the Shabbat meal; Mincha). Many users finish on Shabbat morning from a printed Chumash, when the app cannot be used. **[S+]**
- **Device use on Shabbat and Yom Tov** is prohibited by mainstream poskim. **[K]**
  - The app must never need interaction then.
  - Streaks must treat Shabbat and Yom Tov days as neutral.
  - Reading done offline on Shabbat must be loggable **afterward**.
- **Notifications.** No source on push notifications was checked. **[K/U]** Standard practice in observant-market apps is no pushes from shortly before candle lighting until after havdalah (local zmanim). The same applies to Yom Tov, including 2-day diaspora Yom Tov and 3-day Yom Tov–Shabbat chains.
  - A notification arriving on Shabbat is not the user's melacha, but it is disruptive and may tempt handling the device. Many users keep phones on for emergencies.
  - Chol HaMoed: device use is widely permitted. **[K]**
- **Weeks with no parsha (Yom Tov on Shabbat).** The parsha window spans two weeks. A weekly streak must not "miss" that week. **[S]** (outorah.org/p/81739; chayenu.org)
- **Other pause cases**
  - Tisha B'Av: general Torah study is restricted (OC 554). Don't nudge that day. **[K]**
  - Shiva: Torah study forbidden on weekdays, though Shnayim Mikra is allowed on Shabbat (YD 400:1). **[S]**
  - Illness: exempt, make up later (Kaf HaChaim 285:9). **[S]**
- **The natural streak unit is the parsha-week, not the day.** The halachic window runs from Shabbat Mincha (or Sunday) to the next Shabbat meal/Mincha, with bedieved make-up through Tuesday and annual make-up through Simchat Torah.

---

## 7. Open questions (not resolved because of access limits)

1. The exact text of SA 285:3–7 and MB 285:2, 5, 7, 8, 12, 14, 18 (verify numbering), and of Kitzur SA 72:11. Check them in print or on Sefaria.
2. "Until Wednesday": does it mean up to Tuesday nightfall (the common reading) or through all of Wednesday?
3. MB 285:18 (day of Hoshana Rabbah) vs. MB 669:4 (night of Simchat Torah) for Vezot HaBeracha.
4. The Yom Tov-on-Shabbat start window (OU "Twenty Questions Part 2", Q14).
5. Rav Ovadia Yosef / Yalkut Yosef on the preferred day and time, and Sephardic last-verse and haftarah practice. The Dailyhalacha.com search returned nothing on topic.
6. Whether any source restricts reading the Targum of "nikra ve-lo mitargem" verses privately.
7. Double-parsha practice: inferred but not explicitly sourced.
8. The text of the Rema on the haftarah, and whether the haftarah is read once, or twice plus Targum (Ashkenazi variants).
9. The Gra's own practice: aliyah-a-day or whole section at once.
10. Any customary prayer before or after Shnayim Mikra.

---

## 8. Product implications (concrete feature recommendations)

### 8.1 Calendar and parsha engine
- **Support both Israel and diaspora reading schedules**, including:
  - combined parshiyot;
  - Yom Tov-on-Shabbat "skip" weeks;
  - Vezot HaBeracha on Simchat Torah (Shemini Atzeret in Israel);
  - Bereishit opening only after the Simchat Torah reading.
- Use a proven library rather than hand-rolled rules, e.g., Hebcal's `@hebcal/core` / `@hebcal/leyning`, which encode SA OC 428 and the aliyah boundaries.
- **Parsha-week window object** with these timestamps:
  - `opensAt`: previous Shabbat Mincha per MB 285:7, or Sunday. A setting, since poskim differ.
  - `idealBy`: Shabbat-day meal (configurable time, default about chatzot).
  - `secondBy`: Shabbat Mincha.
  - `bedievedBy`: Tuesday nightfall.
  - `makeupBy`: end of Simchat Torah (diaspora) / Shemini Atzeret (Israel).
- **Make the parsha completion status a ladder, not a binary:**
  - Done lechatchila (before Shabbat meal)
  - Done (by Mincha)
  - Done bedieved (by Tuesday)
  - Made up (before Simchat Torah)
  - Lost
- **Make-up queue.** List missed parshiyot until Simchat Torah, always prioritize the current week's parsha, and show an annual "whole Torah" completion map.
- **Travel mode.** Detect a diaspora user in Israel (or the reverse) during misaligned weeks. Prompt them to read both parshiyot, with an override for "davening with a chutz la'aretz minyan". Never ask them to repeat a parsha already completed.

### 8.2 Reading modes and data model
- **Track every verse as three units: Mikra 1, Mikra 2, Targum.** That gives resumable sessions and honest progress.
- **Modes:**
  - **Verse by verse** (default; Arizal / Magen Avraham / MB).
  - **Section by section**, with breaks at **petucha/setuma** markers from Masoretic data. The app should never break mid-pasuk.
  - Optional **Mikra–Targum–Mikra** (Chavot Yair/Levush), labeled as a minority practice.
- **Final-verse repeat toggle.**
  - Default ON for section mode (MA, Kaf HaChaim, Kitzur).
  - ON for verse mode under an "Aruch HaShulchan" preset.
  - OFF under the Chabad preset.
  - Option to repeat twice (Chida).
- **Commentary engine**, one of:
  - Onkelos (default).
  - Rashi (Hebrew).
  - Rashi in translation (Rav Moshe).
  - Elucidated translation based on Chazal/Rashi.
  - "Both Targum and Rashi" (SA 285:2, yarei shamayim mode).
  - **Never count a plain literal translation as the Targum.** Show it only as a study aid.
- **Third-Hebrew-reading prompts:**
  - In Rashi mode, flag verses with no Rashi comment and prompt a third Hebrew reading (MB 285:5). Make it a setting, since the ruling is debated.
  - For any verse where the Onkelos dataset is missing or identical to the Hebrew (Bamidbar 32:3), offer a third Hebrew reading and/or Targum Yerushalmi.
  - Run a data-integrity check so that every verse has a Targum string.
- **Do not suppress the Targum** for 35:22, Birkat Kohanim, etc. That rule applies only to the public reading.
- **Haftarah.** Optional item (default ON for Ashkenaz/Chabad presets), read once in Hebrew. When a special haftarah displaces the regular one, offer both (Chabad).
- **Trop.** Display cantillation and offer audio for the Mikra only, never for the Targum.
- **Encourage reading aloud.** Copy should say "say it aloud". Completion is marked per verse by a deliberate tap; scrolling past is not enough. Audio playback is a learning aid and does not replace the user's own reading.

### 8.3 Schedules and presets
- **Presets** that set start time, daily plan, last-verse repeat, haftarah, and no-interruption mode:
  - "Mishnah Berurah"
  - "Arizal (Friday morning, uninterrupted)"
  - "Shelah/Chabad (Friday after midday, whole parsha)"
  - "Gra (aliyah a day)"
  - "Sephardi (Shulchan Aruch/Kaf HaChaim)"
  - "Custom"
  - Label each preset with its sources and a "consult your rav" note.
- **Aliyah-a-day plan**
  - Sunday through Friday cover aliyot 1–6.
  - The 7th aliyah (plus haftarah) goes on either **Friday (combined)** or **Shabbat morning before the meal**. The Shabbat option is logged after Shabbat.
  - Snap day boundaries to the nearest petucha/setuma or end of topic (Gra).
- **Friday plan.** Countdowns to chatzot (Chabad/Shelah) or a post-Shacharit reminder (Arizal), computed from local zmanim.
- **Optional uninterrupted-session mode** (Arizal). It records whether the session was continuous but never forces a restart; many poskim treat this as custom.

### 8.4 Shul reading integration
- On Shabbat the app is offline, so after Shabbat ask: "Did you read along quietly with the ba'al koreh?" A yes counts as **one Mikra** for the current week (MB 285:14).
- "Listened only" is a separate, explicitly **bedieved** option (Magen Avraham 285:8), off by default.

### 8.5 Shabbat and Yom Tov safety (streaks and notifications)
- **Hard rule: no push notifications, badges, sounds or background prompts** from N minutes (default 30) before local candle lighting until after local havdalah time. This applies to Shabbat and to all Yom Tov days, including 2nd-day diaspora Yom Tov and 3-day chains. It is computed from the device's location or the user's chosen city. Show the next blackout window in settings.
- **Streaks never break on Shabbat or Yom Tov.**
  - The primary streak is **weekly**: parsha completed by the chosen deadline.
  - Any daily streak counts only eligible weekdays (excluding Shabbat, Yom Tov, Tisha B'Av).
  - Skip weeks and combined weeks count as one parsha window, never as a miss.
- **Motzaei Shabbat / post-Yom Tov check-in** for reading done offline: "I finished from a printed Chumash", with when (Friday / Shabbat before the meal / before Mincha / after Mincha). It backdates the status ladder.
- **Life-event pauses** that freeze streaks and move missed parshiyot to the make-up queue: shiva, illness, Tisha B'Av, travel.
- **Erev Shabbat and Erev Yom Tov:** the last reminder should fire well before candle lighting, e.g., the Chabad/Shelah "after chatzot" nudge on Friday, with a "finish before the Shabbat meal tomorrow" fallback.
- Avoid any copy or game mechanic that implies the user should open the app on Shabbat to "keep" anything.

### 8.6 Audience and copy
- **No obligation-shaming copy.** Women are generally exempt, and their voluntary practice is meritorious. A "Chinuch mode" for children uses simpler plans, and a bar mitzvah boy's earlier progress carries over (Rav Yaakov Kamenetsky).
- **In-app "Why / Source" sheet** for each rule, citing the siman/se'if (Berakhot 8a–b; SA OC 285; MB 285; Kitzur 72), with a clear "customs vary; ask your rav" disclaimer.
- Have a qualified rav review the content before launch, given the open items in section 7.

---

## 9. Sources consulted (via search summaries; none fetched directly)

- Yeshiva.org.il wiki, "שניים מקרא ואחד תרגום": https://www.yeshiva.org.il/wiki/index.php/שניים_מקרא_ואחד_תרגום
- Yeshiva.org.il Beit Midrash 6696 (SA 285:4 times): https://www.yeshiva.org.il/midrash/6696
- Hidabroot Q&A (bedieved through Tuesday night): https://www.hidabroot.org/question/276789
- OU Torah / Halacha Yomis series on Shnayim Mikra:
  - https://outorah.org/p/81413 (Introduction)
  - https://outorah.org/p/81536 (When to learn)
  - https://www.outorah.org/p/173503 (Timing)
  - https://www.outorah.org/p/173583 (Weekly completion)
  - https://outorah.org/p/173224 (Manner of reading)
  - https://outorah.org/p/173835 (Reading along)
  - https://outorah.org/p/237343 (English translation)
  - https://www.outorah.org/p/173159 (Translated commentary)
  - https://outorah.org/p/72947 (Overview)
  - https://outorah.org/p/81738 (Twenty Questions Part 1)
  - https://outorah.org/p/81739 (Twenty Questions Part 2)
  - https://outorah.org/p/49153 (Israel/diaspora divergence)
- Dinonline:
  - https://dinonline.org/2019/10/22/time-for-shnayim-mikra-ve-echad-targum/
  - https://dinonline.org/2011/10/10/best-time-for-shanyim-mikra-of-vezos-haberachah/
  - https://dinonline.org/2011/10/08/shnayim-mikra-for-bereishis/
  - https://dinonline.org/2014/10/15/shayim-mikra-for-bereishis/
  - https://dinonline.org/2016/10/30/can-i-read-artscrolls-english-translation-instead-of-targum-when-doing-shnayim-mikroh/
  - https://dinonline.org/2020/04/01/interrupting-in-the-middle-of-shnayim-mikrah/
- Peninei Halakha (R. Eliezer Melamed), Shabbat 1:5:10: https://ph.yhb.org.il/en/01-05-10/
- Shulchan Aruch HaRav (R. Yaakov Goldstein; Chabad):
  - https://shulchanaruchharav.com/?p=1012 (obligation, women, children)
  - https://shulchanaruchharav.com/?p=1015 (when)
  - https://shulchanaruchharav.com/?p=1016 (how)
  - https://shulchanaruchharav.com/?p=18294 (reading)
  - https://shulchanaruchharav.com/?p=27118 (Amen)
  - https://shulchanaruchharav.com/?p=2997 (Israel travel)
  - https://shulchanaruchharav.com/?p=27915 (Hoshana Rabbah)
- Shulchan Aruch HaRav OC 285 in English (not fetched): https://www.chabad.org/3447074
- Halacha Yomit (Arizal, Friday): https://halachayomit.co.il/en/pdf/6376.pdf
- Yeshiva.co, Israel/diaspora travel: https://www.yeshiva.co/midrash/49796
- Yeshivat Har Etzion halacha shiurim:
  - https://www.etzion.org.il/sites/default/files/19shtayim_mikra.doc
  - https://www.etzion.org.il/sites/default/files/20shtayim_mikra2.doc
- Kol Torah (R. Chaim Jachter; Ezra Frazer):
  - https://www.koltorah.org/halachah/shnayim-mikrah-vechad-targum-basics-by-rabbi-chaim-jachternbsp
  - https://www.koltorah.org/articles/shnayim-mikra-vechad-targum-by-ezra-frazer
- Sheilot.com:
  - https://sheilot.com/en/answers/shabbos/shabbos-torah-reading/shnayim-mikra-ve-echad-targum/view/5343/ (verse without translation)
  - https://sheilot.com/en/guides/shnayim-mikra-veechad-targum/view/17799/
  - https://sheilot.com/en/articles/shabbos/view/6327/
- JewishLink (third reading when Rashi is silent): https://jewishlink.news/reading-a-pasuk-a-third-time-when-rashi-does-not-comment-a-response-to-tabc-alumnus-eyal-kinderlehrer/
- Rabbi Avi Shafran, "Thrice Upon a Word": https://www.rabbiavishafran.com/?p=4866
- Chayenu:
  - https://chayenu.org/explore-chayenu/haftarah
  - https://chayenu.org/explore-chayenu/chumash
- Sefaria source sheet, Berakhot 8a–b: https://www.sefaria.org/sheets/20854
- Wikipedia: https://en.wikipedia.org/wiki/Shnayim_mikra_ve-echad_targum
- Mishnah Megillah 4:10 (Wikisource): https://he.wikisource.org/wiki/משנה_מגילה_ד_י
