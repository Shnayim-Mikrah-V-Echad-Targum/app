// Run with: node --test tool/cloudflare/test/suite.test.mjs
// The account page's password, devices and streak, the link from the app to
// the site, and the admin panel's owner, on real SQLite behind D1's calls
// (d1.mjs). Resend and Turnstile are stubbed, and the clock is the test's.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { afterEach, beforeEach, test } from 'node:test';

import worker from '../src/worker.js';
import { deviceName, deviceOf } from '../src/devices.js';
import { d1 } from './d1.mjs';

const SITE = 'https://shnayimmikrah.org';
const START = Date.UTC(2026, 9, 25, 12);
const CHROME_ANDROID = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36';
const FIREFOX_WINDOWS = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Gecko/20100101 Firefox/131.0';

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
let realNow;
let clock;

beforeEach(() => {
  mail = [];
  clock = START;
  realNow = Date.now;
  Date.now = () => clock;
  realFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    const target = String(url);
    if (target === 'https://api.resend.com/emails') {
      mail.push(JSON.parse(init.body));
      return new Response('{}', { status: 200 });
    }
    if (target.startsWith('https://challenges.cloudflare.com/')) {
      return new Response(JSON.stringify({ success: true }), { headers: { 'content-type': 'application/json' } });
    }
    throw new Error(`unexpected request in a test: ${url}`);
  };
});

afterEach(() => {
  globalThis.fetch = realFetch;
  Date.now = realNow;
});

async function send(state, method, path, { cookie, form, json, token, ua = CHROME_ANDROID, headers: extra = {} } = {}) {
  const headers = { 'user-agent': ua, 'cf-connecting-ip': '203.0.113.9', 'accept-language': 'en', ...extra };
  if (cookie) headers.cookie = cookie;
  if (token) headers.authorization = `Bearer ${token}`;
  const init = { method, headers, redirect: 'manual' };
  if (method !== 'GET') {
    headers.origin = SITE;
    headers['sec-fetch-site'] = 'same-origin';
  }
  if (form !== undefined) {
    headers['content-type'] = 'application/x-www-form-urlencoded';
    init.body = new URLSearchParams(form).toString();
  }
  if (json !== undefined) {
    headers['content-type'] = 'application/json';
    init.body = JSON.stringify(json);
  }
  const request = new Request(`${SITE}${path}`, init);
  Object.defineProperty(request, 'cf', { value: { country: 'IL', asn: 8551, threatScore: 2 } });
  return worker.fetch(request, state.env, { waitUntil: () => {} });
}

function lastCode() {
  return mail.at(-1).text.match(/Your code is (\d{6})/)[1];
}

function sessionOf(response) {
  const all = response.headers.getSetCookie?.() ?? [response.headers.get('set-cookie')];
  return all.find((c) => c?.startsWith('__Host-sm_session='))?.split(';')[0] ?? null;
}

// Signs in on the site with an emailed code; the session cookie.
async function siteSignIn(state, email, ua = CHROME_ANDROID) {
  await send(state, 'POST', '/account/sign-in/email', { form: { email, 'cf-turnstile-response': 't' }, ua });
  const response = await send(state, 'POST', '/account/sign-in/code', { form: { email, code: lastCode() }, ua });
  assert.equal(response.status, 303);
  return sessionOf(response);
}

// Signs in as the app does; its token and id.
async function appSignIn(state, email, platform = 'android') {
  const app = { ua: 'Dart/3.9 (dart:io)', headers: { 'x-app-platform': platform } };
  await send(state, 'POST', '/api/auth/code', { json: { email }, ...app });
  const response = await send(state, 'POST', '/api/auth/verify', { json: { email, code: lastCode() }, ...app });
  const body = await response.json();
  return { token: body.token, id: body.user.id };
}

function role(state, email, name) {
  state.database.prepare('INSERT INTO roles (email, role, granted_at) VALUES (?, ?, 0)').run(email, name);
}

function action(state, cookie, form) {
  return send(state, 'POST', '/account/admin/action', { cookie, form });
}

test('a device is named coarsely, never by its whole user agent', () => {
  const named = (headers) => deviceOf(new Request(SITE, { headers }));
  assert.equal(named({ 'user-agent': CHROME_ANDROID }), 'browser|Chrome|Android');
  assert.equal(named({ 'user-agent': FIREFOX_WINDOWS }), 'browser|Firefox|Windows');
  assert.equal(named({ 'user-agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1' }), 'browser|Safari|iOS');
  assert.equal(named({ 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36 Edg/130.0' }), 'browser|Edge|Windows');
  assert.equal(named({ 'user-agent': 'Dart/3.9 (dart:io)', 'x-app-platform': 'windows' }), 'app||Windows');
  assert.equal(named({ 'user-agent': 'Dart/3.9 (dart:io)' }), 'app||');
  assert.equal(deviceName('browser|Chrome|Android', 'en'), 'Chrome on Android');
  assert.equal(deviceName('app||Windows', 'en'), 'The app on Windows');
  assert.equal(deviceName('app||Windows', 'he'), 'האפליקציה ב־Windows');
  assert.equal(deviceName(null, 'en'), 'A device');
});

test('the account page lists the devices signed in, and signs one, or all the others, out', async () => {
  const state = makeEnv();
  const phone = await siteSignIn(state, 'reader@example.com');
  clock += 60000;
  const laptop = await siteSignIn(state, 'reader@example.com', FIREFOX_WINDOWS);
  const app = await appSignIn(state, 'reader@example.com', 'ios');

  const page = await (await send(state, 'GET', '/account', { cookie: laptop, ua: FIREFOX_WINDOWS })).text();
  assert.match(page, /Signed-in devices/);
  assert.match(page, /Chrome on Android/);
  assert.match(page, /Firefox on Windows \(this device\)/);
  assert.match(page, /The app on iOS/);
  assert.doesNotMatch(page, /Pixel 8/);

  const phoneId = state.database.prepare("SELECT rowid AS id FROM sessions WHERE device = 'browser|Chrome|Android'").get().id;
  const one = await send(state, 'POST', '/account/devices/sign-out', { cookie: laptop, form: { id: String(phoneId) }, ua: FIREFOX_WINDOWS });
  assert.equal(one.headers.get('location'), '/account?notice=device-signed-out');
  assert.equal((await send(state, 'GET', '/account', { cookie: phone })).status, 303);
  // Another account's device is not this one's to sign out.
  const other = await siteSignIn(state, 'other@example.com');
  const otherId = state.database.prepare("SELECT s.rowid AS id FROM sessions s JOIN users u ON u.id = s.user_id WHERE u.email = 'other@example.com'").get().id;
  await send(state, 'POST', '/account/devices/sign-out', { cookie: laptop, form: { id: String(otherId) }, ua: FIREFOX_WINDOWS });
  assert.equal((await send(state, 'GET', '/account', { cookie: other })).status, 200);

  const rest = await send(state, 'POST', '/account/devices/sign-out', { cookie: laptop, form: { others: 'yes' }, ua: FIREFOX_WINDOWS });
  assert.equal(rest.headers.get('location'), '/account?notice=devices-signed-out');
  assert.equal((await send(state, 'GET', '/api/me', { token: app.token })).status, 401);
  assert.equal((await send(state, 'GET', '/account', { cookie: laptop, ua: FIREFOX_WINDOWS })).status, 200);

  // This device, from its own list: signed out, and its cookie cleared.
  const self = state.database.prepare("SELECT rowid AS id FROM sessions WHERE device = 'browser|Firefox|Windows'").get().id;
  const out = await send(state, 'POST', '/account/devices/sign-out', { cookie: laptop, form: { id: String(self) }, ua: FIREFOX_WINDOWS });
  assert.equal(out.headers.get('location'), '/account/sign-in?notice=signed-out');
  assert.match(out.headers.get('set-cookie'), /Max-Age=0/);
});

test('an account made by code adds a password soon after signing in, and a password is changed with the old one', async () => {
  const state = makeEnv();
  const cookie = await siteSignIn(state, 'reader@example.com');
  const other = await siteSignIn(state, 'reader@example.com', FIREFOX_WINDOWS);
  const fresh = await (await send(state, 'GET', '/account', { cookie })).text();
  assert.match(fresh, /No password yet/);
  assert.match(fresh, /Add a password/);

  const short = await send(state, 'POST', '/account/password', { cookie, form: { new_password: 'short' } });
  assert.equal(short.status, 400);
  const added = await send(state, 'POST', '/account/password', { cookie, form: { new_password: 'a long new password' } });
  assert.equal(added.headers.get('location'), '/account?notice=password-added');
  assert.equal(state.database.prepare("SELECT pw_alg FROM users WHERE email = 'reader@example.com'").get().pw_alg, 'pbkdf2-sha256');
  // The other device is signed out; this one stays.
  assert.equal((await send(state, 'GET', '/account', { cookie: other, ua: FIREFOX_WINDOWS })).status, 303);
  const after = await (await send(state, 'GET', '/account?notice=password-added', { cookie })).text();
  assert.match(after, /Your password is added/);
  assert.match(after, /Current password/);

  // It signs in with the password now.
  const signIn = await send(state, 'POST', '/account/sign-in', { form: { email: 'reader@example.com', password: 'a long new password', 'cf-turnstile-response': 't' } });
  assert.equal(signIn.status, 303);
  assert.ok(sessionOf(signIn));

  const wrong = await send(state, 'POST', '/account/password', { cookie, form: { password: 'not the password', new_password: 'another long password' } });
  assert.equal(wrong.status, 401);
  assert.match(await wrong.text(), /The current password is wrong/);
  const changed = await send(state, 'POST', '/account/password', { cookie, form: { password: 'a long new password', new_password: 'another long password' } });
  assert.equal(changed.headers.get('location'), '/account?notice=password-changed');
});

test('a password is added only within 15 minutes of signing in', async () => {
  const state = makeEnv();
  const cookie = await siteSignIn(state, 'reader@example.com');
  clock += 16 * 60000;
  const page = await (await send(state, 'GET', '/account', { cookie })).text();
  assert.doesNotMatch(page, /Add a password/);
  assert.match(page, /within 15 minutes of signing in/);
  const stale = await send(state, 'POST', '/account/password', { cookie, form: { new_password: 'a long new password' } });
  assert.equal(stale.status, 403);
  assert.equal(state.database.prepare("SELECT pw_alg FROM users WHERE email = 'reader@example.com'").get().pw_alg, 'none');
});

test('the account page shows the streak the app backed up, with the fire', async () => {
  const state = makeEnv();
  const app = await appSignIn(state, 'reader@example.com');
  const cookie = await siteSignIn(state, 'reader@example.com');
  assert.match(await (await send(state, 'GET', '/account', { cookie })).text(), /Turn on “Back up progress”/);

  await send(state, 'PUT', '/api/progress', { token: app.token, json: { data: { format: 1, streak: { days: 12, weeks: 3, longestDays: 20, longestWeeks: 5, asOf: '2026-10-25' } } } });
  const page = await (await send(state, 'GET', '/account', { cookie })).text();
  assert.match(page, /<span class="flame" aria-hidden="true">🔥<\/span>/);
  assert.match(page, /<strong>12<\/strong> days on track/);
  assert.match(page, /Parsha streak: 3 weeks/);
  assert.match(page, /as of 2026-10-25/);
  const he = await (await send(state, 'GET', '/account?lang=he', { cookie })).text();
  assert.match(he, /<strong>12<\/strong> ימים לפי התוכנית/);
  assert.match(he, /רצף פרשות: 3 שבועות/);

  // One day, and a backup this can't read, say so plainly.
  await send(state, 'PUT', '/api/progress', { token: app.token, json: { data: { streak: { days: 1, weeks: 1, asOf: 'yesterday' } } } });
  const one = await (await send(state, 'GET', '/account', { cookie })).text();
  assert.match(one, /<strong>1<\/strong> day on track/);
  assert.match(one, /Parsha streak: 1 week/);
  assert.doesNotMatch(one, /as of/);
  await send(state, 'PUT', '/api/progress', { token: app.token, json: { data: { streak: { days: '<b>', weeks: 2 } } } });
  assert.match(await (await send(state, 'GET', '/account', { cookie })).text(), /Turn on “Back up progress”/);
});

test('a link from the app signs the browser in, once, after asking, and only to the account pages', async () => {
  const state = makeEnv();
  role(state, 'admin@example.com', 'admin');
  const app = await appSignIn(state, 'admin@example.com');
  assert.equal((await send(state, 'POST', '/api/handoff', { json: { next: '/account/admin' } })).status, 401);
  assert.equal((await send(state, 'POST', '/api/handoff', { token: app.token, json: { next: 'https://evil.example/' } })).status, 400);
  const made = await send(state, 'POST', '/api/handoff', { token: app.token, json: { next: '/account/admin' } });
  const { url } = await made.json();
  assert.match(url, /^https:\/\/shnayimmikrah\.org\/account\/handoff\?t=[A-Za-z0-9_-]+$/);
  const token = new URL(url).searchParams.get('t');

  // Opening it asks first: nothing is signed in by a GET.
  const asked = await send(state, 'GET', `/account/handoff?t=${token}`);
  assert.equal(asked.status, 200);
  assert.equal(sessionOf(asked), null);
  assert.match(await asked.text(), /The app is signed in as <strong>admin@example\.com<\/strong>/);

  const went = await send(state, 'POST', '/account/handoff', { form: { token } });
  assert.equal(went.status, 303);
  assert.equal(went.headers.get('location'), '/account/admin');
  const cookie = sessionOf(went);
  assert.equal((await send(state, 'GET', '/account/admin', { cookie })).status, 200);

  // Once only, and not after five minutes.
  assert.equal((await send(state, 'POST', '/account/handoff', { form: { token } })).status, 410);
  const later = (await (await send(state, 'POST', '/api/handoff', { token: app.token, json: {} })).json()).url;
  clock += 6 * 60000;
  const expired = await send(state, 'GET', new URL(later).pathname + new URL(later).search);
  assert.equal(expired.status, 410);
  assert.match(await expired.text(), /Open it again from the app/);
});

test('the owner names and removes admins, and acts on their accounts; no admin acts on the owner', async () => {
  const state = makeEnv();
  role(state, 'owner@example.com', 'owner');
  role(state, 'admin@example.com', 'admin');
  const owner = await siteSignIn(state, 'owner@example.com');
  const admin = await siteSignIn(state, 'admin@example.com');
  const reader = await appSignIn(state, 'reader@example.com');
  const ownerId = state.database.prepare("SELECT id FROM users WHERE email = 'owner@example.com'").get().id;
  const adminId = state.database.prepare("SELECT id FROM users WHERE email = 'admin@example.com'").get().id;

  // The owner has the panel, and sees the staff.
  const overview = await (await send(state, 'GET', '/account/admin', { cookie: owner })).text();
  assert.match(overview, /owner \(super admin\)/);
  assert.match(overview, /Newest accounts/);
  assert.match(await (await send(state, 'GET', '/account', { cookie: owner })).text(), /site owner \(super admin\)/);

  // An admin can't name admins, nor act on the owner or another admin.
  assert.match((await action(state, admin, { action: 'grant_admin', target: reader.id, confirm: 'yes' })).headers.get('location'), /error=forbidden/);
  assert.match((await action(state, admin, { action: 'sign_out_everywhere', target: String(ownerId) })).headers.get('location'), /error=forbidden/);
  assert.match((await action(state, admin, { action: 'set_trust', target: String(ownerId), reason: '0' })).headers.get('location'), /error=forbidden/);
  const ownerPage = await (await send(state, 'GET', `/account/admin/accounts/${ownerId}`, { cookie: admin })).text();
  assert.match(ownerPage, /The owner’s account: no actions here/);

  // The owner names an admin, with the box ticked.
  const unticked = await action(state, owner, { action: 'grant_admin', target: reader.id, back: `/account/admin/accounts/${reader.id}` });
  assert.match(unticked.headers.get('location'), /error=not_confirmed/);
  await action(state, owner, { action: 'grant_admin', target: reader.id, confirm: 'yes' });
  assert.equal(state.database.prepare("SELECT role FROM roles WHERE email = 'reader@example.com'").get().role, 'admin');
  // A moderator is promoted, not refused.
  role(state, 'mod@example.com', 'moderator');
  const mod = await appSignIn(state, 'mod@example.com');
  await action(state, owner, { action: 'grant_admin', target: mod.id, confirm: 'yes' });
  assert.equal(state.database.prepare("SELECT role FROM roles WHERE email = 'mod@example.com'").get().role, 'admin');

  // The owner signs an admin out, and removes the role.
  await action(state, owner, { action: 'sign_out_everywhere', target: String(adminId) });
  assert.equal((await send(state, 'GET', '/account/admin', { cookie: admin })).status, 303);
  await action(state, owner, { action: 'revoke_admin', target: String(adminId) });
  assert.equal(state.database.prepare("SELECT count(*) AS n FROM roles WHERE email = 'admin@example.com'").get().n, 0);
  // But never the owner's own, and an admin's account is not deleted from here.
  assert.match((await action(state, owner, { action: 'revoke_admin', target: String(ownerId) })).headers.get('location'), /error=forbidden/);
  assert.match((await action(state, owner, { action: 'delete_account', target: reader.id, confirm: 'yes' })).headers.get('location'), /error=forbidden/);
  assert.equal(state.database.prepare("SELECT role FROM roles WHERE email = 'owner@example.com'").get().role, 'owner');

  const log = await (await send(state, 'GET', '/account/admin/log', { cookie: owner })).text();
  for (const done of ['grant_admin', 'revoke_admin', 'sign_out_everywhere']) assert.match(log, new RegExp(done));
});

test('an admin renames a member, sees their devices and streak, and signs one device out', async () => {
  const state = makeEnv();
  role(state, 'admin@example.com', 'admin');
  const admin = await siteSignIn(state, 'admin@example.com');
  const reader = await appSignIn(state, 'reader@example.com', 'windows');
  await siteSignIn(state, 'reader@example.com');
  await send(state, 'PUT', '/api/progress', { token: reader.token, json: { data: { streak: { days: 4, weeks: 2, asOf: '2026-10-24' } } } });
  const back = `/account/admin/accounts/${reader.id}`;

  const page = await (await send(state, 'GET', back, { cookie: admin })).text();
  assert.match(page, /The app on Windows/);
  assert.match(page, /Chrome on Android/);
  assert.match(page, /🔥 4 days on track, parsha streak 2 weeks \(as of 2026-10-24\)/);

  const renamed = await action(state, admin, { action: 'rename_user', target: reader.id, name: 'Reuven', back });
  assert.equal(renamed.headers.get('location'), `${back}?done=rename_user`);
  assert.equal(state.database.prepare('SELECT display_name FROM profiles WHERE user_id = ?').get(reader.id).display_name, 'Reuven');
  assert.match((await action(state, admin, { action: 'rename_user', target: reader.id, name: 'x', back })).headers.get('location'), /error=invalid_name/);

  const appSession = state.database.prepare("SELECT rowid AS id FROM sessions WHERE device = 'app||Windows'").get().id;
  await action(state, admin, { action: 'end_session', target: reader.id, session: String(appSession), back });
  assert.equal((await send(state, 'GET', '/api/me', { token: reader.token })).status, 401);
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM sessions WHERE user_id = ?').get(reader.id).n, 1);
});
