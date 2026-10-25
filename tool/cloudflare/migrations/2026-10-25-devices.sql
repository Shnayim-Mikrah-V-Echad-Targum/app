-- For a database made before 2026-10-25 (schema.sql has these for a new one).
-- Run once: npx wrangler@4 d1 execute shnayimmikrah-logs --remote --file migrations/2026-10-25-devices.sql
-- Each change keeps what is there.

-- What signed in, and when it was last seen, for each session.
ALTER TABLE sessions ADD COLUMN device TEXT;
ALTER TABLE sessions ADD COLUMN last_seen_at INTEGER;

-- The owner (the super admin) among the roles. SQLite can't change a
-- table's CHECK, so the table is made again with its rows.
CREATE TABLE roles_new (
  email TEXT PRIMARY KEY,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'moderator')),
  granted_at INTEGER NOT NULL
);
INSERT INTO roles_new (email, role, granted_at) SELECT email, role, granted_at FROM roles;
DROP TABLE roles;
ALTER TABLE roles_new RENAME TO roles;

-- The one-time links from the app to the site.
CREATE TABLE IF NOT EXISTS handoffs (
  token_hash TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  next TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);
