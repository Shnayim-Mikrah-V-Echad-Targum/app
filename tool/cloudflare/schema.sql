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
