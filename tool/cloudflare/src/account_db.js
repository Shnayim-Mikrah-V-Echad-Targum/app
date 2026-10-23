// The accounts' rows in D1 (tool/cloudflare/schema.sql). Each function returns
// a statement, bound and not yet run, so the caller can run it alone or in a
// batch, which D1 runs as one transaction. Nothing here sees a raw secret: the
// callers pass hashes.

export const SESSION_MS = 30 * 86400000;
export const CODE_MS = 15 * 60000;
export const CODE_TRIES = 5;
export const RESET_MS = 60 * 60000;
export const UNVERIFIED_MS = 7 * 86400000;

export function findUserByEmail(db, email) {
  return db.prepare(
    'SELECT id, email, email_verified_at, pw_alg, pw_iter, pw_salt, pw_hash FROM users WHERE email = ?',
  ).bind(email);
}

export function insertUser(db, { email, password, now }) {
  return db.prepare(
    'INSERT INTO users (email, pw_alg, pw_iter, pw_salt, pw_hash, created_at) VALUES (?, ?, ?, ?, ?, ?) RETURNING id',
  ).bind(email, password.pw_alg, password.pw_iter, password.pw_salt, password.pw_hash, now);
}

export function setPassword(db, userId, password) {
  return db.prepare(
    'UPDATE users SET pw_alg = ?, pw_iter = ?, pw_salt = ?, pw_hash = ? WHERE id = ?',
  ).bind(password.pw_alg, password.pw_iter, password.pw_salt, password.pw_hash, userId);
}

export function markVerified(db, userId, now) {
  return db.prepare('UPDATE users SET email_verified_at = ? WHERE id = ? AND email_verified_at IS NULL').bind(now, userId);
}

// A new code replaces the old one, so a code that was sent earlier stops working.
export function replaceCode(db, { userId, codeHash, now }) {
  return [
    db.prepare("DELETE FROM codes WHERE user_id = ? AND purpose = 'verify'").bind(userId),
    db.prepare(
      "INSERT INTO codes (user_id, purpose, code_hash, expires_at, attempts, created_at) VALUES (?, 'verify', ?, ?, 0, ?)",
    ).bind(userId, codeHash, now + CODE_MS, now),
  ];
}

export function findCode(db, userId) {
  return db.prepare(
    "SELECT id, code_hash, expires_at, attempts FROM codes WHERE user_id = ? AND purpose = 'verify' ORDER BY id DESC LIMIT 1",
  ).bind(userId);
}

// Counts a wrong try, and returns the count.
export function countCodeTry(db, codeId) {
  return db.prepare('UPDATE codes SET attempts = attempts + 1 WHERE id = ? RETURNING attempts').bind(codeId);
}

export function deleteCode(db, codeId) {
  return db.prepare('DELETE FROM codes WHERE id = ?').bind(codeId);
}

export function deleteCodesOf(db, userId) {
  return db.prepare('DELETE FROM codes WHERE user_id = ?').bind(userId);
}

export function insertSession(db, { tokenHash, userId, now }) {
  return db.prepare(
    'INSERT INTO sessions (token_hash, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)',
  ).bind(tokenHash, userId, now, now + SESSION_MS);
}

export function findSession(db, tokenHash, now) {
  return db.prepare(
    `SELECT u.id, u.email, u.email_verified_at
       FROM sessions s JOIN users u ON u.id = s.user_id
      WHERE s.token_hash = ? AND s.expires_at > ?`,
  ).bind(tokenHash, now);
}

export function deleteSession(db, tokenHash) {
  return db.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(tokenHash);
}

export function deleteSessionsOf(db, userId) {
  return db.prepare('DELETE FROM sessions WHERE user_id = ?').bind(userId);
}

// A new reset link replaces the unused ones sent before it.
export function replaceResetToken(db, { userId, tokenHash, now }) {
  return [
    db.prepare('DELETE FROM reset_tokens WHERE user_id = ? AND used_at IS NULL').bind(userId),
    db.prepare(
      'INSERT INTO reset_tokens (token_hash, user_id, expires_at, used_at, created_at) VALUES (?, ?, ?, NULL, ?)',
    ).bind(tokenHash, userId, now + RESET_MS, now),
  ];
}

export function findResetToken(db, tokenHash, now) {
  return db.prepare(
    'SELECT user_id FROM reset_tokens WHERE token_hash = ? AND used_at IS NULL AND expires_at > ?',
  ).bind(tokenHash, now);
}

// Claims a reset link, so it works once: only the first claim returns a row.
export function claimResetToken(db, tokenHash, now) {
  return db.prepare(
    'UPDATE reset_tokens SET used_at = ? WHERE token_hash = ? AND used_at IS NULL AND expires_at > ? RETURNING user_id',
  ).bind(now, tokenHash, now);
}

export function deleteResetTokensOf(db, userId) {
  return db.prepare('DELETE FROM reset_tokens WHERE user_id = ?').bind(userId);
}

// Removes an account's rows, the user row last.
export function deleteAccount(db, userId) {
  return [
    deleteSessionsOf(db, userId),
    deleteCodesOf(db, userId),
    deleteResetTokensOf(db, userId),
    db.prepare('DELETE FROM users WHERE id = ?').bind(userId),
  ];
}

// Counts one attempt against a key in its time window, and says whether the
// window's limit is now passed. The window is part of the key, so each window
// starts a new count, and a row expires with its window.
export async function overLimit(db, key, limit, windowMs, now) {
  const window = Math.floor(now / windowMs);
  const row = await db.prepare(
    `INSERT INTO rate_limits (key, count, expires_at) VALUES (?, 1, ?)
     ON CONFLICT(key) DO UPDATE SET count = count + 1
     RETURNING count`,
  ).bind(`${key}|${window}`, (window + 1) * windowMs).first();
  return row.count > limit;
}

// The daily clean-up of the accounts' rows that have passed their time.
export function accountCleanup(db, now) {
  return [
    db.prepare('DELETE FROM sessions WHERE expires_at <= ?').bind(now),
    db.prepare('DELETE FROM codes WHERE expires_at <= ?').bind(now),
    db.prepare('DELETE FROM reset_tokens WHERE expires_at <= ?').bind(now),
    db.prepare('DELETE FROM rate_limits WHERE expires_at <= ?').bind(now),
    db.prepare(
      'DELETE FROM codes WHERE user_id IN (SELECT id FROM users WHERE email_verified_at IS NULL AND created_at <= ?)',
    ).bind(now - UNVERIFIED_MS),
    db.prepare('DELETE FROM users WHERE email_verified_at IS NULL AND created_at <= ?').bind(now - UNVERIFIED_MS),
  ];
}
