// The community's rows in D1 (tool/cloudflare/schema.sql). As in
// account_db.js, each function returns a statement, bound and not yet run,
// or a list of them for a batch, which D1 runs as one transaction.
//
// What a reader may see is decided here, in the queries: a post that is
// deleted is seen by no one; one hidden pending review by its author and
// staff; one by a member the reader blocked by staff alone. The queries that read
// posts take the reader's id as ?1 (0 when signed out, as no account has
// that id) and whether the reader is staff as ?2.

export const POST_MIN = 2;
export const POST_MAX = 10000;
export const TITLE_MIN = 5;
export const TITLE_MAX = 150;
export const NAME_MIN = 2;
export const NAME_MAX = 40;
export const DETAILS_MAX = 1000;

// Whether the reader (?1, staff ?2) may see the post [p].
function visible(p) {
  return `(${p}.deleted_at IS NULL AND (?2 OR ${p}.author_id = ?1 OR (${p}.hidden_at IS NULL
    AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE b.blocker_id = ?1 AND b.blocked_id = ${p}.author_id))))`;
}

// --- Members ----------------------------------------------------------------

// The session's account, with its role and its profile, if it has one yet.
export function findMember(db, tokenHash, now) {
  return db.prepare(
    `SELECT u.id, u.email, u.pw_alg, s.expires_at,
            CASE WHEN u.email_verified_at IS NOT NULL THEN r.role END AS role,
            p.display_name, p.trust_level, p.accepted_terms_at, p.silenced_until, p.banned_at
       FROM sessions s JOIN users u ON u.id = s.user_id
       LEFT JOIN roles r ON r.email = u.email
       LEFT JOIN profiles p ON p.user_id = u.id
      WHERE s.token_hash = ? AND s.expires_at > ? AND u.email_verified_at IS NOT NULL`,
  ).bind(tokenHash, now);
}

export function extendSession(db, tokenHash, expiresAt) {
  return db.prepare('UPDATE sessions SET expires_at = ? WHERE token_hash = ?').bind(expiresAt, tokenHash);
}

// A profile, unless the account has one; returns nothing where the name was taken.
export function insertProfile(db, { userId, name, now }) {
  return db.prepare(
    `INSERT INTO profiles (user_id, display_name, name_key, created_at) VALUES (?, ?, ?, ?)
     ON CONFLICT DO NOTHING RETURNING user_id`,
  ).bind(userId, name, name.toLowerCase(), now);
}

export function findProfile(db, userId) {
  return db.prepare('SELECT display_name FROM profiles WHERE user_id = ?').bind(userId);
}

export function setName(db, userId, name) {
  return db.prepare('UPDATE profiles SET display_name = ?, name_key = ? WHERE user_id = ?')
    .bind(name, name.toLowerCase(), userId);
}

export function findNameKey(db, key) {
  return db.prepare('SELECT user_id FROM profiles WHERE name_key = ?').bind(key);
}

export function acceptTerms(db, userId, now) {
  return db.prepare('UPDATE profiles SET accepted_terms_at = ? WHERE user_id = ?').bind(now, userId);
}

// A member's role and whether the account is there, for moderation.
export function findUserRole(db, userId) {
  return db.prepare(
    `SELECT u.id, CASE WHEN u.email_verified_at IS NOT NULL THEN r.role END AS role
       FROM users u LEFT JOIN roles r ON r.email = u.email WHERE u.id = ?`,
  ).bind(userId);
}

// Removes what a member posted, and the threads they started that no one
// else posted in, before their account goes (accounts.js, deleteEverything).
// The threads others posted in stay, without their author.
export function deleteMember(db, userId) {
  return [
    db.prepare(
      `UPDATE threads SET post_count = max(post_count - (SELECT count(*) FROM posts p
          WHERE p.thread_id = threads.id AND p.author_id = ?1 AND p.deleted_at IS NULL), 0)
        WHERE id IN (SELECT thread_id FROM posts WHERE author_id = ?1)`,
    ).bind(userId),
    db.prepare('DELETE FROM posts WHERE author_id = ?').bind(userId),
    db.prepare(
      'DELETE FROM threads WHERE author_id = ? AND NOT EXISTS (SELECT 1 FROM posts p WHERE p.thread_id = threads.id)',
    ).bind(userId),
    db.prepare('DELETE FROM todot WHERE user_id = ?').bind(userId),
    db.prepare('DELETE FROM reports WHERE reporter_id = ?').bind(userId),
    db.prepare('DELETE FROM user_blocks WHERE blocker_id = ?1 OR blocked_id = ?1').bind(userId),
    db.prepare('DELETE FROM user_progress WHERE user_id = ?').bind(userId),
    db.prepare('DELETE FROM profiles WHERE user_id = ?').bind(userId),
  ];
}

// --- Reading ----------------------------------------------------------------

export function forums(db) {
  return db.prepare(
    'SELECT id, slug, name_en, name_he, description_en, description_he, locked FROM forums ORDER BY sort_order, id',
  );
}

export function findForum(db, forumId) {
  return db.prepare('SELECT id, locked FROM forums WHERE id = ?').bind(forumId);
}

// Each forum's threads, and when one was last posted in: a weekly thread
// opened but not yet posted in counts as a thread, but is no sign of life.
export function forumStats(db) {
  return db.prepare(
    `SELECT f.id AS forum_id, count(t.id) AS thread_count,
            max(CASE WHEN t.post_count > 0 THEN t.last_post_at END) AS last_post_at
       FROM forums f LEFT JOIN threads t ON t.forum_id = f.id AND t.deleted_at IS NULL
      GROUP BY f.id`,
  );
}

const THREAD_COLUMNS = `t.id, t.forum_id, t.parsha_id, t.hebrew_year, t.kind, t.title, t.author_id, t.pinned,
  t.locked, t.post_count, t.last_post_at, t.created_at, pr.display_name AS author_name`;

// A page of a forum's threads (or every forum's), pinned or not, newest
// activity first, then the higher id: those after [after] ({time, id}),
// where given. Each with its first post's body where the reader may see it
// (for the excerpt), and the thanks given to the posts the reader can see.
export function threads(db, { viewer, staff, pinned, forumId, parshaId, after, limit }) {
  return db.prepare(
    `SELECT ${THREAD_COLUMNS},
            (SELECT CASE WHEN ${visible('f')} THEN f.body END FROM posts f
              WHERE f.thread_id = t.id AND f.deleted_at IS NULL ORDER BY f.created_at, f.id LIMIT 1) AS first_body,
            (SELECT count(*) FROM todot r JOIN posts p ON p.id = r.post_id
              WHERE p.thread_id = t.id AND ${visible('p')}) AS todah_total
       FROM threads t LEFT JOIN profiles pr ON pr.user_id = t.author_id
      WHERE t.deleted_at IS NULL AND t.pinned = ?3
        AND (?4 IS NULL OR t.forum_id = ?4) AND (?5 IS NULL OR t.parsha_id = ?5)
        AND (?6 IS NULL OR t.last_post_at < ?6 OR (t.last_post_at = ?6 AND t.id < ?7))
      ORDER BY t.last_post_at DESC, t.id DESC
      LIMIT ?8`,
  ).bind(viewer, staff ? 1 : 0, pinned ? 1 : 0, forumId ?? null, parshaId ?? null, after?.time ?? null, after?.id ?? null, limit);
}

// One thread: staff may open one deleted, from an old link, say.
export function thread(db, { id, staff }) {
  return db.prepare(
    `SELECT ${THREAD_COLUMNS} FROM threads t LEFT JOIN profiles pr ON pr.user_id = t.author_id
      WHERE t.id = ? AND (t.deleted_at IS NULL OR ?)`,
  ).bind(id, staff ? 1 : 0);
}

// The thread a post goes in, as the rules for posting read it.
export function threadForPosting(db, id) {
  return db.prepare('SELECT id, locked, deleted_at FROM threads WHERE id = ?').bind(id);
}

// A page of a thread's posts the reader may see, newest first (the caller
// turns it around), then the higher id: those before [before] ({time, id}).
// Each with the post it answers, where the reader may see that one.
export function posts(db, { viewer, staff, threadId, before, limit }) {
  return db.prepare(
    `SELECT p.id, p.thread_id, p.author_id, p.reply_to_id, p.body, p.created_at, p.edited_at, p.hidden_at,
            pr.display_name AS author_name,
            (SELECT count(*) FROM todot r WHERE r.post_id = p.id) AS todah,
            EXISTS (SELECT 1 FROM todot r WHERE r.post_id = p.id AND r.user_id = ?1) AS my_todah,
            q.id AS quote_id, q.body AS quote_body, qp.display_name AS quote_author
       FROM posts p
       LEFT JOIN profiles pr ON pr.user_id = p.author_id
       LEFT JOIN posts q ON q.id = p.reply_to_id AND ${visible('q')}
       LEFT JOIN profiles qp ON qp.user_id = q.author_id
      WHERE p.thread_id = ?3 AND ${visible('p')}
        AND (?4 IS NULL OR p.created_at < ?4 OR (p.created_at = ?4 AND p.id < ?5))
      ORDER BY p.created_at DESC, p.id DESC
      LIMIT ?6`,
  ).bind(viewer, staff ? 1 : 0, threadId, before?.time ?? null, before?.id ?? null, limit);
}

export function findPost(db, id) {
  return db.prepare('SELECT id, thread_id, author_id, deleted_at FROM posts WHERE id = ?').bind(id);
}

// --- The weekly thread --------------------------------------------------------

export function findWeekly(db, parshaId, year) {
  return db.prepare(
    "SELECT id FROM threads WHERE kind = 'weekly' AND parsha_id = ? AND hebrew_year = ? AND deleted_at IS NULL",
  ).bind(parshaId, year);
}

// Opens the weekly thread unless it is open already; its title is built from
// the parasha's names, so no caller can choose it. Unpinned: the app's "This
// week" card opens it, and pinned weeks would crowd the forum's first page.
export function insertWeekly(db, parshaId, year, now) {
  return db.prepare(
    `INSERT OR IGNORE INTO threads (forum_id, parsha_id, hebrew_year, kind, title, author_id, pinned, last_post_at, created_at)
     SELECT f.id, pa.id, ?2, 'weekly', pa.name_en || ' · ' || pa.name_he || ' · ' || CAST(?2 AS INTEGER), NULL, 0, ?3, ?3
       FROM forums f, parashot pa WHERE f.slug = 'parsha' AND pa.id = ?1`,
  ).bind(parshaId, year, now);
}

export function parshaExists(db, parshaId) {
  return db.prepare('SELECT 1 AS found FROM parashot WHERE id = ?').bind(parshaId);
}

// --- Writing ----------------------------------------------------------------

// What the limits on posting read: the member's posts lately.
export function postingHistory(db, { userId, body, now }) {
  return db.prepare(
    `SELECT max(created_at) AS last_at,
            sum(CASE WHEN created_at > ?2 THEN 1 ELSE 0 END) AS today,
            sum(CASE WHEN created_at > ?3 AND body = ?4 THEN 1 ELSE 0 END) AS same
       FROM posts WHERE author_id = ?1 AND created_at > ?2`,
  ).bind(userId, now - 86400000, now - 300000, body);
}

export function threadsToday(db, userId, now) {
  return db.prepare('SELECT count(*) AS n FROM threads WHERE author_id = ? AND created_at > ?')
    .bind(userId, now - 86400000);
}

// A thread and its first post, together.
export function insertThread(db, { forumId, parshaId, title, body, userId, now }) {
  return [
    db.prepare(
      `INSERT INTO threads (forum_id, parsha_id, kind, title, author_id, post_count, last_post_at, created_at)
       VALUES (?, ?, 'discussion', ?, ?, 1, ?, ?) RETURNING id`,
    ).bind(forumId, parshaId ?? null, title, userId, now, now),
    db.prepare('INSERT INTO posts (thread_id, author_id, body, created_at) VALUES (last_insert_rowid(), ?, ?, ?)')
      .bind(userId, body, now),
  ];
}

export function insertPost(db, { threadId, userId, body, replyToId, now }) {
  return [
    db.prepare(
      'INSERT INTO posts (thread_id, author_id, reply_to_id, body, created_at) VALUES (?, ?, ?, ?, ?) RETURNING id',
    ).bind(threadId, userId, replyToId ?? null, body, now),
    db.prepare('UPDATE threads SET post_count = post_count + 1, last_post_at = ? WHERE id = ?').bind(now, threadId),
  ];
}

// An edit keeps the earlier wording.
export function editPost(db, { postId, userId, body, now }) {
  return [
    db.prepare('INSERT INTO post_revisions (post_id, body, edited_by, edited_at) SELECT id, body, ?, ? FROM posts WHERE id = ?')
      .bind(userId, now, postId),
    db.prepare('UPDATE posts SET body = ?, edited_at = ? WHERE id = ?').bind(body, now, postId),
  ];
}

// A post deleted, which its thread no longer counts.
export function softDeletePost(db, { postId, userId, reason, now }) {
  return [
    db.prepare(
      'UPDATE threads SET post_count = max(post_count - 1, 0) WHERE id = (SELECT thread_id FROM posts WHERE id = ? AND deleted_at IS NULL)',
    ).bind(postId),
    db.prepare('UPDATE posts SET deleted_at = ?, deleted_by = ?, delete_reason = ? WHERE id = ? AND deleted_at IS NULL')
      .bind(now, userId, reason ?? null, postId),
  ];
}

export function giveTodah(db, postId, userId, now) {
  return db.prepare('INSERT OR IGNORE INTO todot (post_id, user_id, created_at) VALUES (?, ?, ?)').bind(postId, userId, now);
}

export function takeTodah(db, postId, userId) {
  return db.prepare('DELETE FROM todot WHERE post_id = ? AND user_id = ?').bind(postId, userId);
}

// --- Safety -----------------------------------------------------------------

export function insertReport(db, { reporterId, postId, threadId, reason, details, now }) {
  return db.prepare(
    `INSERT INTO reports (reporter_id, post_id, thread_id, reason, details, created_at) VALUES (?, ?, ?, ?, ?, ?)
     ON CONFLICT DO NOTHING RETURNING id`,
  ).bind(reporterId, postId ?? null, threadId ?? null, reason, details ?? null, now);
}

// Hides a post once three members have reported it, until staff look.
export function hideIfReported(db, postId, now) {
  return db.prepare(
    `UPDATE posts SET hidden_at = ?1, hidden_reason = 'community_flags'
      WHERE id = ?2 AND hidden_at IS NULL
        AND (SELECT count(DISTINCT reporter_id) FROM reports WHERE post_id = ?2 AND status = 'open') >= 3`,
  ).bind(now, postId);
}

export function block(db, blockerId, blockedId, now) {
  return db.prepare('INSERT OR IGNORE INTO user_blocks (blocker_id, blocked_id, created_at) VALUES (?, ?, ?)')
    .bind(blockerId, blockedId, now);
}

export function unblock(db, blockerId, blockedId) {
  return db.prepare('DELETE FROM user_blocks WHERE blocker_id = ? AND blocked_id = ?').bind(blockerId, blockedId);
}

export function blocked(db, blockerId) {
  return db.prepare(
    `SELECT b.blocked_id AS id, pr.display_name AS name FROM user_blocks b
       LEFT JOIN profiles pr ON pr.user_id = b.blocked_id
      WHERE b.blocker_id = ? ORDER BY b.created_at`,
  ).bind(blockerId);
}

// --- Moderation ---------------------------------------------------------------

export function openReports(db) {
  return db.prepare(
    `SELECT r.id, r.post_id, r.reason, r.details, r.created_at, p.body AS post_body
       FROM reports r LEFT JOIN posts p ON p.id = r.post_id
      WHERE r.status = 'open' ORDER BY r.created_at, r.id`,
  );
}

// The statements of a moderation action on its target (an id as a number),
// or null for an action there is none of.
export function moderation(db, { action, target, actorId, reason, now }) {
  const until = now + 7 * 86400000;
  switch (action) {
    case 'hide_post':
      return [db.prepare('UPDATE posts SET hidden_at = ?, hidden_reason = ? WHERE id = ?').bind(now, reason ?? 'staff', target)];
    case 'restore_post':
      return [
        db.prepare(
          'UPDATE threads SET post_count = post_count + 1 WHERE id = (SELECT thread_id FROM posts WHERE id = ? AND deleted_at IS NOT NULL)',
        ).bind(target),
        db.prepare(
          'UPDATE posts SET hidden_at = NULL, hidden_reason = NULL, deleted_at = NULL, deleted_by = NULL, delete_reason = NULL WHERE id = ?',
        ).bind(target),
      ];
    case 'lock_thread':
    case 'unlock_thread':
      return [db.prepare('UPDATE threads SET locked = ? WHERE id = ?').bind(action === 'lock_thread' ? 1 : 0, target)];
    case 'pin_thread':
    case 'unpin_thread':
      return [db.prepare('UPDATE threads SET pinned = ? WHERE id = ?').bind(action === 'pin_thread' ? 1 : 0, target)];
    case 'delete_thread':
      return [
        db.prepare('UPDATE threads SET deleted_at = ?, deleted_by = ?, delete_reason = ? WHERE id = ? AND deleted_at IS NULL')
          .bind(now, actorId, reason ?? null, target),
      ];
    case 'silence_user':
      return [db.prepare('UPDATE profiles SET silenced_until = ? WHERE user_id = ?').bind(until, target)];
    case 'ban_user':
      return [db.prepare('UPDATE profiles SET banned_at = ? WHERE user_id = ?').bind(now, target)];
    case 'unban_user':
      return [db.prepare('UPDATE profiles SET banned_at = NULL, silenced_until = NULL WHERE user_id = ?').bind(target)];
    case 'set_trust':
      return [db.prepare('UPDATE profiles SET trust_level = ? WHERE user_id = ?').bind(Number(reason), target)];
    case 'resolve_report':
    case 'dismiss_report':
      return [
        db.prepare("UPDATE reports SET status = ?, resolved_by = ?, resolved_at = ? WHERE id = ? AND status = 'open'")
          .bind(action === 'resolve_report' ? 'actioned' : 'dismissed', actorId, now, target),
      ];
    case 'grant_moderator':
      return [
        db.prepare(
          `INSERT INTO roles (email, role, granted_at) SELECT email, 'moderator', ? FROM users
            WHERE id = ? AND email_verified_at IS NOT NULL ON CONFLICT (email) DO NOTHING`,
        ).bind(now, target),
      ];
    case 'revoke_moderator':
      return [
        db.prepare("DELETE FROM roles WHERE role = 'moderator' AND email = (SELECT email FROM users WHERE id = ?)").bind(target),
      ];
    default:
      return null;
  }
}

export function logModeration(db, { actorId, action, targetType, target, reason, now }) {
  return db.prepare(
    'INSERT INTO moderation_log (actor_id, action, target_type, target_id, reason, created_at) VALUES (?, ?, ?, ?, ?, ?)',
  ).bind(actorId, action, targetType, String(target), reason ?? null, now);
}

// --- Progress backup ----------------------------------------------------------

export function loadProgress(db, userId) {
  return db.prepare('SELECT data FROM user_progress WHERE user_id = ?').bind(userId);
}

export function saveProgress(db, userId, data, now) {
  return db.prepare(
    `INSERT INTO user_progress (user_id, data, updated_at) VALUES (?, ?, ?)
     ON CONFLICT (user_id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at`,
  ).bind(userId, data, now);
}
