// The accounts' rows in D1 (tool/cloudflare/schema.sql). Each function returns
// a statement, bound and not yet run, so the caller can run it alone or in a
// batch, which D1 runs as one transaction. Nothing here sees a raw secret: the
// callers pass hashes.

export const SESSION_MS = 30 * 86400000;
export const CODE_MS = 15 * 60000;
export const CODE_TRIES = 5;
export const RESET_MS = 60 * 60000;
export const UNVERIFIED_MS = 7 * 86400000;
export const PENDING_MS = 10 * 60000;
export const PENDING_TRIES = 5;
export const CHALLENGE_MS = 5 * 60000;

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
    // A role counts only once the address is confirmed as the account's.
    `SELECT u.id, u.email, u.email_verified_at, u.pw_alg, s.expires_at,
            CASE WHEN u.email_verified_at IS NOT NULL THEN r.role END AS role
       FROM sessions s JOIN users u ON u.id = s.user_id
       LEFT JOIN roles r ON r.email = u.email
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
    ...deleteSecondSteps(db, userId),
    db.prepare('DELETE FROM pending_signins WHERE user_id = ?').bind(userId),
    db.prepare('DELETE FROM webauthn_challenges WHERE user_id = ?').bind(userId),
    db.prepare('DELETE FROM users WHERE id = ?').bind(userId),
  ];
}

// Whether a key has used up its tries in its window. Reads only, so a refused
// try writes nothing. The window is part of the key, so each window starts a
// new count, and a row expires with its window.
export async function isOverLimit(db, key, limit, windowMs, now) {
  const window = Math.floor(now / windowMs);
  const row = await db.prepare('SELECT count FROM rate_limits WHERE key = ?').bind(`${key}|${window}`).first();
  return (row?.count ?? 0) >= limit;
}

// One try counted against a key in its window: a statement, to run alone or in a batch.
export function countTry(db, key, windowMs, now) {
  const window = Math.floor(now / windowMs);
  return db.prepare(
    `INSERT INTO rate_limits (key, count, expires_at) VALUES (?, 1, ?)
     ON CONFLICT(key) DO UPDATE SET count = count + 1`,
  ).bind(`${key}|${window}`, (window + 1) * windowMs);
}

// The daily clean-up of the accounts' rows that have passed their time.
export function accountCleanup(db, now) {
  return [
    db.prepare('DELETE FROM sessions WHERE expires_at <= ?').bind(now),
    db.prepare('DELETE FROM codes WHERE expires_at <= ?').bind(now),
    db.prepare('DELETE FROM reset_tokens WHERE expires_at <= ?').bind(now),
    db.prepare('DELETE FROM rate_limits WHERE expires_at <= ?').bind(now),
    db.prepare('DELETE FROM pending_signins WHERE expires_at <= ?').bind(now),
    db.prepare('DELETE FROM webauthn_challenges WHERE expires_at <= ?').bind(now),
    db.prepare('DELETE FROM totp WHERE confirmed_at IS NULL AND created_at <= ?').bind(now - 86400000),
    db.prepare(
      'DELETE FROM codes WHERE user_id IN (SELECT id FROM users WHERE email_verified_at IS NULL AND created_at <= ?)',
    ).bind(now - UNVERIFIED_MS),
    db.prepare('DELETE FROM users WHERE email_verified_at IS NULL AND created_at <= ?').bind(now - UNVERIFIED_MS),
  ];
}

// --- The second step, and passkeys ------------------------------------------

export function findTotp(db, userId) {
  return db.prepare('SELECT secret_sealed, confirmed_at, last_step FROM totp WHERE user_id = ?').bind(userId);
}

// A new secret being set up replaces any other not yet confirmed; a
// confirmed one stays until it is turned off.
export function startTotp(db, { userId, sealed, now }) {
  return db.prepare(
    `INSERT INTO totp (user_id, secret_sealed, confirmed_at, last_step, created_at) VALUES (?, ?, NULL, 0, ?)
     ON CONFLICT (user_id) DO UPDATE SET secret_sealed = excluded.secret_sealed, last_step = 0, created_at = excluded.created_at
     WHERE totp.confirmed_at IS NULL`,
  ).bind(userId, sealed, now);
}

// The step a code was used at, so that it works once; and, at set-up, that
// the secret is confirmed. Only a later step is taken, so of two requests
// with the same code, one wins.
export function useTotpStep(db, { userId, step, now, confirm = false }) {
  return db.prepare(
    `UPDATE totp SET last_step = ?, confirmed_at = CASE WHEN ? THEN coalesce(confirmed_at, ?) ELSE confirmed_at END
      WHERE user_id = ? AND last_step < ? RETURNING user_id`,
  ).bind(step, confirm ? 1 : 0, now, userId, step);
}

export function replaceRecoveryCodes(db, userId, hashes) {
  return [
    db.prepare('DELETE FROM recovery_codes WHERE user_id = ?').bind(userId),
    ...hashes.map((hash) => db.prepare('INSERT INTO recovery_codes (user_id, code_hash) VALUES (?, ?)').bind(userId, hash)),
  ];
}

// Uses a recovery code, once: only the first use returns a row.
export function useRecoveryCode(db, userId, hash, now) {
  return db.prepare(
    'UPDATE recovery_codes SET used_at = ? WHERE user_id = ? AND code_hash = ? AND used_at IS NULL RETURNING user_id',
  ).bind(now, userId, hash);
}

export function recoveryLeft(db, userId) {
  return db.prepare('SELECT count(*) AS n FROM recovery_codes WHERE user_id = ? AND used_at IS NULL').bind(userId);
}

// Turns the second step off: the authenticator and its recovery codes.
export function deleteTotp(db, userId) {
  return [
    db.prepare('DELETE FROM totp WHERE user_id = ?').bind(userId),
    db.prepare('DELETE FROM recovery_codes WHERE user_id = ?').bind(userId),
  ];
}

// Every way of signing in but the password and the email: the
// authenticator, its recovery codes, and the passkeys (as an admin clears
// them for a member locked out, and as an account is deleted).
export function deleteSecondSteps(db, userId) {
  return [...deleteTotp(db, userId), db.prepare('DELETE FROM passkeys WHERE user_id = ?').bind(userId)];
}

export function insertPending(db, { tokenHash, userId, now }) {
  return db.prepare('INSERT INTO pending_signins (token_hash, user_id, attempts, expires_at) VALUES (?, ?, 0, ?)')
    .bind(tokenHash, userId, now + PENDING_MS);
}

export function findPending(db, tokenHash, now) {
  return db.prepare(
    `SELECT p.user_id, p.attempts, u.email FROM pending_signins p JOIN users u ON u.id = p.user_id
      WHERE p.token_hash = ? AND p.expires_at > ?`,
  ).bind(tokenHash, now);
}

export function countPendingTry(db, tokenHash) {
  return db.prepare('UPDATE pending_signins SET attempts = attempts + 1 WHERE token_hash = ? RETURNING attempts').bind(tokenHash);
}

export function deletePending(db, tokenHash) {
  return db.prepare('DELETE FROM pending_signins WHERE token_hash = ?').bind(tokenHash);
}

export function insertChallenge(db, { challengeHash, userId, purpose, now }) {
  return db.prepare('INSERT INTO webauthn_challenges (challenge_hash, user_id, purpose, expires_at) VALUES (?, ?, ?, ?)')
    .bind(challengeHash, userId ?? null, purpose, now + CHALLENGE_MS);
}

// Takes a challenge, once: only the first claim returns its row.
export function claimChallenge(db, { challengeHash, purpose, now }) {
  return db.prepare(
    'DELETE FROM webauthn_challenges WHERE challenge_hash = ? AND purpose = ? AND expires_at > ? RETURNING user_id',
  ).bind(challengeHash, purpose, now);
}

export function passkeysOf(db, userId) {
  return db.prepare('SELECT id, created_at, last_used_at FROM passkeys WHERE user_id = ? ORDER BY created_at').bind(userId);
}

export function findPasskey(db, id) {
  return db.prepare(
    `SELECT k.id, k.user_id, k.public_key, k.alg, k.sign_count, u.email_verified_at
       FROM passkeys k JOIN users u ON u.id = k.user_id WHERE k.id = ?`,
  ).bind(id);
}

export function insertPasskey(db, { id, userId, jwk, alg, signCount, now }) {
  return db.prepare(
    'INSERT INTO passkeys (id, user_id, public_key, alg, sign_count, created_at) VALUES (?, ?, ?, ?, ?, ?)',
  ).bind(id, userId, JSON.stringify(jwk), alg, signCount, now);
}

export function usePasskey(db, { id, signCount, now }) {
  return db.prepare('UPDATE passkeys SET sign_count = ?, last_used_at = ? WHERE id = ?').bind(signCount, now, id);
}

export function deletePasskey(db, userId, id) {
  return db.prepare('DELETE FROM passkeys WHERE user_id = ? AND id = ?').bind(userId, id);
}
