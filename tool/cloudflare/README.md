# The site's Worker and its logs

`shnayimmikrah.org` is served by the Cloudflare Worker `shnayimmikrah-org`. Every request passes through `src/worker.js` first: it answers the requests that aren't the site's, serves the accounts and the app's community API (below) and the app's files for the rest, and writes the logs described here. The rules are in `src/rules.js`, and `test/worker.test.mjs` checks them; the accounts are checked by `test/accounts.test.mjs`, and the community by `test/community.test.mjs`. All run in CI (`node --test tool/cloudflare/test/worker.test.mjs tool/cloudflare/test/accounts.test.mjs tool/cloudflare/test/community.test.mjs`).

## What is logged

Logs go to the D1 database **`shnayimmikrah-logs`**, in two tables (`schema.sql`).

**`visits`**: one row per page a visitor opened on the site, with the time, the path (without its query), the status, the country and network number (`asn`) Cloudflare gives, the browser's User-Agent, the referring site's host (never its path or query), the first language the browser asks for, and the visitor's address as a keyed hash (below). Files the page loads (scripts, fonts, images) are not visits, so one visit is one row. The accounts' pages (`/account/...`) are not visits either: each would write a row, for little use.

**`security_events`**: one row per request that is refused or looks like an attack, with the kind and what it's about:

| Kind | When |
|---|---|
| `bad_host` | the request came to another address (such as the `workers.dev` one): redirected to the site |
| `bad_method` | a method the site doesn't use (anything but GET, HEAD, OPTIONS): 405 |
| `too_long` | a path over 512 or a query over 2048 characters: 414 |
| `scanner_path` | a path only scanners ask for (`/.env`, `/.git`, WordPress, `.php` and backup files): 404 |
| `traversal` | an encoded slash or dots in the path: 404 |
| `scanner_agent` | a User-Agent of a known scanning tool (sqlmap, nikto, nmap…): 403 |
| `no_user_agent` | no User-Agent at all: noted, and served |
| `threat_score` | Cloudflare's threat score of 20 or more, when the plan gives one |

The site's own requests never make a security event, and a refused request is not a visit.

## What is not logged

- **Addresses.** The visitor's address is never stored. It becomes a keyed hash (HMAC-SHA256, with a secret salt, `IP_SALT`, set as a Worker secret and not in the repository) of the UTC day and the address. The same visitor has the same hash within a day and a different one the next day, so a day's visitors can be counted and told apart, but a visitor can't be followed from one day to the next. To keep a longer link, change the code; that's a decision to make with the privacy policy in view.
- **Query strings and referrer paths**, which can carry searches and addresses.
- **Request bodies, cookies and headers** other than those named above.
- **Workers request logs** are turned off, so the full URLs of requests are not kept by Cloudflare's Workers logs.

Cloudflare keeps its own security events for the zone for its own period; they aren't copied here.

## How long

Both tables keep **365 days** (`RETENTION_DAYS` in `wrangler.toml`). A daily job, at 03:17 UTC, removes the rows older than that.

## Accounts

An account is optional, and the app doesn't need one. A visitor signs up at `/account/sign-up` with an email address and a password, confirms the address with a six-digit code sent by email, and then has a session in a cookie. The pages are plain HTML forms that the Worker serves (`src/account_pages.js`), in English and Hebrew. The logic is in `src/accounts.js`, the rows in `src/account_db.js`, the hashes in `src/account_crypto.js`, and the email in `src/mail.js`.

**What is stored**, in `schema.sql` (`users`, `sessions`, `codes`, `reset_tokens`, `rate_limits`, `roles`):

- `users`: the address in lower case; the password as PBKDF2-SHA256, with its own count, salt and hash; when the address was confirmed; when the account was made.
- `sessions`: the SHA-256 of each session's token. The cookie holds the token itself.
- `codes`: the keyed hash (HMAC-SHA256, with `ACCOUNTS_KEY`) of each sign-up code, its expiry and its wrong tries.
- `reset_tokens`: the SHA-256 of each password reset link, its expiry, and whether it has been used.
- `rate_limits`: a keyed hash of an address or an email, with the window it counts in.
- `roles`: the site's staff, by email address, as `admin` (every permission) or `moderator`. A role counts only once its address is a confirmed account, and the account page shows it. Rows are added by hand, never from the site, so the addresses are not in the repo: `INSERT INTO roles (email, role, granted_at) VALUES ('name@example.com', 'admin', 0)`.

Never stored: a password, a code, a token or a link as it was sent, or a visitor's address.

**How long**: a session 30 days; a code 15 minutes; a reset link an hour; an address never confirmed 7 days; a verified account until its owner deletes it; a rate-limit row until its window ends. The daily job (03:17 UTC) removes what has passed its time.

**Endpoints**: form posts, answered with redirects.

| Path | What it does |
|---|---|
| `GET`, `POST /account/sign-up` | creates the account and emails a code (Turnstile) |
| `GET`, `POST /account/verify` | confirms the code; a right code signs in |
| `POST /account/verify/resend` | emails a new code, which replaces the old one |
| `GET`, `POST /account/sign-in` | signs in (Turnstile); an unconfirmed account gets a new code |
| `POST /account/sign-out` | ends this session |
| `GET`, `POST /account/reset` | emails a reset link, if the address has a confirmed account (Turnstile) |
| `GET`, `POST /account/reset/complete` | sets the new password, once per link, and signs out every session (Turnstile) |
| `GET /account` | the account, when signed in |
| `POST /account/delete` | deletes the account, after the password is entered |

**Protections**: Turnstile on sign-up, sign-in and both reset forms. Limits per email and per address, counted in windows: sign-up 5 an hour per email and 20 an hour per address; sign-in 10 failed tries per 15 minutes per email and 30 per address, so a sign-in that works counts nothing; the code, resend and reset limits are in `src/accounts.js`. A try refused by a limit writes nothing. A code locks after 5 wrong tries. A POST must come from the site's own origin. The cookie is `__Host-`, HttpOnly, Secure and SameSite=Lax; the pages are `no-store` and send a referrer only to the site itself. (Not `no-referrer`: under it a browser sends `Origin: null` with a form, so a post is also let through when the browser's `Sec-Fetch-Site` says `same-origin`.) The answers to sign-up, sign-in and reset do not show whether an address has an account.

**Writes and CPU**: a page view writes a `visits` row, except on the account pages. A sign-in that works writes one session row; a failed one writes its counters. PBKDF2 runs at 100,000 iterations, the most Workers accept, and the count is stored with each hash: a sign-in with a lower count raises it. Measured in Node, 100,000 iterations take about 50 ms of CPU, while the Workers Free plan allows 10 ms per request. Check the account's Workers plan before the accounts go live.

**Set up once**, in addition to the database and salt below: the secrets `ACCOUNTS_KEY` (`openssl rand -hex 32`), `RESEND_API_KEY` (from Resend) and `TURNSTILE_SECRET_KEY` (from the Turnstile widget), set with `npx wrangler@4 secret put NAME --config wrangler.toml`; and the variables in `wrangler.toml`, `TURNSTILE_SITE_KEY` (the widget's public site key) and `ACCOUNTS_EMAIL_FROM` (the sender, on a domain verified in Resend). The accounts' tables are added by applying `schema.sql` again, which is safe to repeat.

**An account made in the app** (by code, [Community](#community)) has no password (`pw_alg` `none`): it can't sign in on the site's form until a reset gives it one, and its account page deletes it without asking for one. A code confirming an address for the first time drops any password set before it was confirmed, as whoever set it never proved the address theirs.

**Not here**: a password change while signed in (only a reset changes it).

## Community

The app's community, its sign-in and the reading-progress backup run here too, as a JSON API under `/api/` (`src/api.js`), on the same accounts and the same D1 database. The app uses it wherever its build has the site's address (`WEB_URL`; `lib/features/community/data/worker_forum_repository.dart`). The rules are in `src/community.js` and the rows in `src/community_db.js`; they mirror the forum's Supabase migrations (`supabase/migrations`), where triggers kept them, so the app behaves the same on either.

**Signing in**: the app asks for a code (`POST /api/auth/code`), which makes the account the first time, without a password, and emails it; the code (`POST /api/auth/verify`) signs in and confirms the address. The answer holds the session's token, which the app sends as a bearer token, and sets the site's session cookie, which the web app, on the site's own address, sends instead. A request with the cookie alone that changes anything must come from the site itself, as the account forms must. A session in use is kept going: past half its 30 days, it runs for 30 days again.

**What is stored**, in `schema.sql`:

- `profiles`: the member's display name (`user_` and hex until they pick one, unique whatever the case), trust level, when they accepted the guidelines, and any ban or silence.
- `forums`, `parashot`: the forums and the 54 parashot, which `schema.sql` fills.
- `threads`, `posts`, `post_revisions`: what members post, and a post's earlier wording when it is edited. A deleted post is kept as a tombstone that no one sees.
- `todot`: the thanks given to a post, one per member.
- `reports`, `user_blocks`, `moderation_log`: reports, blocks, and what staff did.
- `user_progress`: the backup the app sends, as JSON, up to 900 KB.

**The rules**, as on Supabase:

- Anyone may read. To post, a member must be signed in, have accepted the guidelines, and be neither banned nor silenced.
- A new member (trust level 0) waits 30 seconds between posts (others 5), posts up to 10 times and starts up to 3 threads a day, and puts at most 2 links in a post. The same post twice within 5 minutes is refused. A post has 2 to 10,000 characters, a title 5 to 150.
- A reader doesn't see the posts of a member they blocked. Three members reporting a post hide it from all but its author and staff, until staff look.
- Only staff start threads in a locked forum (Announcements) or post in a locked thread.
- Staff are the addresses in `roles` ([Accounts](#accounts)): an `admin` can do everything; a `moderator` can hide, restore and delete posts, lock, pin and delete threads, silence, ban and unban members, set their trust and settle reports. Only an admin names or removes a moderator (`grant_moderator`, `revoke_moderator`), and only an admin acts on staff. Every action is logged.
- The weekly thread of a parasha is opened on first use, named from its names, for the Hebrew years about now only.
- Deleting the account, in the app or on the site, removes the member's posts and thanks, the threads they started that no one else posted in, their reports, blocks, profile and backup. Threads others posted in stay, without their author.

**Endpoints** (JSON; an error is `{"error": code}` with the code the app shows a message for):

| Path | What it does |
|---|---|
| `POST /api/auth/code`, `POST /api/auth/verify` | emails a sign-in code; checks it and signs in |
| `POST /api/auth/sign-out` | ends this session |
| `GET`, `DELETE /api/me` | the account; deletes it with everything posted |
| `GET`, `PUT /api/profile`, `POST /api/profile/guidelines` | the member's profile; a new display name; accepts the guidelines |
| `GET /api/forums`, `GET /api/forum-stats` | the forums; their thread counts and last post |
| `GET`, `POST /api/threads` | a page of threads (`forum`, `parsha`, `after`, `limit`); a new thread with its first post |
| `GET /api/threads/:id`, `GET`, `POST /api/threads/:id/posts` | a thread; a page of its posts (`before`, `limit`); a reply |
| `POST /api/weekly` | the weekly thread of a parasha and year, opened on first use |
| `PATCH`, `DELETE /api/posts/:id`, `PUT`, `DELETE /api/posts/:id/todah` | edits or deletes a post; gives or takes back thanks |
| `POST`, `GET /api/reports` | reports a post or thread; the open reports (staff) |
| `GET /api/blocks`, `PUT`, `DELETE /api/blocks/:id` | the members blocked; blocks or unblocks one |
| `POST /api/moderate` | a moderation action (staff) |
| `GET`, `PUT /api/progress` | the backup |

A page's cursor (`after`, `before`) is the last row's time in milliseconds and its id, `1761000000000:42`. The API is not logged as visits.

**Not ported from Supabase**: the word filter (`private.banned_terms`, empty there) and closing the forum on Shabbat (`block_posting_on_shabbat`, off there); a thread's slow mode, which nothing set.

## Reading the logs

Until the admin panel exists, query the database from the terminal, or in the Cloudflare dashboard (*Storage & databases → D1 → shnayimmikrah-logs → Console*):

```sql
-- Page views per day, last 30 days
SELECT date(ts/1000, 'unixepoch') AS day, count(*) AS views, count(DISTINCT ip) AS visitors
FROM visits WHERE ts > (strftime('%s','now') - 30*86400) * 1000 GROUP BY day ORDER BY day;

-- Security events by kind, last 7 days
SELECT kind, count(*) FROM security_events
WHERE ts > (strftime('%s','now') - 7*86400) * 1000 GROUP BY kind ORDER BY 2 DESC;

-- The paths that scanners asked for
SELECT path, count(*) FROM security_events WHERE kind = 'scanner_path' GROUP BY path ORDER BY 2 DESC LIMIT 50;
```

From the terminal: `npx wrangler@4 d1 execute shnayimmikrah-logs --remote --command "SELECT count(*) FROM visits"` (with `CLOUDFLARE_API_TOKEN` set, and the token able to use D1).

## Setting it up, and deploying

Done once: the database (`wrangler d1 create shnayimmikrah-logs`, or in the dashboard), its tables (`wrangler d1 execute shnayimmikrah-logs --remote --file schema.sql`), and the salt: `openssl rand -hex 32 | npx wrangler@4 secret put IP_SALT --config wrangler.toml`. The `database_id` in `wrangler.toml` is the database's id. The accounts' secrets and variables are listed under Accounts. Applying `schema.sql` again adds any table a change brings (the community's, say) and brings the forums and parashot up to date; it is safe to repeat.

Deploying the site and the Worker together, from a built site (`flutter build web` first, or the folder of a CI build):

```sh
tool/cloudflare/deploy.sh build/web
```

It needs `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`, and a token with Workers Scripts: Edit and D1: Edit. Changing the salt makes every visitor's hash new from then on.

## Before this is live for visitors to rely on

The privacy policy (`assets/legal/legal.json`) has sections on the community, on the accounts and on the visit log: what they hold, that addresses are hashed, and for how long. Its Hebrew needs a native speaker's review first. Not checked from the repo, and to check in the dashboards: the Resend sending domain and its verification, the Turnstile widget and its hostnames, and the Workers plan's CPU limit for PBKDF2.
