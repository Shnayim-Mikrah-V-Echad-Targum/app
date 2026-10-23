// Run with: node --test tool/cloudflare/test/admin.test.mjs
// The admin panel (src/admin.js), on real SQLite behind D1's calls (d1.mjs).
// Members sign in through the app's API, as they do; Resend is stubbed.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { afterEach, beforeEach, test } from 'node:test';

import worker from '../src/worker.js';
import { d1 } from './d1.mjs';

const SITE = 'https://shnayimmikrah.org';

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
      ACCOUNTS_EMAIL_FROM: 'accounts@shnayimmikrah.org',
    },
  };
}

let mail;
let realFetch;

beforeEach(() => {
  mail = [];
  realFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    if (String(url) === 'https://api.resend.com/emails') {
      mail.push(JSON.parse(init.body));
      return new Response('{}', { status: 200 });
    }
    throw new Error(`unexpected request in a test: ${url}`);
  };
});

afterEach(() => {
  globalThis.fetch = realFetch;
});

async function send(state, method, path, { cookie, json, form, origin = SITE, fetchSite = 'same-origin', token } = {}) {
  const headers = { 'user-agent': 'Mozilla/5.0', 'cf-connecting-ip': '203.0.113.9', 'sec-fetch-dest': 'document' };
  if (cookie) headers.cookie = cookie;
  if (token) headers.authorization = `Bearer ${token}`;
  const init = { method, headers };
  if (method !== 'GET') {
    headers.origin = origin;
    headers['sec-fetch-site'] = fetchSite;
  }
  if (json !== undefined) {
    headers['content-type'] = 'application/json';
    init.body = JSON.stringify(json);
  }
  if (form !== undefined) {
    headers['content-type'] = 'application/x-www-form-urlencoded';
    init.body = new URLSearchParams(form).toString();
  }
  const request = new Request(`${SITE}${path}`, init);
  Object.defineProperty(request, 'cf', { value: { country: 'IL', asn: 8551, threatScore: 2 } });
  const waits = [];
  const response = await worker.fetch(request, state.env, { waitUntil: (promise) => waits.push(promise) });
  await Promise.all(waits);
  return response;
}

// Signs in through the app's API, and returns the cookie, the token and the id.
async function signIn(state, email) {
  await send(state, 'POST', '/api/auth/code', { json: { email } });
  const code = mail.at(-1).text.match(/Your code is (\d{6})/)[1];
  const response = await send(state, 'POST', '/api/auth/verify', { json: { email, code } });
  const body = await response.json();
  return { cookie: response.headers.get('set-cookie').split(';')[0], token: body.token, id: body.user.id };
}

async function asAdmin(state) {
  state.database.prepare("INSERT INTO roles (email, role, granted_at) VALUES ('admin@example.com', 'admin', 0)").run();
  return signIn(state, 'admin@example.com');
}

function action(state, cookie, form, opts = {}) {
  return send(state, 'POST', '/account/admin/action', { cookie, form, ...opts });
}

test('the panel is for admins alone', async () => {
  const state = makeEnv();
  const signedOut = await send(state, 'GET', '/account/admin');
  assert.equal(signedOut.status, 303);
  assert.equal(signedOut.headers.get('location'), '/account/sign-in');

  state.database.prepare("INSERT INTO roles (email, role, granted_at) VALUES ('mod@example.com', 'moderator', 0)").run();
  for (const email of ['reader@example.com', 'mod@example.com']) {
    const { cookie } = await signIn(state, email);
    const refused = await send(state, 'GET', '/account/admin', { cookie });
    assert.equal(refused.status, 403, email);
    assert.match(await refused.text(), /for the site’s administrators/);
    assert.equal((await action(state, cookie, { action: 'ban_user', target: '1' })).status, 403);
  }

  const admin = await asAdmin(state);
  const page = await send(state, 'GET', '/account/admin', { cookie: admin.cookie });
  assert.equal(page.status, 200);
  assert.equal(page.headers.get('cache-control'), 'no-store');
  assert.match(page.headers.get('content-security-policy'), /frame-ancestors 'none'/);
  const html = await page.text();
  assert.match(html, /<span class="n">3<\/span><span>accounts<\/span>/);
  // The panel is no visit, and the account page links to it for an admin.
  assert.equal(state.database.prepare("SELECT count(*) AS n FROM visits WHERE path LIKE '%admin%'").get().n, 0);
  // /admin leads to it.
  const shortcut = await send(state, 'GET', '/admin/accounts?q=a');
  assert.equal(shortcut.status, 302);
  assert.equal(shortcut.headers.get('location'), `${SITE}/account/admin/accounts?q=a`);
  assert.match(await (await send(state, 'GET', '/account', { cookie: admin.cookie })).text(), /href="\/account\/admin"/);
  assert.doesNotMatch(await (await send(state, 'GET', '/account', { cookie: (await signIn(state, 'other@example.com')).cookie })).text(), /href="\/account\/admin"/);
});

test('the accounts are listed, searched and shown, with what members wrote escaped', async () => {
  const state = makeEnv();
  const admin = await asAdmin(state);
  const reader = await signIn(state, 'reader@example.com');
  await send(state, 'PUT', '/api/profile', { token: reader.token, json: { display_name: '<script>x</script>' } });
  await signIn(state, 'other@example.com');

  const list = await (await send(state, 'GET', '/account/admin/accounts', { cookie: admin.cookie })).text();
  assert.match(list, /reader@example\.com/);
  assert.match(list, /other@example\.com/);
  assert.match(list, /&lt;script&gt;x&lt;\/script&gt;/);
  assert.doesNotMatch(list, /<script>x/);
  const found = await (await send(state, 'GET', '/account/admin/accounts?q=reader', { cookie: admin.cookie })).text();
  assert.match(found, /reader@example\.com/);
  assert.doesNotMatch(found, /other@example\.com/);
  // A search for a LIKE wildcard finds no one by it.
  assert.doesNotMatch(await (await send(state, 'GET', '/account/admin/accounts?q=%25', { cookie: admin.cookie })).text(), /reader@example\.com/);

  const one = await (await send(state, 'GET', `/account/admin/accounts/${reader.id}`, { cookie: admin.cookie })).text();
  assert.match(one, /none \(made in the app, by code\)/);
  assert.match(one, /Make moderator/);
  assert.match(one, /Delete account and all it posted/);
  assert.equal((await send(state, 'GET', '/account/admin/accounts/999', { cookie: admin.cookie })).status, 404);
});

test('an admin bans, silences, names moderators and signs members out, and each is logged', async () => {
  const state = makeEnv();
  const admin = await asAdmin(state);
  const reader = await signIn(state, 'reader@example.com');
  const back = `/account/admin/accounts/${reader.id}`;

  const banned = await action(state, admin.cookie, { action: 'ban_user', target: reader.id, back });
  assert.equal(banned.status, 303);
  assert.equal(banned.headers.get('location'), `${back}?done=ban_user`);
  assert.ok(state.database.prepare('SELECT banned_at FROM profiles WHERE user_id = ?').get(reader.id).banned_at);
  assert.match(await (await send(state, 'GET', `${back}?done=ban_user`, { cookie: admin.cookie })).text(), /Done: ban user\./);

  await action(state, admin.cookie, { action: 'grant_moderator', target: reader.id, back });
  assert.equal(state.database.prepare("SELECT role FROM roles WHERE email = 'reader@example.com'").get().role, 'moderator');
  await action(state, admin.cookie, { action: 'set_trust', target: reader.id, reason: '2', back });
  assert.equal(state.database.prepare('SELECT trust_level FROM profiles WHERE user_id = ?').get(reader.id).trust_level, 2);

  await action(state, admin.cookie, { action: 'sign_out_everywhere', target: reader.id, back });
  assert.equal((await send(state, 'GET', '/api/me', { token: reader.token })).status, 401);

  const log = await (await send(state, 'GET', '/account/admin/log', { cookie: admin.cookie })).text();
  for (const done of ['ban_user', 'grant_moderator', 'set_trust', 'sign_out_everywhere']) assert.match(log, new RegExp(done));

  // A form from elsewhere does nothing.
  const foreign = await action(state, admin.cookie, { action: 'unban_user', target: reader.id }, { origin: 'https://evil.example', fetchSite: 'cross-site' });
  assert.equal(foreign.status, 403);
  assert.ok(state.database.prepare('SELECT banned_at FROM profiles WHERE user_id = ?').get(reader.id).banned_at);
  // Back only within the panel.
  const elsewhere = await action(state, admin.cookie, { action: 'unban_user', target: reader.id, back: 'https://evil.example/' });
  assert.equal(elsewhere.headers.get('location'), '/account/admin?done=unban_user');
});

test('deleting an account needs it ticked, and never takes an admin\'s', async () => {
  const state = makeEnv();
  const admin = await asAdmin(state);
  const reader = await signIn(state, 'reader@example.com');
  await send(state, 'POST', '/api/profile/guidelines', { token: reader.token });
  await send(state, 'POST', '/api/threads', { token: reader.token, json: { forum_id: 2, title: 'A question here', body: 'What does it mean?' } });

  const unticked = await action(state, admin.cookie, { action: 'delete_account', target: reader.id, back: `/account/admin/accounts/${reader.id}` });
  assert.match(unticked.headers.get('location'), /error=not_confirmed/);
  const own = await action(state, admin.cookie, { action: 'delete_account', target: admin.id, confirm: 'yes' });
  assert.match(own.headers.get('location'), /error=own_account/);
  state.database.prepare("INSERT INTO roles (email, role, granted_at) VALUES ('second@example.com', 'admin', 0)").run();
  const second = await signIn(state, 'second@example.com');
  assert.match((await action(state, admin.cookie, { action: 'ban_user', target: second.id })).headers.get('location'), /error=forbidden/);
  assert.match((await action(state, admin.cookie, { action: 'delete_account', target: second.id, confirm: 'yes' })).headers.get('location'), /error=forbidden/);

  const deleted = await action(state, admin.cookie, { action: 'delete_account', target: reader.id, confirm: 'yes', back: `/account/admin/accounts/${reader.id}` });
  assert.equal(deleted.headers.get('location'), '/account/admin/accounts?done=delete_account');
  assert.equal(state.database.prepare("SELECT count(*) AS n FROM users WHERE email = 'reader@example.com'").get().n, 0);
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM posts').get().n, 0);
});

test('reports are shown with the post, and settled from the panel', async () => {
  const state = makeEnv();
  const admin = await asAdmin(state);
  const author = await signIn(state, 'author@example.com');
  await send(state, 'POST', '/api/profile/guidelines', { token: author.token });
  const created = await send(state, 'POST', '/api/threads', { token: author.token, json: { forum_id: 2, title: 'A rude thread', body: 'Something rude <b>here</b>' } });
  const threadId = (await created.json()).id;
  const [post] = await (await send(state, 'GET', `/api/threads/${threadId}/posts`)).json();
  const reporter = await signIn(state, 'reporter@example.com');
  await send(state, 'POST', '/api/reports', { token: reporter.token, json: { post_id: post.id, reason: 'disrespect', details: 'Not kind' } });

  const page = await (await send(state, 'GET', '/account/admin/reports', { cookie: admin.cookie })).text();
  assert.match(page, /disrespect/);
  assert.match(page, /Something rude &lt;b&gt;here&lt;\/b&gt;/);
  assert.match(page, /“Not kind”/);
  assert.match(page, new RegExp(`href="/community/thread/${threadId}"`));

  await action(state, admin.cookie, { action: 'hide_post', target: String(post.id), back: '/account/admin/reports' });
  assert.deepEqual(await (await send(state, 'GET', `/api/threads/${threadId}/posts`)).json(), []);
  const reportId = state.database.prepare('SELECT id FROM reports').get().id;
  await action(state, admin.cookie, { action: 'resolve_report', target: String(reportId), back: '/account/admin/reports' });
  assert.match(await (await send(state, 'GET', '/account/admin/reports', { cookie: admin.cookie })).text(), /No open reports/);
  await action(state, admin.cookie, { action: 'delete_post', target: String(post.id), back: '/account/admin/reports' });
  assert.ok(state.database.prepare('SELECT deleted_at FROM posts WHERE id = ?').get(post.id).deleted_at);
});

test('the security page shows the events and the visits, without any address', async () => {
  const state = makeEnv();
  const admin = await asAdmin(state);
  await send(state, 'GET', '/wp-login.php');
  await send(state, 'GET', '/.env');
  await send(state, 'GET', '/community');
  const page = await (await send(state, 'GET', '/account/admin/security', { cookie: admin.cookie })).text();
  assert.match(page, /scanner_path/);
  assert.match(page, /\/wp-login\.php/);
  assert.match(page, /\/community/);
  assert.doesNotMatch(page, /203\.0\.113\.9/);
  const filtered = await (await send(state, 'GET', '/account/admin/security?kind=scanner_path', { cookie: admin.cookie })).text();
  assert.match(filtered, /Latest events: scanner_path/);
  const overview = await (await send(state, 'GET', '/account/admin', { cookie: admin.cookie })).text();
  assert.match(overview, /security events today/);
});
