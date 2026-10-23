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
