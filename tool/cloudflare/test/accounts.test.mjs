// Run with: node --test tool/cloudflare/test/accounts.test.mjs
// The database is real SQLite (node:sqlite), behind the same calls D1 takes, so
// the accounts' SQL runs as it would on D1. Turnstile and Resend are stubbed.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { afterEach, beforeEach, test } from 'node:test';

import worker from '../src/worker.js';
import { hashPassword } from '../src/account_crypto.js';

const SITE = 'https://shnayimmikrah.org';
const ADDRESS = '203.0.113.9';
const PASSWORD = 'a long password';

// The D1 calls the Worker makes, over node:sqlite. A batch is one transaction.
function d1(database) {
  const prepare = (sql) => {
    let values = [];
    return {
      sql,
      bind(...args) {
        values = args;
        return this;
      },
      first() {
        return database.prepare(sql).get(...values) ?? null;
      },
      all() {
        return { results: database.prepare(sql).all(...values) };
      },
      run() {
        database.prepare(sql).run(...values);
        return { success: true };
      },
    };
  };
  return {
    prepare,
    async batch(statements) {
      database.exec('BEGIN');
      try {
        const results = statements.map((statement) => statement.run());
        database.exec('COMMIT');
        return results;
      } catch (error) {
        database.exec('ROLLBACK');
        throw error;
      }
    },
  };
}

function makeEnv() {
  const database = new DatabaseSync(':memory:');
  database.exec(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8'));
  return {
    database,
    env: {
      LOGS: d1(database),
      ASSETS: { fetch: async () => new Response('the app', { status: 200 }) },
      CANONICAL_HOST: 'shnayimmikrah.org',
      RETENTION_DAYS: '365',
      IP_SALT: 'test-salt',
      ACCOUNTS_KEY: 'test-accounts-key',
      TURNSTILE_SECRET_KEY: 'test-turnstile',
      TURNSTILE_SITE_KEY: 'test-site-key',
      RESEND_API_KEY: 're_test',
      ACCOUNTS_FROM: 'Shnayim Mikrah <accounts@shnayimmikrah.org>',
    },
  };
}

// The outside world: Turnstile answers as the test says, and Resend keeps the mail.
let mail;
let turnstile;
let realFetch;

beforeEach(() => {
  mail = [];
  turnstile = { success: true };
  realFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    const target = String(url);
    if (target.startsWith('https://challenges.cloudflare.com/')) {
      return new Response(JSON.stringify({ success: turnstile.success }), { headers: { 'content-type': 'application/json' } });
    }
    if (target === 'https://api.resend.com/emails') {
      mail.push(JSON.parse(init.body));
      return new Response('{}', { status: 200 });
    }
    throw new Error(`unexpected request in a test: ${target}`);
  };
});

afterEach(() => {
  globalThis.fetch = realFetch;
});

async function call(state, method, path, { form, cookie, origin = SITE, ip = ADDRESS, env } = {}) {
  const headers = { 'user-agent': 'Mozilla/5.0 Chrome/130', 'sec-fetch-dest': 'document', 'cf-connecting-ip': ip, 'accept-language': 'en' };
  const init = { method, headers };
  if (cookie) headers.cookie = cookie;
  if (method === 'POST') {
    headers.origin = origin;
    headers['content-type'] = 'application/x-www-form-urlencoded';
    init.body = new URLSearchParams(form ?? {}).toString();
  }
  const request = new Request(`${SITE}${path}`, init);
  Object.defineProperty(request, 'cf', { value: { country: 'IL', asn: 8551, threatScore: 2 } });
  const waits = [];
  const response = await worker.fetch(request, env ?? state.env, { waitUntil: (promise) => waits.push(promise) });
  await Promise.all(waits);
  return response;
}

function lastCode() {
  return mail.at(-1).text.match(/Your code is (\d{6})/)[1];
}

function lastLink() {
  return mail.at(-1).text.match(/https:\/\/\S+/)[0];
}

// The cookie as the browser sends it back: name=value.
function cookieOf(response) {
  const set = response.headers.get('set-cookie');
  return set ? set.split(';')[0] : null;
}

function tokenOf(cookie) {
  return cookie.slice(cookie.indexOf('=') + 1);
}

// Whether any stored value is exactly this text, in any table.
function storedAnywhere(database, text) {
  for (const { name } of database.prepare("SELECT name FROM sqlite_master WHERE type = 'table'").all()) {
    for (const row of database.prepare(`SELECT * FROM ${name}`).all()) {
      if (Object.values(row).some((value) => value === text)) return true;
    }
  }
  return false;
}

function count(database, sql, ...values) {
  return database.prepare(sql).get(...values).n;
}

async function signedUpAndVerified(state, email = 'reader@example.com') {
  await call(state, 'POST', '/account/sign-up', { form: { email, password: PASSWORD, 'cf-turnstile-response': 't' } });
  const response = await call(state, 'POST', '/account/verify', { form: { email, code: lastCode() } });
  return { email, cookie: cookieOf(response) };
}

test('sign-up sends a code, and the database keeps only hashes', async () => {
  const state = makeEnv();
  const response = await call(state, 'POST', '/account/sign-up', {
    form: { email: 'Reader@Example.com', password: PASSWORD, 'cf-turnstile-response': 't' },
  });
  assert.equal(response.status, 303);
  assert.ok(response.headers.get('location').startsWith('/account/verify?'));
  assert.equal(mail.length, 1);
  assert.equal(mail[0].to[0], 'reader@example.com', 'the address is lower case');

  const user = state.database.prepare('SELECT * FROM users').get();
  assert.equal(user.email_verified_at, null);
  assert.equal(user.pw_alg, 'pbkdf2-sha256');
  assert.equal(user.pw_iter, 100000);
  assert.equal(storedAnywhere(state.database, PASSWORD), false, 'the password is never stored');
  assert.equal(storedAnywhere(state.database, lastCode()), false, 'the code is never stored, only its hash');
});

test('the right code verifies the email and starts a session in a locked-down cookie', async () => {
  const state = makeEnv();
  await call(state, 'POST', '/account/sign-up', { form: { email: 'reader@example.com', password: PASSWORD, 'cf-turnstile-response': 't' } });
  const response = await call(state, 'POST', '/account/verify', { form: { email: 'reader@example.com', code: lastCode() } });

  assert.equal(response.status, 303);
  assert.equal(response.headers.get('location'), '/account');
  const set = response.headers.get('set-cookie');
  assert.match(set, /^__Host-sm_session=[A-Za-z0-9_-]+;/);
  for (const flag of ['Path=/', 'HttpOnly', 'Secure', 'SameSite=Lax']) assert.ok(set.includes(flag), flag);

  const token = tokenOf(cookieOf(response));
  assert.equal(storedAnywhere(state.database, token), false, 'the session token is never stored, only its hash');
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM sessions'), 1);
  assert.notEqual(state.database.prepare('SELECT email_verified_at FROM users').get().email_verified_at, null);
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM codes'), 0, 'a used code is removed');
});

test('a wrong code counts, and locks after five tries even when the right one follows', async () => {
  const state = makeEnv();
  await call(state, 'POST', '/account/sign-up', { form: { email: 'reader@example.com', password: PASSWORD, 'cf-turnstile-response': 't' } });
  const right = lastCode();
  const wrong = right === '000000' ? '111111' : '000000';

  for (let i = 0; i < 4; i++) {
    const response = await call(state, 'POST', '/account/verify', { form: { email: 'reader@example.com', code: wrong } });
    assert.equal(response.status, 400);
  }
  assert.equal(state.database.prepare('SELECT attempts FROM codes').get().attempts, 4);

  const fifth = await call(state, 'POST', '/account/verify', { form: { email: 'reader@example.com', code: wrong } });
  assert.equal(fifth.status, 400);
  const locked = await call(state, 'POST', '/account/verify', { form: { email: 'reader@example.com', code: right } });
  assert.equal(locked.status, 400, 'the right code no longer works once locked');
  assert.equal(locked.headers.get('set-cookie'), null);
});

test('an expired code is refused', async () => {
  const state = makeEnv();
  await call(state, 'POST', '/account/sign-up', { form: { email: 'reader@example.com', password: PASSWORD, 'cf-turnstile-response': 't' } });
  state.database.exec('UPDATE codes SET expires_at = 0');
  const response = await call(state, 'POST', '/account/verify', { form: { email: 'reader@example.com', code: lastCode() } });
  assert.equal(response.status, 400);
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM codes'), 0);
});

test('a new code replaces the one sent before it', async () => {
  const state = makeEnv();
  await call(state, 'POST', '/account/sign-up', { form: { email: 'reader@example.com', password: PASSWORD, 'cf-turnstile-response': 't' } });
  const first = lastCode();
  await call(state, 'POST', '/account/verify/resend', { form: { email: 'reader@example.com' } });
  assert.equal(mail.length, 2);
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM codes'), 1);
  if (first !== lastCode()) {
    const stale = await call(state, 'POST', '/account/verify', { form: { email: 'reader@example.com', code: first } });
    assert.equal(stale.status, 400);
  }
});

test('sign-in refuses a wrong password in the same words as an unknown address', async () => {
  const state = makeEnv();
  await signedUpAndVerified(state);
  const wrong = await call(state, 'POST', '/account/sign-in', { form: { email: 'reader@example.com', password: 'not the password', 'cf-turnstile-response': 't' } });
  const unknown = await call(state, 'POST', '/account/sign-in', { form: { email: 'nobody@example.com', password: PASSWORD, 'cf-turnstile-response': 't' } });
  assert.equal(wrong.status, 401);
  assert.equal(unknown.status, 401);
  assert.equal(await wrong.text(), await unknown.text(), 'the same page for both');
  assert.equal(wrong.headers.get('set-cookie'), null);
});

test('an unverified account signs in only after its email is verified; the code is sent again', async () => {
  const state = makeEnv();
  await call(state, 'POST', '/account/sign-up', { form: { email: 'reader@example.com', password: PASSWORD, 'cf-turnstile-response': 't' } });
  const response = await call(state, 'POST', '/account/sign-in', { form: { email: 'reader@example.com', password: PASSWORD, 'cf-turnstile-response': 't' } });
  assert.equal(response.status, 303);
  assert.ok(response.headers.get('location').includes('notice=unverified'));
  assert.equal(response.headers.get('set-cookie'), null);
  assert.equal(mail.length, 2);
});

test('sign-in and sign-out start and end a session, and the sign-out clears the cookie', async () => {
  const state = makeEnv();
  await signedUpAndVerified(state);
  const signedIn = await call(state, 'POST', '/account/sign-in', { form: { email: 'reader@example.com', password: PASSWORD, 'cf-turnstile-response': 't' } });
  assert.equal(signedIn.status, 303);
  const cookie = cookieOf(signedIn);
  assert.equal((await call(state, 'GET', '/account', { cookie })).status, 200);

  const out = await call(state, 'POST', '/account/sign-out', { cookie });
  assert.equal(out.status, 303);
  assert.match(out.headers.get('set-cookie'), /Max-Age=0/);
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM sessions WHERE token_hash IS NOT NULL'), 1, 'the other session stays');
  const after = await call(state, 'GET', '/account', { cookie });
  assert.equal(after.status, 303, 'a signed-out cookie gets nothing');
  assert.equal(after.headers.get('location'), '/account/sign-in');
});

test('a password reset sends one link, works once, and signs out every other session', async () => {
  const state = makeEnv();
  const { email, cookie } = await signedUpAndVerified(state);
  const other = cookieOf(await call(state, 'POST', '/account/sign-in', { form: { email, password: PASSWORD, 'cf-turnstile-response': 't' } }));
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM sessions'), 2);

  const asked = await call(state, 'POST', '/account/reset', { form: { email, 'cf-turnstile-response': 't' } });
  assert.equal(asked.status, 303);
  assert.equal(mail.length, 2);
  const link = new URL(lastLink());
  assert.equal(link.pathname, '/account/reset/complete');
  const token = link.searchParams.get('token');

  const form = await call(state, 'GET', `/account/reset/complete?token=${token}`);
  assert.equal(form.status, 200);

  const changed = await call(state, 'POST', '/account/reset/complete', {
    form: { token, password: 'a new long password', 'cf-turnstile-response': 't' },
  });
  assert.equal(changed.status, 303);
  assert.ok(changed.headers.get('location').includes('notice=reset-done'));
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM sessions'), 0, 'every session is signed out');
  assert.equal(storedAnywhere(state.database, token), false, 'the reset link is never stored, only its hash');

  const reused = await call(state, 'POST', '/account/reset/complete', { form: { token, password: 'yet another password', 'cf-turnstile-response': 't' } });
  assert.equal(reused.status, 400, 'a link works once');
  assert.equal((await call(state, 'GET', '/account', { cookie })).status, 303);
  assert.equal((await call(state, 'GET', '/account', { cookie: other })).status, 303);

  const old = await call(state, 'POST', '/account/sign-in', { form: { email, password: PASSWORD, 'cf-turnstile-response': 't' } });
  assert.equal(old.status, 401);
  const fresh = await call(state, 'POST', '/account/sign-in', { form: { email, password: 'a new long password', 'cf-turnstile-response': 't' } });
  assert.equal(fresh.status, 303);
});

test('a reset for an address with no account is answered the same, and sends nothing', async () => {
  const state = makeEnv();
  const response = await call(state, 'POST', '/account/reset', { form: { email: 'nobody@example.com', 'cf-turnstile-response': 't' } });
  assert.equal(response.status, 303);
  assert.ok(response.headers.get('location').includes('notice=reset-sent'));
  assert.equal(mail.length, 0);
});

test('an expired reset link is refused', async () => {
  const state = makeEnv();
  const { email } = await signedUpAndVerified(state);
  await call(state, 'POST', '/account/reset', { form: { email, 'cf-turnstile-response': 't' } });
  const token = new URL(lastLink()).searchParams.get('token');
  state.database.exec('UPDATE reset_tokens SET expires_at = 0');
  const response = await call(state, 'POST', '/account/reset/complete', { form: { token, password: 'a new long password', 'cf-turnstile-response': 't' } });
  assert.equal(response.status, 400);
  assert.equal((await call(state, 'GET', `/account/reset/complete?token=${token}`)).status, 400);
});

test('deleting the account removes its user row, sessions, codes and reset links', async () => {
  const state = makeEnv();
  const { email, cookie } = await signedUpAndVerified(state);
  await call(state, 'POST', '/account/reset', { form: { email, 'cf-turnstile-response': 't' } });
  await call(state, 'POST', '/account/verify/resend', { form: { email } });
  const user = state.database.prepare('SELECT id FROM users').get();
  assert.ok(count(state.database, 'SELECT count(*) AS n FROM reset_tokens WHERE user_id = ?', user.id) > 0);

  const wrong = await call(state, 'POST', '/account/delete', { form: { password: 'not the password' }, cookie });
  assert.equal(wrong.status, 401);
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM users'), 1, 'a wrong password deletes nothing');

  const gone = await call(state, 'POST', '/account/delete', { form: { password: PASSWORD }, cookie });
  assert.equal(gone.status, 303);
  assert.match(gone.headers.get('set-cookie'), /Max-Age=0/);
  for (const table of ['users', 'sessions', 'codes', 'reset_tokens']) {
    assert.equal(count(state.database, `SELECT count(*) AS n FROM ${table}`), 0, table);
  }
});

test('a user is limited per email: the tries past the limit are refused', async () => {
  const state = makeEnv();
  await signedUpAndVerified(state);
  const statuses = [];
  for (let i = 0; i < 11; i++) {
    const response = await call(state, 'POST', '/account/sign-in', { form: { email: 'reader@example.com', password: 'not the password', 'cf-turnstile-response': 't' } });
    statuses.push(response.status);
  }
  assert.deepEqual(statuses.slice(0, 10), Array(10).fill(401));
  assert.equal(statuses[10], 429);
});

test('a form without a passing Turnstile check creates nothing', async () => {
  const state = makeEnv();
  turnstile = { success: false };
  const refused = await call(state, 'POST', '/account/sign-up', { form: { email: 'reader@example.com', password: PASSWORD, 'cf-turnstile-response': 't' } });
  assert.equal(refused.status, 403);
  const missing = await call(state, 'POST', '/account/sign-up', { form: { email: 'reader@example.com', password: PASSWORD } });
  assert.equal(missing.status, 403);
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM users'), 0);
  assert.equal(mail.length, 0);
});

test('a form from another origin is refused, and so is a request without the configuration', async () => {
  const state = makeEnv();
  const foreign = await call(state, 'POST', '/account/sign-up', {
    form: { email: 'reader@example.com', password: PASSWORD, 'cf-turnstile-response': 't' },
    origin: 'https://evil.example',
  });
  assert.equal(foreign.status, 403);
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM users'), 0);

  const unset = { ...state.env, RESEND_API_KEY: '' };
  assert.equal((await call(state, 'GET', '/account/sign-in', { env: unset })).status, 503);
});

test('the account pages are not visits; the site\'s own pages are', async () => {
  const state = makeEnv();
  await call(state, 'GET', '/account/sign-in');
  await call(state, 'GET', '/account/sign-up');
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM visits'), 0);
  await call(state, 'GET', '/community');
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM visits'), 1);
});

test('an account made with an older, lower count is raised to the current one at sign-in', async () => {
  const state = makeEnv();
  const old = await hashPassword(PASSWORD, 1000);
  state.database.prepare(
    'INSERT INTO users (email, pw_alg, pw_iter, pw_salt, pw_hash, email_verified_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
  ).run('reader@example.com', old.pw_alg, old.pw_iter, old.pw_salt, old.pw_hash, 1, 1);
  const response = await call(state, 'POST', '/account/sign-in', { form: { email: 'reader@example.com', password: PASSWORD, 'cf-turnstile-response': 't' } });
  assert.equal(response.status, 303);
  assert.equal(state.database.prepare('SELECT pw_iter FROM users').get().pw_iter, 100000);
  const again = await call(state, 'POST', '/account/sign-in', { form: { email: 'reader@example.com', password: PASSWORD, 'cf-turnstile-response': 't' } });
  assert.equal(again.status, 303, 'the raised hash still signs in');
});

test('the daily clean-up removes expired sessions and accounts never verified', async () => {
  const state = makeEnv();
  const { email } = await signedUpAndVerified(state);
  state.database.exec('UPDATE sessions SET expires_at = 0');
  state.database.prepare(
    'INSERT INTO users (email, pw_alg, pw_iter, pw_salt, pw_hash, email_verified_at, created_at) VALUES (?, ?, ?, ?, ?, NULL, ?)',
  ).run('stale@example.com', 'pbkdf2-sha256', 1, 'c2FsdA', 'aGFzaA', Date.now() - 8 * 86400000);

  const waits = [];
  await worker.scheduled({}, state.env, { waitUntil: (promise) => waits.push(promise) });
  await Promise.all(waits);

  assert.equal(count(state.database, 'SELECT count(*) AS n FROM sessions'), 0);
  assert.equal(count(state.database, "SELECT count(*) AS n FROM users WHERE email = 'stale@example.com'"), 0);
  assert.equal(count(state.database, 'SELECT count(*) AS n FROM users WHERE email = ?', email), 1, 'a verified account stays');
});
