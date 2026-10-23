-- The site's log, in the D1 database `shnayimmikrah-logs` (tool/cloudflare/README.md).
-- Applied once, and again only when this file adds a table or an index: every
-- statement is IF NOT EXISTS.

-- One row per page a visitor opened on shnayimmikrah.org (not per file it loads).
CREATE TABLE IF NOT EXISTS visits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts INTEGER NOT NULL,          -- Unix time in milliseconds, UTC
  ip TEXT,                      -- keyed hash of the address, new each UTC day; the address is never stored
  path TEXT NOT NULL,           -- the page's path, without its query
  status INTEGER NOT NULL,
  method TEXT NOT NULL,
  country TEXT,                 -- Cloudflare's country code, such as IL
  asn INTEGER,                  -- the network's number, such as the visitor's provider
  ua TEXT,                      -- the browser's User-Agent, cut to 200 characters
  referer_host TEXT,            -- the referring site's host only
  lang TEXT,                    -- the browser's first preferred language, such as he-IL
  threat_score INTEGER          -- Cloudflare's threat score, when it gives one
);
CREATE INDEX IF NOT EXISTS visits_ts ON visits (ts);

-- One row per security event: a request refused, a suspicious request, or a
-- score over the threshold. The site's own requests never make one.
CREATE TABLE IF NOT EXISTS security_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts INTEGER NOT NULL,
  kind TEXT NOT NULL,           -- bad_host, bad_method, too_long, scanner_path, traversal, scanner_agent, no_user_agent, threat_score
  detail TEXT,                  -- what the kind is about, when it's about something (the host, the method, the score)
  ip TEXT,
  path TEXT,
  method TEXT,
  status INTEGER,               -- the status the request got
  ua TEXT,
  country TEXT,
  asn INTEGER
);
CREATE INDEX IF NOT EXISTS security_events_ts ON security_events (ts);
CREATE INDEX IF NOT EXISTS security_events_kind ON security_events (kind, ts);

-- The accounts (tool/cloudflare/README.md, Accounts). Only hashes are kept:
-- a session, a reset link and a code are stored as hashes, never as sent.

-- One row per account. The address is the account's; the password is kept as
-- PBKDF2-SHA256 with its own count and salt, so the count can be raised later.
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,   -- lower case
  pw_alg TEXT NOT NULL,         -- pbkdf2-sha256
  pw_iter INTEGER NOT NULL,     -- the PBKDF2 iteration count of this hash
  pw_salt TEXT NOT NULL,        -- base64url, 16 random bytes
  pw_hash TEXT NOT NULL,        -- base64url, 32 bytes
  email_verified_at INTEGER,    -- Unix time in milliseconds; NULL until the code is confirmed
  created_at INTEGER NOT NULL
);

-- One row per signed-in browser. The cookie holds the token; this holds its SHA-256.
CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_user ON sessions (user_id);
CREATE INDEX IF NOT EXISTS sessions_expires ON sessions (expires_at);

-- A one-time code sent by email, as a keyed hash. It locks after a few wrong tries.
CREATE TABLE IF NOT EXISTS codes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  purpose TEXT NOT NULL,        -- verify
  code_hash TEXT NOT NULL,      -- HMAC-SHA256 of the code, with ACCOUNTS_KEY
  expires_at INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS codes_user ON codes (user_id, purpose);
CREATE INDEX IF NOT EXISTS codes_expires ON codes (expires_at);

-- A password reset link, as its SHA-256. It works once, and only within its hour.
CREATE TABLE IF NOT EXISTS reset_tokens (
  token_hash TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL,
  used_at INTEGER,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS reset_tokens_user ON reset_tokens (user_id);
CREATE INDEX IF NOT EXISTS reset_tokens_expires ON reset_tokens (expires_at);

-- One counter per limit, per key (a keyed hash of an address or email) and window.
CREATE TABLE IF NOT EXISTS rate_limits (
  key TEXT PRIMARY KEY,
  count INTEGER NOT NULL,
  expires_at INTEGER NOT NULL   -- the end of its window; the daily clean-up removes it after
);
CREATE INDEX IF NOT EXISTS rate_limits_expires ON rate_limits (expires_at);

-- The site's staff, by address, so a role can be given before the account is
-- made. admin can do everything, moderator the community's moderation. Rows
-- are added by hand (README, Accounts), never from the site, and the
-- addresses live only here, not in the repo.
CREATE TABLE IF NOT EXISTS roles (
  email TEXT PRIMARY KEY,       -- lower case
  role TEXT NOT NULL CHECK (role IN ('admin', 'moderator')),
  granted_at INTEGER NOT NULL
);

-- The community: the app's forums (tool/cloudflare/README.md, Community),
-- served as JSON by src/api.js. The rules the app relies on (who may post,
-- the limits, blocking, hiding, moderation) are kept in src/community.js.
-- Times are Unix milliseconds; a user is a row of users.

-- One per member, made the first time the account reaches the community.
-- The name is "user_" and hex until its owner picks one; name_key is the
-- name in lower case, so that two names differing only in case clash.
CREATE TABLE IF NOT EXISTS profiles (
  user_id INTEGER PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,   -- 2 to 40 characters
  name_key TEXT NOT NULL UNIQUE,
  trust_level INTEGER NOT NULL DEFAULT 0,  -- 0 for a new member, up to 4
  accepted_terms_at INTEGER,    -- set before the member may post
  silenced_until INTEGER,
  banned_at INTEGER,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS forums (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name_en TEXT NOT NULL,
  name_he TEXT NOT NULL,
  description_en TEXT NOT NULL DEFAULT '',
  description_he TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  locked INTEGER NOT NULL DEFAULT 0   -- only staff start threads in it
);

CREATE TABLE IF NOT EXISTS parashot (
  id INTEGER PRIMARY KEY,       -- 1 to 54
  name_en TEXT NOT NULL,
  name_he TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS threads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  forum_id INTEGER NOT NULL REFERENCES forums (id),
  parsha_id INTEGER REFERENCES parashot (id),
  hebrew_year INTEGER,          -- the weekly thread's year
  kind TEXT NOT NULL DEFAULT 'discussion',  -- discussion, weekly, question, announcement
  title TEXT NOT NULL,
  author_id INTEGER REFERENCES users (id) ON DELETE SET NULL,  -- NULL for a weekly thread
  pinned INTEGER NOT NULL DEFAULT 0,
  locked INTEGER NOT NULL DEFAULT 0,
  post_count INTEGER NOT NULL DEFAULT 0,  -- the posts not deleted
  last_post_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  deleted_at INTEGER,
  deleted_by INTEGER,
  delete_reason TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS threads_one_weekly ON threads (parsha_id, hebrew_year)
  WHERE kind = 'weekly' AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS threads_listing ON threads (forum_id, pinned, last_post_at DESC, id DESC)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS threads_author ON threads (author_id, created_at);

CREATE TABLE IF NOT EXISTS posts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  thread_id INTEGER NOT NULL REFERENCES threads (id) ON DELETE CASCADE,
  author_id INTEGER REFERENCES users (id) ON DELETE SET NULL,
  reply_to_id INTEGER REFERENCES posts (id) ON DELETE SET NULL,
  body TEXT NOT NULL,           -- 2 to 10,000 characters
  created_at INTEGER NOT NULL,
  edited_at INTEGER,
  hidden_at INTEGER,            -- hidden pending review: by reports, or by staff
  hidden_reason TEXT,
  deleted_at INTEGER,           -- deleted by its author or by staff; kept, as a tombstone
  deleted_by INTEGER,
  delete_reason TEXT
);
CREATE INDEX IF NOT EXISTS posts_thread ON posts (thread_id, created_at DESC, id DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS posts_author ON posts (author_id, created_at);
CREATE INDEX IF NOT EXISTS posts_reply_to ON posts (reply_to_id);

-- A post's earlier wording, kept when it is edited.
CREATE TABLE IF NOT EXISTS post_revisions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id INTEGER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  edited_by INTEGER,
  edited_at INTEGER NOT NULL
);

-- "Todah", a member's thanks for a post: one per member and post.
CREATE TABLE IF NOT EXISTS todot (
  post_id INTEGER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (post_id, user_id)
);
CREATE INDEX IF NOT EXISTS todot_user ON todot (user_id);

-- Three members reporting a post hide it until staff look.
CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reporter_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  post_id INTEGER REFERENCES posts (id) ON DELETE CASCADE,
  thread_id INTEGER REFERENCES threads (id) ON DELETE CASCADE,
  reason TEXT NOT NULL,         -- spam, lashon_hara, disrespect, misinformation, off_topic, other
  details TEXT,                 -- up to 1,000 characters
  status TEXT NOT NULL DEFAULT 'open',  -- open, actioned, dismissed
  created_at INTEGER NOT NULL,
  resolved_by INTEGER,
  resolved_at INTEGER
);
CREATE UNIQUE INDEX IF NOT EXISTS reports_one_per_reporter_post ON reports (reporter_id, post_id) WHERE post_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS reports_queue ON reports (status, created_at);

-- A member no longer sees what a member they blocked posts.
CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  blocked_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (blocker_id, blocked_id)
);

-- What staff did, and to what.
CREATE TABLE IF NOT EXISTS moderation_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor_id INTEGER,
  action TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  reason TEXT,
  created_at INTEGER NOT NULL
);

-- The app's backup of a member's reading progress, as the app sends it (JSON).
CREATE TABLE IF NOT EXISTS user_progress (
  user_id INTEGER PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  data TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

-- The forums and the parashot (the names as assets/data/parshiyot.json has
-- them). Applying this file again brings them up to date.
INSERT INTO forums (id, slug, name_en, name_he, description_en, description_he, sort_order, locked) VALUES
  (1, 'parsha', 'Parshat HaShavua', 'פרשת השבוע', 'A discussion thread for every week’s parsha.', 'שרשור דיון לכל פרשת שבוע.', 1, 0),
  (2, 'questions', 'Questions & answers', 'שאלות ותשובות', 'Ask about a verse, a Targum or a Rashi.', 'שאלות על פסוק, תרגום או רש״י.', 2, 0),
  (3, 'divrei-torah', 'Divrei Torah', 'דברי תורה', 'Share an insight on the parsha.', 'שיתוף חידוש על הפרשה.', 3, 0),
  (4, 'chavruta', 'Chavruta & encouragement', 'חברותא ועידוד', 'Find a learning partner and keep each other going.', 'מציאת חברותא ועידוד הדדי.', 4, 0),
  (5, 'feedback', 'App feedback', 'משוב על האפליקציה', 'Ideas, bugs and accessibility feedback.', 'רעיונות, תקלות ומשוב על נגישות.', 5, 0),
  (6, 'announcements', 'Announcements', 'הודעות', 'News from the maintainers.', 'חדשות מצוות האפליקציה.', 6, 1)
ON CONFLICT (id) DO UPDATE SET slug = excluded.slug, name_en = excluded.name_en, name_he = excluded.name_he,
  description_en = excluded.description_en, description_he = excluded.description_he,
  sort_order = excluded.sort_order, locked = excluded.locked;

INSERT INTO parashot (id, name_en, name_he) VALUES
  (1, 'Bereshit', 'בראשית'), (2, 'Noach', 'נח'), (3, 'Lech Lecha', 'לך־לך'), (4, 'Vayera', 'וירא'),
  (5, 'Chayei Sarah', 'חיי שרה'), (6, 'Toldot', 'תולדות'), (7, 'Vayetze', 'ויצא'), (8, 'Vayishlach', 'וישלח'),
  (9, 'Vayeshev', 'וישב'), (10, 'Miketz', 'מקץ'), (11, 'Vayigash', 'ויגש'), (12, 'Vayechi', 'ויחי'),
  (13, 'Shemot', 'שמות'), (14, 'Va''era', 'וארא'), (15, 'Bo', 'בא'), (16, 'Beshalach', 'בשלח'),
  (17, 'Yitro', 'יתרו'), (18, 'Mishpatim', 'משפטים'), (19, 'Terumah', 'תרומה'), (20, 'Tetzaveh', 'תצוה'),
  (21, 'Ki Tisa', 'כי תשא'), (22, 'Vayakhel', 'ויקהל'), (23, 'Pekudei', 'פקודי'), (24, 'Vayikra', 'ויקרא'),
  (25, 'Tzav', 'צו'), (26, 'Shemini', 'שמיני'), (27, 'Tazria', 'תזריע'), (28, 'Metzora', 'מצרע'),
  (29, 'Acharei Mot', 'אחרי מות'), (30, 'Kedoshim', 'קדשים'), (31, 'Emor', 'אמור'), (32, 'Behar', 'בהר'),
  (33, 'Bechukotai', 'בחקתי'), (34, 'Bamidbar', 'במדבר'), (35, 'Naso', 'נשא'), (36, 'Beha''alotcha', 'בהעלתך'),
  (37, 'Shelach', 'שלח־לך'), (38, 'Korach', 'קרח'), (39, 'Chukat', 'חקת'), (40, 'Balak', 'בלק'),
  (41, 'Pinchas', 'פינחס'), (42, 'Matot', 'מטות'), (43, 'Masei', 'מסעי'), (44, 'Devarim', 'דברים'),
  (45, 'Va''etchanan', 'ואתחנן'), (46, 'Ekev', 'עקב'), (47, 'Re''eh', 'ראה'), (48, 'Shoftim', 'שופטים'),
  (49, 'Ki Tetze', 'כי־תצא'), (50, 'Ki Tavo', 'כי־תבוא'), (51, 'Nitzavim', 'נצבים'), (52, 'Vayelech', 'וילך'),
  (53, 'Ha''azinu', 'האזינו'), (54, 'Vezot HaBerachah', 'וזאת הברכה')
ON CONFLICT (id) DO UPDATE SET name_en = excluded.name_en, name_he = excluded.name_he;
