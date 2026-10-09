# Report A: Community and forum design for a weekly Torah-portion app (Flutter + Supabase)

Research date: 2026-10-09. Companion file: `forum_schema.sql` in this folder. It holds the full schema, RLS policies, triggers and RPCs, and I ran it against PostgreSQL 16 (see §7, "Validation").

## How this was researched, and what was checked

**Read directly from primary sources:**
- Discourse's own source code (`config/site_settings.yml` and `config/locales/server.en.yml` on GitHub), for its defaults and community guidelines.
- Apple's App Review Guidelines, its "Offering account deletion in your app" page and its age-ratings page (developer.apple.com could be reached).
- Supabase's documentation sources from the `supabase/supabase` GitHub repo, plus the `supabase/splinter` lint docs.
- W3C ARIA Practices (feed pattern), GitHub's `relative-time-element`, and the Flutter docs source.
- pub.dev package metadata, and the README and package.json of `@hebcal/core`.

**Not checked:** The shared WebSearch budget ran out early in this session, and the sandbox proxy blocks most other hosts: support.google.com/play.google.com, supabase.com, meta.discourse.org, stackoverflow.com, 929.org.il and Wikipedia. Statements that come from prior knowledge are marked **[unverified]** and should be checked before you rely on them.

---

## 1. Design principles: Discourse, Stack Exchange and Reddit, and weekly per-portion threads

### 1.1 Discourse (source: Discourse's own defaults and copy)

**"Civilized discourse."** The default guidelines text (`guidelines_topic` in `server.en.yml`) opens with *"This is a Civilized Place for Public Discussion. Please treat this discussion forum with the same respect you would a public park."* Other key norms in that text:
- *"criticize ideas, not people"*; avoid name-calling, ad hominem attacks, responding to tone, and knee-jerk contradiction;
- *"When you see bad behavior, don't reply … Just flag it. If enough flags accrue, action will be taken, either automatically or by moderator intervention"*;
- moderators should be *"community facilitators, not just janitors or police."*

This tone fits a beit-midrash-style community well (see §6).

**Trust levels are earned by reading, not just posting.** These are the default promotion requirements from `site_settings.yml`:

| Level | Default requirements |
|---|---|
| TL0 → TL1 | entered 5 topics, read 30 posts, **10 minutes of reading time** |
| TL1 → TL2 | entered 20 topics, read 100 posts, 60 minutes of reading, visited on 15 days, gave 1 like and received 1, replied to 3 topics |
| TL2 → TL3 | over a rolling 100 days: visited 50 days, replied to 10 topics, viewed 25% of topics and 25% of posts (with caps), at most 5 flagged posts, gave 30 likes and received 20. TL3 can be lost again. |
| TL4 | assigned manually |

What the levels unlock by default:
- **Flagging:** TL1 (`flag_post_allowed_groups`).
- **Personal messages:** TL1.
- **Editing wiki posts:** TL1.
- **Making one's own posts wikis:** TL3.
- **Editing all topic titles:** group 13 = TL3.
- **Editing all posts:** TL4.

**A sandbox for new users (TL0).** Default rate limits and caps:
- `rate_limit_new_user_create_post` = **30 s** between posts, against 5 s for everyone else.
- `max_replies_in_first_day` = 10 and `max_topics_in_first_day` = 3.
- `newuser_max_replies_per_topic` = 3 *"until someone replies to them."*
- `newuser_max_links` = 2, `newuser_max_mentions_per_post` = 2, `newuser_max_attachments` = 0.

Defaults that apply to everyone:
- `unique_posts_mins` = 5 (no identical post within 5 minutes);
- `min_post_length` = 20, `min_topic_title_length` = 15, `body_min_entropy` = 7;
- `max_topics_per_day` = 20, `max_flags_per_day` = 20, `max_edits_per_day` = 30.

**Flags work as weighted community moderation:**
- `hide_post_sensitivity` = 6 (*"The likelihood that a flagged post will be hidden"*). After a post is hidden this way, `cooldown_minutes_after_hiding_posts` = 10 must pass before its author can edit it.
- `num_users_to_silence_new_user` = 3: if spam flags come from that many different users, *"hide all their posts and prevent future posting."*
- `num_flaggers_to_close_topic` = 5: that many unique flaggers automatically pause a topic.
- `high_trust_flaggers_auto_hide_posts`: a spam flag from a TL3+ user hides a new user's post immediately.
- `cooldown_hours_until_reflag` = 24.

**Spam heuristics:**
- `min_first_post_typing_time` = 3000 ms. Posts typed faster go to the approval queue, and the author can be auto-silenced.
- `max_new_accounts_per_registration_ip` = 3.
- `newuser_spam_host_threshold` = 3 (repeated links to the same host).
- `approve_suspect_users`.

**Layout.** Discourse uses one chronological stream per topic, with "in reply to" links instead of deep nesting. This is a deliberate choice in Discourse's design (Jeff Atwood's "Civilized Discourse Construction Kit" essay, https://blog.codinghorror.com/civilized-discourse-construction-kit/) **[page not reachable from here]**. It also helps accessibility (§5).

**Lessons for this app:**
1. Gate the more powerful actions behind trust earned by *reading*. A study app can measure reading of the parasha itself.
2. Copy Discourse's new-user limits nearly as-is.
3. Have flags hide content automatically pending review, so moderators don't need to be online, which matters on Shabbat.
4. Use a flat stream per thread.

### 1.2 Stack Exchange and Reddit **[unverified; sources blocked]**

- **Stack Exchange** grants privileges by reputation:
  - 1: create posts; 15: vote up and flag; 50: comment everywhere; 125: vote down;
  - 2,000: edit others' posts; 3,000: cast close votes; 10,000: access moderator tools (https://stackoverflow.com/help/privileges).
  - Lessons: separate *Q&A* (one best answer) from *discussion*; let the community curate; expect canonical questions and duplicates.
  - **Mi Yodeya** (judaism.stackexchange.com) is the relevant precedent. It treats requests for personal halachic rulings as off-topic and tells users to consult their rabbi. Copy that norm.
- **Reddit** gives each community (subreddit) its own rules and volunteer moderators. AutoModerator holds back posts by account age or karma, and recurring "weekly discussion" megathreads are a common pattern. Lessons:
  - Deep comment trees and up/down voting can bury minority or beginner voices and encourage pile-ons. In a Torah-study setting, prefer positive-only reactions (for example "todah" / "insightful").
  - AutoModerator-style rules map neatly onto Postgres triggers (§3).

### 1.3 Per-portion weekly threads (the 929 model)

- **What 929 is [unverified]:** *929 – Tanakh B'Yachad* (launched in Israel in December 2014) has the public read one chapter of Tanakh a day, Sunday to Thursday, through all 929 chapters. Each chapter page combines short essays from diverse contributors (rabbis, academics, artists, writers) with community discussion, and the cycle restarts.
- **Lessons:**
  - Anchor discussion to a *text unit* and a *time cycle*.
  - Seed each unit with curated starter content so the thread is never empty.
  - Keep earlier cycles' threads as a browsable archive.
- **Model for this app:**
  - Create **one pinned "weekly" thread per parasha per Hebrew year** automatically, for example with `pg_cron` or an Edge Function every Saturday night after havdalah (the schema enforces a unique index on `(parasha_id, hebrew_year)` where `kind='weekly'`).
  - Allow **verse-anchored threads** (`verse_ref`) and optional sub-threads per aliyah.
  - Show "this week" according to the user's **Israel/Diaspora** setting (`profiles.in_israel`). The two schedules diverge for some weeks after a festival falls on Shabbat, so **key threads by parasha, never by date**.
  - Combined parashot (for example Vayakhel–Pekudei) need either a join table `thread_parashot(thread_id, parasha_id)` or a second id column.
- **Schedule data:**
  - `@hebcal/core` v6.14.1, **GPL-2.0-or-later**, JS, suitable for an Edge Function. Its README lists `getSedra()` and candle-lighting/havdalah times "approximated based on location" (https://github.com/hebcal/hebcal-es6).
  - `kosher_dart` v2.0.20, **LGPL-2.1**, a Dart zmanim library (https://pub.dev/packages/kosher_dart, https://github.com/yakir8/kosher_dart).

---

## 2. App store requirements for user-generated content

### 2.1 Apple

**Guideline 1.2, User-Generated Content (verbatim, fetched today):** *"Apps with user-generated content or social networking services must include:*
- *A method for filtering objectionable material from being posted to the app*
- *A mechanism to report offensive content and timely responses to concerns*
- *The ability to block abusive users from the service*
- *Published contact information so users can easily reach you"*

It also says: *"It is your responsibility to remove content that violates this guideline, your terms of service, or your community standards … Egregious or repeated behavior is grounds for immediate removal of your app."*

How the proposed design meets each requirement:

| 1.2 requirement | Implementation in the proposed design |
|---|---|
| Filtering | `private.banned_terms` blocklist with reject/hold actions; the trigger runs on insert and edit; Hebrew-aware normalization; new-user link limits; community flags auto-hide posts |
| Report + timely response | Report button on every post, thread and profile → `reports` table → moderator queue (`status`, `resolved_at`); three distinct reports auto-hide the post |
| Block abusive users | `user_blocks`; the RLS policy on `posts` hides a blocked author's posts from the blocker server-side, which also covers Realtime |
| Published contact info | Support email or URL inside the app (Settings → Contact) **and** in the App Store listing. Guideline 1.5 adds that the app and its Support URL must offer *"an easy way to contact you"* |

**Other guidelines that apply to a religious-content community:**
- **1.1.1** bans *"Defamatory, discriminatory, or mean-spirited content, including references or commentary about religion …"*.
- **1.1.5** bans *"Inflammatory religious commentary or inaccurate or misleading quotations of religious texts."* Your moderation policy needs a "misinformation / misquoted source" report reason.

**Practitioner note [unverified]:** App Review rejection messages for 1.2 commonly also ask that:
- users agree to terms (an EULA) stating there is *no tolerance* for objectionable content or abusive users, **before** they can post;
- the developer acts on reports **within 24 hours** by removing the content and ejecting the offending user.

Build both in: `accept_terms()` stamps `profiles.accepted_terms_at`, and posting is refused until it is set.

**Guideline 5.1.1(v) and account deletion (fetched today):** *"If your app supports account creation, you must also offer account deletion within the app."* Apple's support page (https://developer.apple.com/support/offering-account-deletion-in-your-app/) adds:
- Deletion must be easy to find, typically in account settings. *"only offering to temporarily deactivate or disable an account is insufficient."*
- A web flow is allowed only through a *direct link* to the deletion page. Phone calls, emails or support flows are not acceptable outside highly regulated industries.
- Tell the user how long deletion takes and confirm when it is done. Deletion must be available to everyone in every region, including guest accounts.
- **UGC:** *"People expect that all data associated with their account will be deleted … This includes user-generated content that's shared with others, such as … text posts."* Keep data only if the law requires it, and say so.
- If you add Sign in with Apple later, revoke tokens through its REST API.

### 2.2 Google Play **[unverified; page blocked]**

**User Generated Content policy** (https://support.google.com/googleplay/android-developer/answer/9876937) requires apps with UGC to:
1. Require users to accept terms of use or a user policy **before** creating or uploading UGC.
2. Define objectionable content and behavior, consistent with Play policy, and prohibit it in those terms.
3. Run robust, effective and ongoing moderation.
4. Provide an **in-app system for reporting** objectionable UGC and users, and act on reports.
5. Provide an **in-app way to block** users and content.
6. Make sure in-app monetization does not encourage objectionable behavior.

Apps whose main purpose is objectionable UGC are removed.

**Account deletion policy** (https://support.google.com/googleplay/android-developer/answer/13327111):
- If users can create an account in the app, they must be able to request deletion **inside the app** and through a **web link** that works without reinstalling the app. That link is declared in the Data safety form.
- Deleting the account must delete the associated data, except data with a legitimate retention reason, which must be disclosed. Deactivation alone does not count.

### 2.3 Age ratings

**Apple** (https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions, fetched today):
- The categories are 4+, 9+, 13+, 16+ and 18+. Values differ by OS version: there are separate tables for iOS 26 and the other 26 releases.
- Definitions: *User-Generated Content*, *"broad distribution of content created by users"*; *Messaging and Chat*, which *"may include … public posting."*
- In the general table, UGC and messaging alone do not raise the rating above 4+. The separate *Social Media* capability is what moves an app to 13+. Regional tables are stricter (Brazil, Korea).
- Expect reviewers to scrutinize moderation more closely when the rating is low.

**Google Play** uses the IARC questionnaire, which asks whether users can interact or share content. An "Users Interact" notice is shown **[unverified]**.

**Recommendation:**
- Require a declared age of 13 or older to *post*, and let younger users read only. Bar/bat-mitzvah-age users are a likely audience, and this avoids COPPA's under-13 consent rules for collecting personal data **[legal check advised]**.
- Answer the store questionnaires truthfully: "UGC: yes, moderated; messaging: public posts only; no private messages", if you don't build private messages. Leaving out private messaging lowers both risk and moderation load.

---

## 3. Moderation tooling (implemented in `forum_schema.sql`)

| Tool | Design |
|---|---|
| **Report queue** | `reports(reporter_id, post_id / thread_id / reported_user_id, reason enum, details, status open/actioned/dismissed, resolved_by, resolved_at, resolution_note)`, with a unique constraint `(reporter_id, post_id)` and an index on `(status, created_at)`. Reasons tailored to this community: `spam`, `lashon_hara`, `disrespect`, `misinformation`, `proselytizing`, `off_topic`, `other`. The reporter is stamped server-side. **Three distinct open reports auto-hide the post** (Discourse-style) until a moderator reviews it. |
| **Soft delete and hide** | `posts.hidden_at`/`hidden_reason` mean held for review (filter or flags). `deleted_at`/`deleted_by`/`delete_reason` make a tombstone, so thread structure and "in reply to" links survive. There are no DELETE policies; users delete through the `soft_delete_post()` RPC, and moderator deletions are logged. |
| **Edit history** | `post_revisions`: a trigger copies the old body on every edit, and only moderators can read it. Edits re-run the content filter. |
| **Lock, pin, slow mode** | `threads.is_locked`, `is_pinned`, `slow_mode_seconds`. Posting into a locked thread is refused for non-moderators. Users cannot write pin or lock, because of column privileges. |
| **Roles** | `user_roles(user_id, role)` plus `private.is_moderator()` (security definer). Alternative: Supabase's documented **custom access token hook**, which puts a `user_role` claim in the JWT (`public.custom_access_token_hook`, with an `authorize()` helper; Supabase RBAC guide). Trade-off: a JWT claim stays valid until the token expires, so revoking a role is delayed, while a table lookup is immediate. **Recommendation:** enforce with the table and use the claim only for UI hints. |
| **Silence and ban** | `profiles.silenced_until`, `banned_at`, checked by `private.assert_can_post()`. Supabase Auth's own ban *"only blocks sign-in for its duration and does not revoke existing sessions"* (Supabase "Managing user data"), so the DB-level check is still needed. |
| **Word and regex blocklist** | `private.banned_terms(pattern, action reject/hold)`, matched case-insensitively against `private.he_plain(text)` (NFD → strip nikud and ta'amim → fold final letters). **The same folding must be applied to the patterns.** In testing, the pattern `שקרן` did not match the folded text `שקרנ` until the fix was made. Keep the table in an unexposed schema so spammers cannot read it. |
| **Rate limits (Postgres triggers)** | All in `private.posts_before_insert()`:<br>• Discourse defaults: 30 s between posts for TL0 and 5 s for others; TL0 limited to 10 posts and 3 threads per 24 h; no duplicate body within 5 minutes; at most 2 links in a TL0 post.<br>• Per-thread slow mode.<br>• A per-user `pg_advisory_xact_lock` makes these checks race-free.<br>Errors are raised as `P0001` with stable codes (`rate_limited`, `slow_mode`, `duplicate_post`, `content_rejected`, `thread_locked`, `terms_not_accepted`, `silenced_until:…`, `shabbat_closed`) so the Flutter client can show localized messages. |
| **Audit log** | `moderation_log(actor_id, action, target_type, target_id, reason, created_at)`, written by the `moderate()` RPC and readable only by moderators. |
| **Anti-spam basics** | • Email OTP sign-in, with Supabase Auth's per-IP token-bucket limits (§4.6).<br>• Enable CAPTCHA on sign-up (Supabase Auth supports hCaptcha/Turnstile) **[unverified here]**.<br>• **Configure custom SMTP**: the built-in email provider allows only **2 emails per hour** (Supabase `config.ts`).<br>• TL0 link limits; duplicate detection; minimum lengths.<br>• Optionally hold every first post from TL0 users for review (set `hidden_at` on insert while `trust_level = 0`).<br>• A nightly job promotes trust levels: for example, TL1 after 24 h, 3 posts that were not hidden and some reading time; TL2 after 15 visit days. |

---

## 4. Supabase best practices (checked against the docs source)

### 4.1 RLS policy patterns for forums

- **Public read:** `for select to anon, authenticated using (deleted_at is null and hidden_at is null and …)`.
- **Authenticated insert as self:** `for insert to authenticated with check (author_id = (select auth.uid()))`. The BEFORE INSERT trigger also *overwrites* `author_id` with `auth.uid()`, and column privileges do not even let the client send `author_id` (tested: *permission denied*).
- **Update own:** `using (author_id = (select auth.uid()) and deleted_at is null) with check (author_id = (select auth.uid()))`. The docs explain that `using` checks the existing row and `with check` checks the resulting row.
- **Moderators:** a *separate* permissive policy, `to authenticated using ((select private.is_moderator()))`. Permissive policies are OR-ed. Keeping the moderator clause out of the `anon` policy means anon never needs EXECUTE on the helper.
- **RLS filters rows, not columns.** Use column grants (`grant update (body) on public.posts to authenticated`) so users cannot flip `is_pinned`, `hidden_at`, `trust_level` and so on. Do privileged changes through RPCs.
- **Never let a policy use `user_metadata`;** it is user-editable. Use tables or `app_metadata` **[general Supabase guidance; unverified here]**.
- **Views:** views bypass RLS by default. On Postgres 15+ create them `with (security_invoker = true)`.

### 4.2 Performance

These points come from the Supabase "Row Level Security" guide and the splinter lint `0003_auth_rls_initplan`:
- Wrap helpers as `(select auth.uid())`. This *"causes an `initPlan` … to 'cache' the results per-statement, rather than calling the function on each row."* I confirmed it with EXPLAIN: `InitPlan 1 (returns $0)` plus an Index Cond on the PK (§7).
- Add `TO authenticated` so a policy doesn't run for anon at all.
- *"Add an index on every column your policies filter on."* A column only counts as indexed if it **comes first** in a btree index; a composite PK `(team_id, user_id)` does not index `user_id`. The schema therefore adds `user_blocks(blocked_id)`, `posts(author_id, created_at desc)`, `reports(reporter_id)` and similar indexes.
- Prefer `col in (select … where user_id = (select auth.uid()))`, with no join back to the row's table, and wrap membership lookups in security definer functions.

### 4.3 Security definer pitfalls

From Supabase "Database functions" and splinter `0011_function_search_path_mutable`:
- *"Prefer `security invoker`, which is also the default. When you use `security definer`, you must set the `search_path`."* Use `set search_path = ''` and schema-qualify every name.
- **Never put a definer function in an exposed schema** unless it is meant to be an RPC. It *"is callable over the Data API with the creator's privileges"* and *"can return rows the caller isn't allowed to read."* Functions owned by `postgres` bypass RLS.
- *"Any role can call it by default, including `anon`."* `revoke execute … from public, anon`, then `grant execute … to authenticated`.
- **Check ownership inside the function body**, since the grant alone does not limit rows. Every RPC in `forum_schema.sql` checks `auth.uid()` or `private.is_moderator()`.
- A definer function can break RLS recursion when one policy's subquery triggers another policy. This only works if the owner has `bypassrls`, which `postgres` does on Supabase.

### 4.4 Realtime with RLS

From Supabase "Postgres Changes" and "Realtime Authorization":
- Postgres Changes **checks RLS for every subscriber**: *"a single change to a table with 100 subscribed users [means] 100 authorization checks."* Changes are processed on a single thread. Above about 3,000 concurrent subscribers, use **Broadcast** (`realtime.broadcast_changes()` from a trigger, on *private* channels authorized by RLS policies on `realtime.messages`).
- *"RLS policies are not applied to `DELETE` statements."* You can only filter DELETE events with `replica identity full`. **This is another reason to use soft delete**, which arrives as an UPDATE and so goes through RLS.
- **Consequence (my inference):** when a post becomes hidden, subscribers lose read access to the *new* row, so they won't receive that UPDATE and may keep showing the stale content. Send a small `post_hidden {id}` broadcast on the thread topic, or have clients re-fetch when the screen resumes.
- Keep policies cheap, and use column selection and filters (`thread_id=eq.123`) so each client receives only what it needs.

### 4.5 Email OTP vs magic link

From Supabase "Passwordless email" and "Email templates":
- **Both use the same call.** `signInWithOtp` *"sends a Magic Link by default."* To send a **six-digit code**, edit the "Magic Link" template to include `{{ .Token }}`. Then call `verifyOtp` (Dart: `supabase.auth.verifyOTP(email: …, token: …, type: OtpType.email)`).
- **Why codes are easier across Android, iOS, web and Windows:**
  - Magic links need redirect URLs and deep-link setup on every platform. supabase_flutter supports deep links on *"Android, iOS, Web, macOS and Windows"*, but *"Setting up deep links in Windows has few more steps"* (Supabase "Native mobile deep linking"; uses the `app_links` package, v7.2.2).
  - Links break when the email is opened on a different device from the app.
  - **Email security scanners pre-fetch links:** *"the `{{ .ConfirmationURL }}` sent will be consumed instantly which leads to a 'Token has expired or is invalid' error … Use an email OTP instead."*
- **Defaults:**
  - one OTP request per user every **60 s**, and each OTP is valid for **1 hour**. You can shorten this; anything over one day is *"strongly discouraged"*;
  - sign-in and sign-up endpoints are limited per IP, with bursts up to 30;
  - the built-in SMTP sends **2 emails/hour**, so configure custom SMTP before launch.
- Set `shouldCreateUser: false` on a dedicated "sign in" screen if you want sign-up to be an explicit, separate step that requires accepting the terms.

### 4.6 Deleting a user

From Supabase "Managing user data":
- **Officially documented path:** call `auth.admin.deleteUser()` from an Edge Function using the secret (service-role) key, after verifying the caller's JWT. Deleting the `auth.users` row cascades to `auth.sessions` and invalidates refresh tokens.
- **Gotchas:**
  - *"You cannot delete a user if they are the owner of any objects in Supabase Storage"*, so delete the user's files first.
  - **Access tokens already issued stay valid until `exp`.** Keep the JWT expiry short, sign out on the client, and for sensitive operations check the `session_id` claim against `auth.sessions`.
  - Use `on delete cascade` from `profiles.id` to `auth.users`.
- **SQL alternative** (`public.delete_my_account()` in the companion file): a security definer RPC that deletes the caller's posts, then deletes threads they started that are now empty, then `delete from auth.users where id = auth.uid()`. This is a widely used community pattern on hosted Supabase **[unverified here]**; it worked in the local test. **Post content is deleted** to meet Apple's UGC expectation. Optionally keep moderation evidence by copying the reported text into `reports` at report time, and disclose that retention.

### 4.7 Rate limiting

- Supabase Auth uses token buckets per IP (most with capacity 30) and returns **429** when they are empty. You can tune them in Dashboard → Auth → Rate Limits or through the Management API.
- For data writes, use the Postgres triggers in §3. For expensive RPCs or Edge Functions, use a counter table or an external store.

### 4.8 Linting

Run the Database Advisors (splinter):
- `0003` auth_rls_initplan;
- `0010` security_definer_view;
- `0011` function_search_path_mutable.

Run them in CI against migrations, for example with `supabase db lint`.

---

## 5. Accessibility of forums

- **Flat vs threaded:** Prefer a **flat chronological stream with one level of "in reply to"**, which shows a quoted snippet and links to the parent, as Discourse does.
  - Deep trees are hard to navigate with a screen reader (depth has to be announced, and collapsing state is confusing). Indentation also wastes width on phones and at large text sizes.
  - If you add nesting, cap it at one or two levels and announce it ("Reply to Batya, level 2").
- **Structure (Flutter):**
  - Mark the thread title `Semantics(header: true)`, and section labels (Pinned, This week's parasha, Older) as headers too.
  - Treat each post as one semantic container (`MergeSemantics`) whose label reads, in order: *author, role badge, absolute time, edited status, content*.
  - Make actions (Reply, Thanks, Report, Block) separate focusable buttons with explicit labels.
  - On Flutter web, these become ARIA roles and labels.
- **Feeds and infinite scroll:** The W3C feed pattern warns that loading content on scroll *"can cause usability and interoperability difficulties for users of assistive technologies"*. It defines a contract built on `article` elements and keyboard keys (Page Down/Up between articles).
  - In Flutter, also provide an explicit **"Load more"** button, keep focus on the current post, and never insert Realtime posts above the reading position.
  - Instead, show a "3 new posts" pill the user activates, and announce it once.
- **Relative vs absolute time:**
  - Show relative time for recent posts ("3 hours ago") and absolute dates after a cut-off. GitHub's `relative-time` element switches after `threshold = P30D` by default, and its markup always carries an ISO datetime. For a discussion forum, 7 days is a good cut-off.
  - **Always** put the absolute date and time in the semantics label and on long-press or tooltip, localized for Hebrew and English. Optionally add the Hebrew date (for example "ה׳ תשרי").
  - Don't auto-update relative-time text, because screen readers re-announce changing text.
- **Text and layout:**
  - Respect the OS text size (Flutter does by default; test at the largest setting).
  - Meet WCAG contrast (Flutter has an Accessibility Guideline API for tests) and use 48 dp touch targets.
  - Set text direction **per post** by its first strong character, since posts mix Hebrew and English. Isolate inline runs of the other direction.
- **Hebrew scripture inside posts:** Screen readers handle cantillation marks badly. Give quoted verses a `semanticsLabel` built from the ta'amim-stripped text (see `typography.md` §3).

---

## 6. Content considerations for a Torah-study community

**Draft community norms** (classical sources cited by reference; wording is yours to adapt):
- **Machloket l'shem shamayim** (Pirkei Avot 5:17): disagreement is welcome when it is "for the sake of heaven". Argue about the text, not the person. This matches Discourse's *"criticize ideas, not people"*.
- **No lashon hara, rechilut or motzi shem ra** (Leviticus 19:16; the Chofetz Chaim's laws of speech). Don't post negative things about identifiable people, including rabbis, public figures and community members, even if they are true. Don't name-and-shame congregations or organizations.
- **Kavod habriyot and kavod haTorah:** dignified language and no mockery of other communities' practice. Decide and state the community's scope (pluralistic or denomination-specific) up front.
- **No halachic rulings (psak):** share sources and views, but *"for practical questions, ask your rabbi."* Show this disclaimer on the composer when a post is tagged "Halacha".
- **Cite sources** (verse, Talmud page, commentator), and mark personal interpretation as such. This also addresses Apple 1.1.5 on misquoted religious texts.
- **No proselytizing or missionary content**, and no political campaigning.
- **Gentle correction** (Lev. 19:17, *tochacha*; Avot 1:6, judge favorably): moderators first send a private note, then hide the content, then silence, then ban. Log each step.
- **The Divine Name:** you may ask posters to write ה׳ / Hashem / G-d rather than the Tetragrammaton. Make this a community norm or an optional auto-substitution in user posts only, never in scripture text.

**Report reasons that match these norms:** lashon hara / personal attack; disrespect; misinformation / misquoted source; proselytizing; spam; off-topic; other.

### Should the server block posting on Shabbat?

| | Pros | Cons |
|---|---|---|
| **Block (server-enforced)** | • Matches the expectations of an observant audience and the app's credibility.<br>• Avoids *facilitating* chillul Shabbat by Jewish users (lifnei iver / mesayea questions).<br>• Moderators get Shabbat off: no queue builds up and no push notifications go out. | • **Shabbat is local.** It starts and ends at different UTC times worldwide, so a single global window is either too short for some users or about 50+ hours long. A per-user window needs the user's location.<br>• Non-Jewish and non-observant users are blocked.<br>• Yom Tov is 1 day in Israel but 2 in the Diaspora, and there are edge cases (polar latitudes, date line).<br>• Bugs in zmanim data become outages.<br>• Blocking only *posting* doesn't settle whether *reading* or *serving* is acceptable. |
| **Don't block** | • Simple and inclusive. | • The community may object.<br>• Moderation may be needed on Shabbat. |

**Halachic note:** Whether an automatically running site may operate on Shabbat, and whether to block users, is a question for the community's posek **[not legal or halachic advice]**. Many observant-run businesses disable *transactions* on Shabbat while leaving content readable **[unverified examples]**.

**Recommended approach (configurable):**
1. In the client, add a **"Shabbat mode"** keyed to the user's chosen location or timezone. From candle lighting to havdalah it shows a notice, hides the composer, and pauses push notifications.
2. On the server, run an **optional** check that is off by default and can be switched on per community: `private.settings.block_posting_on_shabbat`, plus `private.shabbat_windows(region, starts_at, ends_at)`, which a yearly job fills from hebcal or kosher_dart. `assert_can_post()` refuses posts with `shabbat_closed` while the user's region (default: Jerusalem) is inside a window. I tested this.
3. Skip all moderation SLAs and notification sends during the user's Shabbat, and include Yom Tov.
4. Explain the policy in the community guidelines.

---

## 7. Validation of `forum_schema.sql`

Run locally on PostgreSQL 16.15 with a stub of Supabase's `anon`/`authenticated` roles, `auth.users` and `auth.uid()`. All behaved as intended:

1. A TL0 user posts successfully. An immediate second post fails with `rate_limited`.
2. A spoofed `author_id` is refused: *permission denied* from the column grant. The trigger would overwrite it anyway.
3. A blocklisted term is rejected. A "hold" term (Hebrew with nikud, pattern written with a final letter) is auto-hidden. This only worked after both sides were folded.
4. Anon sees only visible posts.
5. Authors see their own held posts, and moderators see everything.
6. A user who blocks an author stops seeing that author's posts.
7. Users cannot change `hidden_at` (column privilege). A body edit stamps `edited_at` and writes a revision.
8. A non-moderator calling `moderate()` gets `forbidden`. After a moderator locks a thread, posting into it fails with `thread_locked`.
9. A spoofed `reporter_id` is refused. Three distinct reports auto-hide the post.
10. Anon cannot execute `delete_my_account()`. For an authenticated user it removes the auth user, the profile and the posts, and reports cascade.
11. The Shabbat window gate returns `shabbat_closed`.
12. EXPLAIN shows `InitPlan` for `(select auth.uid())` and an index condition on the PK.

**Not tested:** Supabase's real `auth` schema permissions (whether `delete from auth.users` works through the hosted `postgres` role), Realtime, and PostgREST behavior. With column grants, PostgREST `select=*` errors on `profiles`, so clients must list the columns they want.

---

## Concrete recommendations

### Product decisions
1. **Structure:**
   - Categories, with a pinned **weekly thread per parasha per Hebrew year** created automatically after havdalah.
   - Optional verse-anchored threads and per-aliyah sub-topics, plus an archive by year.
   - "This week" follows the Israel/Diaspora setting.
2. **Discussion format:** a flat stream with one-level "in reply to". Positive-only reactions ("todah", "insightful") and no downvotes. **No private messages at launch.**
3. **Sign-in:** email **OTP code** through Supabase, with custom SMTP, CAPTCHA on sign-up, and a 13+ age gate for posting. Users must accept the guidelines/EULA (`accept_terms()`) before their first post.
4. **Trust levels:**
   - TL0 limits: 30 s between posts, 10 posts and 3 threads per day, at most 2 links per post. Optionally hold every first post for review.
   - TL1 (flagging, links) after about 24 h, 3 posts that were not hidden and some reading time.
   - TL3 trusted users can hide spam immediately.
5. **Moderation:**
   - Report button on every post, thread and profile.
   - Three distinct reports auto-hide a post. Target review **within 24 h**.
   - Moderator tools: hide/restore, soft delete, lock/pin, slow mode, silence (7 days by default), ban, and an audit log.
   - In-app contact page plus a support URL in the store listings.
6. **Account deletion:** in Settings, with a confirmation step, through an Edge Function (`auth.admin.deleteUser`) or the provided RPC. It deletes Storage objects, posts, profile and auth user, and signs the user out. Publish the web deletion link for Google Play.
7. **Shabbat:** a client "Shabbat mode" (composer hidden, notifications paused), plus the optional server window check, off until the community's rabbinic guidance decides.

### Proposed schema

Full DDL is in `forum_schema.sql`.

| Table | Key columns |
|---|---|
| `profiles` | `id` (PK → auth.users, cascade), `display_name` (unique, case-insensitive), `bio`, `locale`, `trust_level` 0–4, `accepted_terms_at`, `silenced_until`, `banned_at`, `in_israel`, `shabbat_region`, `created_at` |
| `user_roles` | `user_id`, `role` (`moderator`/`admin`), `granted_at`; PK `(user_id, role)` |
| `categories` | `id`, `slug`, `name_en`, `name_he`, `sort_order`, `is_locked`, `min_trust_to_create_thread` |
| `parashot` | `id` 1–54, `name_en`, `name_he`, `book`, `start_ref`, `end_ref` (+ optional `thread_parashot` for combined portions) |
| `threads` | `id`, `category_id`, `parasha_id`, `hebrew_year`, `verse_ref`, `kind` (discussion/weekly/question/announcement), `title`, `author_id`, `is_pinned`, `is_locked`, `slow_mode_seconds`, `post_count`, `last_post_at`, `created_at`, `deleted_at/by/reason`; unique weekly `(parasha_id, hebrew_year)` |
| `posts` | `id`, `thread_id`, `author_id`, `reply_to_post_id`, `body` (2–10,000 chars), `body_plain` (generated search key), `created_at`, `edited_at`, `hidden_at/reason`, `deleted_at/by/reason` |
| `post_revisions` | `post_id`, `body`, `edited_by`, `edited_at` |
| `reactions` | `post_id`, `user_id`, `kind` (todah/insightful); PK all three |
| `reports` | `reporter_id`, `post_id` / `thread_id` / `reported_user_id`, `reason` enum, `details`, `status`, `resolved_by/at`, `resolution_note` |
| `user_blocks` | `blocker_id`, `blocked_id`, `created_at`; PK + index on `blocked_id` |
| `moderation_log` | `actor_id`, `action`, `target_type`, `target_id`, `reason`, `created_at` |
| `private.banned_terms` | `pattern` (regex, matched against folded text), `action` reject/hold, `note` |
| `private.shabbat_windows` | `region`, `starts_at`, `ends_at` |
| `private.settings` | `key`, `value` (for example `block_posting_on_shabbat`) |

Indexes:
- `posts(thread_id, created_at) where deleted_at is null`
- `posts(author_id, created_at desc)`
- `threads(category_id, is_pinned desc, last_post_at desc) where deleted_at is null`
- `reports(status, created_at)`
- `user_blocks(blocked_id)`
- an index on every column that RLS filters on.

### Policy list

RLS is enabled on every public table. Every helper is called as `(select …)`.

| Table | Policies |
|---|---|
| `profiles` | SELECT for anon and authenticated (columns limited by grant: `id, display_name, bio, trust_level, created_at`). UPDATE own row (`id = (select auth.uid())`), columns limited to `display_name, bio, locale, in_israel, shabbat_region`. INSERT only through the `auth.users` trigger. |
| `user_roles` | SELECT own rows. Writes through the service role or an admin RPC only. |
| `categories`, `parashot` | SELECT for all. Writes through the service role or admin only. |
| `threads` | SELECT `deleted_at is null` (anon, authenticated). Moderators SELECT all. INSERT as self (only `category_id, parasha_id, verse_ref, title, kind` granted; the trigger enforces terms, ban, trust, category lock and daily limits; only moderators may create `weekly`/`announcement`). UPDATE own `title` while not locked or deleted. Pin, lock and delete through `moderate()`. |
| `posts` | SELECT visible (`deleted_at is null and hidden_at is null and author not blocked by me`). Authors SELECT their own hidden posts. Moderators SELECT all. INSERT as self (only `thread_id, reply_to_post_id, body` granted; the trigger enforces everything in §3). UPDATE own `body` while not deleted (with revision and re-filter). No DELETE policy; use `soft_delete_post()`. |
| `post_revisions`, `moderation_log` | SELECT for moderators only. Writes come only from triggers or RPCs. |
| `reactions` | SELECT all. INSERT and DELETE own. |
| `reports` | INSERT as self (reporter stamped by trigger; `reporter_id` not grantable). SELECT own rows plus moderators. Resolution through `moderate()`. |
| `user_blocks` | SELECT, INSERT and DELETE where `blocker_id = (select auth.uid())`. Anon keeps SELECT so the `posts` policy's subquery works; RLS returns no rows to anon. |
| `private.*` | Not exposed through the Data API. No grants to anon or authenticated, except EXECUTE on `is_moderator()` and `he_plain()` for authenticated. |

**RPCs** (security definer, `search_path = ''`, EXECUTE revoked from `public`/`anon` and granted to `authenticated`, caller checked in the body):
- `accept_terms()`
- `soft_delete_post(id, reason)`
- `moderate(action, target_id, reason, until)`
- `delete_my_account()`

**Realtime:**
- Add `posts` and `threads` to `supabase_realtime`, and subscribe with a `thread_id=eq.X` filter.
- Rely on soft delete, which goes through RLS as an UPDATE.
- Broadcast `post_hidden` events on a private thread topic.
- Switch to `realtime.broadcast_changes` if concurrency grows past a few thousand subscribers.

---

## Sources

**Discourse:**
- Default settings: https://github.com/discourse/discourse/blob/main/config/site_settings.yml
- Guidelines text and setting descriptions: https://github.com/discourse/discourse/blob/main/config/locales/server.en.yml

**Apple:**
- App Review Guidelines (1.1.1, 1.1.5, 1.2, 1.5, 5.1.1(v)): https://developer.apple.com/app-store/review/guidelines/
- Account deletion: https://developer.apple.com/support/offering-account-deletion-in-your-app/
- Age ratings: https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions

**Google Play [unverified, blocked]:**
- UGC policy: https://support.google.com/googleplay/android-developer/answer/9876937
- Account deletion: https://support.google.com/googleplay/android-developer/answer/13327111

**Supabase docs source** (https://github.com/supabase/supabase/tree/master/apps/docs/content/guides):
- `database/postgres/row-level-security.mdx` and `row-level-security-performance.mdx`
- `database/functions.mdx`
- `realtime/postgres-changes.mdx`, `realtime/authorization.mdx` and `realtime/subscribing-to-database-changes.mdx`
- `auth/auth-email-passwordless.mdx`, `auth/auth-email-templates.mdx`, `auth/rate-limits.mdx` and `_partials/auth_rate_limits.mdx`
- `auth/managing-user-data.mdx`, `auth/native-mobile-deep-linking.mdx` and `auth/auth-hooks/custom-access-token-hook.mdx`
- `api/custom-claims-and-role-based-access-control-rbac.mdx`
- `packages/shared-data/config.ts` (OTP and email default values)

**Supabase splinter lints:** https://github.com/supabase/splinter/tree/main/docs (0003, 0010, 0011)

**Accessibility:**
- W3C ARIA APG feed pattern: https://github.com/w3c/aria-practices/blob/main/content/patterns/feed/feed-pattern.html
- GitHub `relative-time-element`: https://github.com/github/relative-time-element
- Flutter accessibility docs: https://github.com/flutter/website/blob/main/sites/docs/src/content/ui/accessibility/ui-design-and-styling.md

**Calendar and package data:**
- `@hebcal/core`: https://github.com/hebcal/hebcal-es6 (README and package.json)
- pub.dev API: `kosher_dart`, `supabase_flutter` (2.18.0), `app_links` (7.2.2)

**[Unverified, blocked]:**
- Stack Exchange privileges: https://stackoverflow.com/help/privileges
- 929: https://www.929.org.il/
- Coding Horror essay: https://blog.codinghorror.com/civilized-discourse-construction-kit/
