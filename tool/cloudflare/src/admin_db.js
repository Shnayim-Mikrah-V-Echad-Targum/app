// What the admin panel (admin.js) reads from D1: the accounts, the community
// and the site's logs. As in account_db.js, each function returns a
// statement, bound and not yet run.

const DAY = 86400000;

// Counts for the overview, in one row.
export function overview(db, now) {
  return db.prepare(
    `SELECT
       (SELECT count(*) FROM users) AS accounts,
       (SELECT count(*) FROM users WHERE email_verified_at IS NOT NULL) AS confirmed,
       (SELECT count(*) FROM users WHERE created_at > ?1) AS new_week,
       (SELECT count(DISTINCT user_id) FROM sessions WHERE expires_at > ?2) AS signed_in,
       (SELECT count(*) FROM roles) AS staff,
       (SELECT count(*) FROM profiles WHERE banned_at IS NOT NULL) AS banned,
       (SELECT count(*) FROM profiles WHERE silenced_until > ?2) AS silenced,
       (SELECT count(*) FROM threads WHERE deleted_at IS NULL) AS threads,
       (SELECT count(*) FROM posts WHERE deleted_at IS NULL) AS posts,
       (SELECT count(*) FROM posts WHERE deleted_at IS NULL AND created_at > ?1) AS posts_week,
       (SELECT count(*) FROM posts WHERE hidden_at IS NOT NULL AND deleted_at IS NULL) AS hidden,
       (SELECT count(*) FROM reports WHERE status = 'open') AS open_reports,
       (SELECT count(*) FROM security_events WHERE ts > ?3) AS events_day`,
  ).bind(now - 7 * DAY, now, now - DAY);
}

// Visits and visitors (a day's distinct address hashes) for each of the last [days] UTC days.
export function visitsByDay(db, now, days) {
  return db.prepare(
    `SELECT date(ts / 1000, 'unixepoch') AS day, count(*) AS visits, count(DISTINCT ip) AS visitors
       FROM visits WHERE ts > ? GROUP BY day ORDER BY day DESC`,
  ).bind(now - days * DAY);
}

export function eventsByKind(db, since) {
  return db.prepare('SELECT kind, count(*) AS n FROM security_events WHERE ts > ? GROUP BY kind ORDER BY n DESC').bind(since);
}

export function recentEvents(db, { kind, limit }) {
  return db.prepare(
    `SELECT ts, kind, detail, ip, path, method, status, ua, country, asn FROM security_events
      WHERE (?1 IS NULL OR kind = ?1) ORDER BY ts DESC LIMIT ?2`,
  ).bind(kind ?? null, limit);
}

// The most frequent values of a visit column ([column] is one of a fixed few) since a time.
export function topVisits(db, column, since, limit = 10) {
  if (!['path', 'country', 'referer_host', 'lang'].includes(column)) throw new Error('not a visit column');
  return db.prepare(
    `SELECT ${column} AS value, count(*) AS n FROM visits WHERE ts > ? AND ${column} IS NOT NULL
      GROUP BY ${column} ORDER BY n DESC LIMIT ?`,
  ).bind(since, limit);
}

// The addresses (as the day's hashes) behind the most security events since a time.
export function topOffenders(db, since, limit = 10) {
  return db.prepare(
    `SELECT ip, count(*) AS n, group_concat(DISTINCT kind) AS kinds, max(country) AS country, max(asn) AS asn
       FROM security_events WHERE ts > ? AND ip IS NOT NULL GROUP BY ip ORDER BY n DESC LIMIT ?`,
  ).bind(since, limit);
}

const ACCOUNT_COLUMNS = `u.id, u.email, u.email_verified_at, u.created_at, u.pw_alg, r.role,
  p.display_name, p.trust_level, p.accepted_terms_at, p.banned_at, p.silenced_until,
  (SELECT count(*) FROM posts WHERE author_id = u.id AND deleted_at IS NULL) AS posts,
  (SELECT max(created_at) FROM sessions WHERE user_id = u.id) AS last_sign_in,
  (SELECT count(*) FROM sessions WHERE user_id = u.id AND expires_at > ?1) AS sessions`;

// A page of accounts, newest first, whose address or display name holds [query].
export function accounts(db, { query, now, limit, offset }) {
  const like = `%${query.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
  return db.prepare(
    `SELECT ${ACCOUNT_COLUMNS}
       FROM users u LEFT JOIN roles r ON r.email = u.email LEFT JOIN profiles p ON p.user_id = u.id
      WHERE ?2 = '' OR u.email LIKE ?3 ESCAPE '\\' OR p.display_name LIKE ?3 ESCAPE '\\'
      ORDER BY u.id DESC LIMIT ?4 OFFSET ?5`,
  ).bind(now, query, like, limit, offset);
}

export function account(db, id, now) {
  return db.prepare(
    `SELECT ${ACCOUNT_COLUMNS}
       FROM users u LEFT JOIN roles r ON r.email = u.email LEFT JOIN profiles p ON p.user_id = u.id
      WHERE u.id = ?2`,
  ).bind(now, id);
}

export function postsBy(db, userId, limit = 20) {
  return db.prepare(
    `SELECT p.id, p.thread_id, p.body, p.created_at, p.hidden_at, p.deleted_at, t.title
       FROM posts p JOIN threads t ON t.id = p.thread_id
      WHERE p.author_id = ? ORDER BY p.created_at DESC LIMIT ?`,
  ).bind(userId, limit);
}

export function openReports(db) {
  return db.prepare(
    `SELECT r.id, r.reason, r.details, r.created_at, r.post_id, r.thread_id,
            p.body AS post_body, p.hidden_at, p.deleted_at, p.author_id, pr.display_name AS author_name,
            t.id AS t_id, t.title, rp.display_name AS reporter_name,
            (SELECT count(DISTINCT reporter_id) FROM reports o WHERE o.post_id = r.post_id AND o.status = 'open') AS reporters
       FROM reports r
       LEFT JOIN posts p ON p.id = r.post_id
       LEFT JOIN threads t ON t.id = coalesce(r.thread_id, p.thread_id)
       LEFT JOIN profiles pr ON pr.user_id = p.author_id
       LEFT JOIN profiles rp ON rp.user_id = r.reporter_id
      WHERE r.status = 'open' ORDER BY r.created_at, r.id`,
  );
}

export function moderationLog(db, { target, limit }) {
  return db.prepare(
    `SELECT m.created_at, m.action, m.target_type, m.target_id, m.reason, u.email AS actor
       FROM moderation_log m LEFT JOIN users u ON u.id = m.actor_id
      WHERE ?1 IS NULL OR (m.target_type IN ('user', 'moderator', 'trust', 'account') AND m.target_id = ?1)
      ORDER BY m.created_at DESC, m.id DESC LIMIT ?2`,
  ).bind(target ?? null, limit);
}
