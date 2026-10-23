// Run with: node --test tool/cloudflare/test/community.test.mjs
// The app's API (src/api.js) and the community's rules (src/community.js), on
// real SQLite behind D1's calls (d1.mjs). Resend is stubbed, and the clock is
// the test's.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { afterEach, beforeEach, test } from 'node:test';

import worker from '../src/worker.js';
import { excerptOf } from '../src/community.js';
import { d1 } from './d1.mjs';

const SITE = 'https://shnayimmikrah.org';
const START = Date.UTC(2026, 9, 20, 12);

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
    if (String(url) === 'https://api.resend.com/emails') {
      mail.push(JSON.parse(init.body));
      return new Response('{}', { status: 200 });
    }
    throw new Error(`unexpected request in a test: ${url}`);
  };
});

afterEach(() => {
  globalThis.fetch = realFetch;
  Date.now = realNow;
});

// A request to the API, as the app makes it: JSON, with a bearer token.
async function api(state, method, path, { json, token, cookie, origin, fetchSite, ip = '203.0.113.9' } = {}) {
  const headers = { 'user-agent': 'Dart/3.9 (dart:io)', 'cf-connecting-ip': ip };
  if (token) headers.authorization = `Bearer ${token}`;
  if (cookie) headers.cookie = cookie;
  if (origin) headers.origin = origin;
  if (fetchSite) headers['sec-fetch-site'] = fetchSite;
  const init = { method, headers };
  if (json !== undefined) {
    headers['content-type'] = 'application/json';
    init.body = JSON.stringify(json);
  }
  const request = new Request(`${SITE}/api${path}`, init);
  Object.defineProperty(request, 'cf', { value: { country: 'IL', asn: 8551, threatScore: 2 } });
  const waits = [];
  const response = await worker.fetch(request, state.env, { waitUntil: (promise) => waits.push(promise) });
  await Promise.all(waits);
  const text = await response.text();
  return { status: response.status, headers: response.headers, body: text ? JSON.parse(text) : null };
}

function lastCode() {
  return mail.at(-1).text.match(/Your code is (\d{6})/)[1];
}

// Signs in as the app does, and returns the token.
async function signIn(state, email) {
  assert.equal((await api(state, 'POST', '/auth/code', { json: { email } })).status, 204);
  const verified = await api(state, 'POST', '/auth/verify', { json: { email, code: lastCode() } });
  assert.equal(verified.status, 200);
  return verified.body.token;
}

// A member who has accepted the guidelines, ready to post.
async function member(state, email) {
  const token = await signIn(state, email);
  assert.equal((await api(state, 'POST', '/profile/guidelines', { token })).status, 204);
  return token;
}

function grant(state, email, role) {
  state.database.prepare('INSERT INTO roles (email, role, granted_at) VALUES (?, ?, 0)').run(email, role);
}

function later(ms) {
  clock += ms;
}

async function newThread(state, token, { forum = 2, title = 'A question on Rashi', body = 'What does Rashi mean here?' } = {}) {
  const created = await api(state, 'POST', '/threads', { token, json: { forum_id: forum, title, body } });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  return created.body.id;
}

test('the app signs in with a code: the account is made, confirmed, and has no password', async () => {
  const state = makeEnv();
  const response = await api(state, 'POST', '/auth/code', { json: { email: 'Reader@Example.com' } });
  assert.equal(response.status, 204);
  assert.equal(mail[0].to[0], 'reader@example.com');
  const verified = await api(state, 'POST', '/auth/verify', { json: { email: 'reader@example.com', code: lastCode() } });
  assert.equal(verified.status, 200);
  assert.equal(verified.body.user.email, 'reader@example.com');
  assert.match(verified.headers.get('set-cookie'), /^__Host-sm_session=/);
  const user = state.database.prepare('SELECT pw_alg, email_verified_at FROM users').get();
  assert.equal(user.pw_alg, 'none');
  assert.ok(user.email_verified_at);
  const me = await api(state, 'GET', '/me', { token: verified.body.token });
  assert.deepEqual(me.body, { user: { id: verified.body.user.id, email: 'reader@example.com' } });
  assert.equal((await api(state, 'GET', '/me', { token: 'not-a-token' })).status, 401);
});

test('a wrong code fails, and locks after five tries', async () => {
  const state = makeEnv();
  await api(state, 'POST', '/auth/code', { json: { email: 'reader@example.com' } });
  const code = lastCode();
  const wrong = code === '000000' ? '111111' : '000000';
  for (let i = 0; i < 5; i++) {
    assert.equal((await api(state, 'POST', '/auth/verify', { json: { email: 'reader@example.com', code: wrong } })).body.error, 'invalid_code');
  }
  assert.equal((await api(state, 'POST', '/auth/verify', { json: { email: 'reader@example.com', code } })).body.error, 'invalid_code');
});

test('codes are limited per email', async () => {
  const state = makeEnv();
  for (let i = 0; i < 5; i++) assert.equal((await api(state, 'POST', '/auth/code', { json: { email: 'reader@example.com' } })).status, 204);
  const sixth = await api(state, 'POST', '/auth/code', { json: { email: 'reader@example.com' } });
  assert.equal(sixth.status, 429);
  assert.equal(sixth.body.error, 'rate_limited');
  assert.equal((await api(state, 'POST', '/auth/code', { json: { email: 'not an email' } })).body.error, 'invalid_email');
});

test('a password set on the site before the address was confirmed is dropped when the app confirms it', async () => {
  const state = makeEnv();
  // Someone else signed up with the address on the site, and never confirmed it.
  state.database.prepare(
    "INSERT INTO users (email, pw_alg, pw_iter, pw_salt, pw_hash, created_at) VALUES ('reader@example.com', 'pbkdf2-sha256', 100000, 'salt', 'hash', 0)",
  ).run();
  await signIn(state, 'reader@example.com');
  assert.equal(state.database.prepare('SELECT pw_alg FROM users').get().pw_alg, 'none');
});

test('a profile is made with a name not yet chosen, which its member can change', async () => {
  const state = makeEnv();
  const token = await signIn(state, 'reader@example.com');
  const profile = await api(state, 'GET', '/profile', { token });
  assert.match(profile.body.display_name, /^user_[0-9a-f]{8}$/);
  assert.equal(profile.body.accepted_terms, false);
  assert.equal(profile.body.is_moderator, false);
  assert.equal((await api(state, 'PUT', '/profile', { token, json: { display_name: '  Rivka  ' } })).status, 204);
  assert.equal((await api(state, 'GET', '/profile', { token })).body.display_name, 'Rivka');

  const other = await signIn(state, 'other@example.com');
  assert.equal((await api(state, 'PUT', '/profile', { token: other, json: { display_name: 'rivka' } })).body.error, 'name_taken');
  assert.equal((await api(state, 'PUT', '/profile', { token: other, json: { display_name: 'R' } })).body.error, 'invalid_name');
  assert.equal((await api(state, 'GET', '/profile')).status, 204, 'signed out, there is no profile');
});

test('posting needs the guidelines accepted, and a thread is listed with its excerpt', async () => {
  const state = makeEnv();
  const token = await signIn(state, 'reader@example.com');
  const refused = await api(state, 'POST', '/threads', { token, json: { forum_id: 2, title: 'A question', body: 'Why?' } });
  assert.equal(refused.body.error, 'terms_not_accepted');
  await api(state, 'POST', '/profile/guidelines', { token });
  await api(state, 'PUT', '/profile', { token, json: { display_name: 'Rivka' } });
  const id = await newThread(state, token, { body: '> בְּרֵאשִׁית בָּרָא\n\nWhat does   Rashi\nmean here?' });

  const listed = await api(state, 'GET', '/threads?forum=2');
  assert.equal(listed.body.length, 1);
  assert.equal(listed.body[0].id, id);
  assert.equal(listed.body[0].author_name, 'Rivka');
  assert.equal(listed.body[0].excerpt, 'What does Rashi mean here?');
  assert.equal(listed.body[0].post_count, 1);
  assert.equal(listed.body[0].last_post_at, new Date(START).toISOString());

  const stats = await api(state, 'GET', '/forum-stats');
  assert.deepEqual(stats.body.find((s) => s.forum_id === 2), { forum_id: 2, thread_count: 1, last_post_at: new Date(START).toISOString() });
  const forums = await api(state, 'GET', '/forums');
  assert.equal(forums.body.length, 6);
  assert.equal(forums.body.find((f) => f.slug === 'announcements').locked, true);
});

test('the limits on posting: the gap, a duplicate, links, and lengths', async () => {
  const state = makeEnv();
  const token = await member(state, 'reader@example.com');
  const thread = await newThread(state, token);
  const reply = (body) => api(state, 'POST', `/threads/${thread}/posts`, { token, json: { body } });
  assert.equal((await reply('Too soon after the first post')).body.error, 'rate_limited');
  later(31000);
  assert.equal((await reply('What does Rashi mean here?')).body.error, 'duplicate_post');
  assert.equal((await reply('See https://a.example https://b.example https://c.example')).body.error, 'too_many_links');
  assert.equal((await reply('x')).body.error, 'too_short');
  const posted = await reply('An answer, with time enough between');
  assert.equal(posted.status, 201);
  assert.equal(posted.body.author_id, String(state.database.prepare('SELECT id FROM users').get().id));
  assert.equal((await api(state, 'POST', '/threads', { token, json: { forum_id: 2, title: 'Shrt', body: 'A body' } })).body.error, 'title_too_short');
});

test('a new member may start three threads a day', async () => {
  const state = makeEnv();
  const token = await member(state, 'reader@example.com');
  for (let i = 0; i < 3; i++) {
    await newThread(state, token, { title: `Question number ${i}`, body: `Body number ${i}` });
    later(31000);
  }
  const fourth = await api(state, 'POST', '/threads', { token, json: { forum_id: 2, title: 'Question number 4', body: 'Body 4' } });
  assert.equal(fourth.body.error, 'daily_thread_limit_new_user');
});

test('a member does not see what a member they blocked posts, nor its thanks', async () => {
  const state = makeEnv();
  const author = await member(state, 'author@example.com');
  const reader = await member(state, 'reader@example.com');
  const thread = await newThread(state, author);
  const [{ id: postId }] = (await api(state, 'GET', `/threads/${thread}/posts`)).body;
  await api(state, 'PUT', `/posts/${postId}/todah`, { token: reader });
  assert.equal((await api(state, 'GET', '/threads?forum=2', { token: reader })).body[0].todah_total, 1);

  const authorId = (await api(state, 'GET', '/me', { token: author })).body.user.id;
  assert.equal((await api(state, 'PUT', `/blocks/${authorId}`, { token: reader })).status, 204);
  assert.deepEqual((await api(state, 'GET', '/blocks', { token: reader })).body, [{ id: authorId, name: (await api(state, 'GET', '/profile', { token: author })).body.display_name }]);
  assert.deepEqual((await api(state, 'GET', `/threads/${thread}/posts`, { token: reader })).body, []);
  const listed = (await api(state, 'GET', '/threads?forum=2', { token: reader })).body[0];
  assert.equal(listed.excerpt, null);
  assert.equal(listed.todah_total, 0);
  // Others still see it.
  assert.equal((await api(state, 'GET', `/threads/${thread}/posts`)).body.length, 1);
  assert.equal((await api(state, 'DELETE', `/blocks/${authorId}`, { token: reader })).status, 204);
  assert.equal((await api(state, 'GET', `/threads/${thread}/posts`, { token: reader })).body.length, 1);
});

test('three reports hide a post from all but its author and staff', async () => {
  const state = makeEnv();
  const author = await member(state, 'author@example.com');
  const thread = await newThread(state, author);
  const [{ id: postId }] = (await api(state, 'GET', `/threads/${thread}/posts`)).body;
  for (const who of ['a', 'b', 'c']) {
    const token = await signIn(state, `${who}@example.com`);
    assert.equal((await api(state, 'POST', '/reports', { token, json: { post_id: postId, reason: 'spam' } })).status, 204);
    if (who === 'a') {
      assert.equal((await api(state, 'POST', '/reports', { token, json: { post_id: postId, reason: 'spam' } })).body.error, 'already_reported');
    }
  }
  assert.deepEqual((await api(state, 'GET', `/threads/${thread}/posts`)).body, []);
  const own = (await api(state, 'GET', `/threads/${thread}/posts`, { token: author })).body;
  assert.equal(own.length, 1);
  assert.equal(own[0].hidden, true);

  grant(state, 'mod@example.com', 'moderator');
  const mod = await signIn(state, 'mod@example.com');
  assert.equal((await api(state, 'GET', `/threads/${thread}/posts`, { token: mod })).body.length, 1);
  const reports = (await api(state, 'GET', '/reports', { token: mod })).body;
  assert.equal(reports.length, 3);
  assert.equal(reports[0].post_body, 'What does Rashi mean here?');
  assert.equal((await api(state, 'GET', '/reports', { token: author })).body.error, 'forbidden');
  await api(state, 'POST', '/moderate', { token: mod, json: { action: 'restore_post', target_id: String(postId) } });
  assert.equal((await api(state, 'GET', `/threads/${thread}/posts`)).body.length, 1);
});

test('a deleted post is gone for everyone, and its thread no longer counts it', async () => {
  const state = makeEnv();
  const token = await member(state, 'reader@example.com');
  const thread = await newThread(state, token);
  later(31000);
  const reply = await api(state, 'POST', `/threads/${thread}/posts`, { token, json: { body: 'A second thought' } });
  const other = await member(state, 'other@example.com');
  assert.equal((await api(state, 'DELETE', `/posts/${reply.body.id}`, { token: other })).body.error, 'forbidden');
  assert.equal((await api(state, 'PATCH', `/posts/${reply.body.id}`, { token: other, json: { body: 'Not mine' } })).body.error, 'forbidden');
  assert.equal((await api(state, 'PATCH', `/posts/${reply.body.id}`, { token, json: { body: 'A second thought, edited' } })).status, 204);
  const edited = (await api(state, 'GET', `/threads/${thread}/posts`)).body[1];
  assert.equal(edited.body, 'A second thought, edited');
  assert.ok(edited.edited_at);
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM post_revisions').get().n, 1);

  assert.equal((await api(state, 'DELETE', `/posts/${reply.body.id}`, { token })).status, 204);
  assert.equal((await api(state, 'GET', `/threads/${thread}/posts`, { token })).body.length, 1);
  assert.equal((await api(state, 'GET', `/threads/${thread}`)).body.post_count, 1);
});

test('only staff start threads in a locked forum, and only staff post in a locked thread', async () => {
  const state = makeEnv();
  const reader = await member(state, 'reader@example.com');
  const refused = await api(state, 'POST', '/threads', { token: reader, json: { forum_id: 6, title: 'An announcement', body: 'News' } });
  assert.equal(refused.body.error, 'category_restricted');
  grant(state, 'admin@example.com', 'admin');
  const admin = await member(state, 'admin@example.com');
  assert.equal((await api(state, 'GET', '/profile', { token: admin })).body.is_moderator, true);
  assert.equal((await api(state, 'GET', '/profile', { token: admin })).body.role, 'admin');
  const news = await newThread(state, admin, { forum: 6, title: 'An announcement', body: 'News for all' });

  assert.equal((await api(state, 'POST', '/moderate', { token: reader, json: { action: 'lock_thread', target_id: String(news) } })).body.error, 'forbidden');
  assert.equal((await api(state, 'POST', '/moderate', { token: admin, json: { action: 'lock_thread', target_id: String(news) } })).status, 204);
  assert.equal((await api(state, 'POST', `/threads/${news}/posts`, { token: reader, json: { body: 'A reply' } })).body.error, 'thread_locked');
  assert.equal(state.database.prepare("SELECT count(*) AS n FROM moderation_log WHERE action = 'lock_thread'").get().n, 1);
});

test('moderators are named by an admin, and none of them can act on an admin', async () => {
  const state = makeEnv();
  grant(state, 'admin@example.com', 'admin');
  const admin = await signIn(state, 'admin@example.com');
  const adminId = (await api(state, 'GET', '/me', { token: admin })).body.user.id;
  const helper = await signIn(state, 'helper@example.com');
  const helperId = (await api(state, 'GET', '/me', { token: helper })).body.user.id;
  const reader = await signIn(state, 'reader@example.com');
  const readerId = (await api(state, 'GET', '/me', { token: reader })).body.user.id;

  assert.equal((await api(state, 'POST', '/moderate', { token: admin, json: { action: 'grant_moderator', target_id: helperId } })).status, 204);
  assert.equal((await api(state, 'GET', '/profile', { token: helper })).body.is_moderator, true);
  assert.equal((await api(state, 'POST', '/moderate', { token: helper, json: { action: 'grant_moderator', target_id: readerId } })).body.error, 'forbidden');
  assert.equal((await api(state, 'POST', '/moderate', { token: helper, json: { action: 'ban_user', target_id: adminId } })).body.error, 'forbidden');
  assert.equal((await api(state, 'POST', '/moderate', { token: helper, json: { action: 'ban_user', target_id: readerId } })).status, 204);
  await api(state, 'POST', '/profile/guidelines', { token: reader });
  assert.equal((await api(state, 'POST', '/threads', { token: reader, json: { forum_id: 2, title: 'Banned now', body: 'A body' } })).body.error, 'banned');
  assert.equal((await api(state, 'POST', '/moderate', { token: admin, json: { action: 'revoke_moderator', target_id: helperId } })).status, 204);
  assert.equal((await api(state, 'GET', '/profile', { token: helper })).body.is_moderator, false);
  assert.equal((await api(state, 'POST', '/moderate', { token: admin, json: { action: 'fly', target_id: readerId } })).body.error, 'unknown_action');
});

test('the weekly thread is opened once, named from the parasha, for the years about now', async () => {
  const state = makeEnv();
  const first = await api(state, 'POST', '/weekly', { json: { parsha: 3, year: 5787 } });
  assert.equal(first.status, 200);
  const again = await api(state, 'POST', '/weekly', { json: { parsha: 3, year: 5787 } });
  assert.equal(again.body.id, first.body.id);
  const thread = (await api(state, 'GET', `/threads/${first.body.id}`)).body;
  assert.equal(thread.title, 'Lech Lecha · לך־לך · 5787');
  assert.equal(thread.kind, 'weekly');
  assert.equal(thread.pinned, false);
  assert.equal(thread.author_id, null);
  assert.equal((await api(state, 'POST', '/weekly', { json: { parsha: 3, year: 5900 } })).body.error, 'invalid_year');
  assert.equal((await api(state, 'POST', '/weekly', { json: { parsha: 55, year: 5787 } })).body.error, 'invalid_parasha');
  // Opened, but not posted in: a thread, and no sign of life.
  assert.deepEqual((await api(state, 'GET', '/forum-stats')).body.find((s) => s.forum_id === 1), { forum_id: 1, thread_count: 1, last_post_at: null });
});

test('pages of threads and posts follow on without repeating or skipping one', async () => {
  const state = makeEnv();
  const token = await member(state, 'reader@example.com');
  state.database.prepare('UPDATE profiles SET trust_level = 1').run();
  const ids = [];
  for (let i = 0; i < 5; i++) {
    ids.push(await newThread(state, token, { title: `Thread number ${i}`, body: `Body number ${i}` }));
    later(6000);
  }
  // Two threads with the same last activity, told apart by id.
  state.database.prepare('UPDATE threads SET last_post_at = ? WHERE id IN (?, ?)').run(START, ids[3], ids[4]);
  const seen = [];
  let after = null;
  for (;;) {
    const page = (await api(state, 'GET', `/threads?forum=2&limit=2${after ? `&after=${after}` : ''}`)).body;
    if (page.length === 0) break;
    seen.push(...page.map((t) => t.id));
    const last = page.at(-1);
    after = `${Date.parse(last.last_post_at)}:${last.id}`;
  }
  assert.deepEqual([...seen].sort((a, b) => a - b), ids);
  assert.equal(new Set(seen).size, ids.length);

  for (let i = 0; i < 4; i++) {
    await api(state, 'POST', `/threads/${ids[0]}/posts`, { token, json: { body: `Reply number ${i}` } });
    later(6000);
  }
  const latest = (await api(state, 'GET', `/threads/${ids[0]}/posts?limit=2`)).body;
  assert.deepEqual(latest.map((p) => p.body), ['Reply number 2', 'Reply number 3']);
  const before = `${Date.parse(latest[0].created_at)}:${latest[0].id}`;
  const earlier = (await api(state, 'GET', `/threads/${ids[0]}/posts?limit=2&before=${before}`)).body;
  assert.deepEqual(earlier.map((p) => p.body), ['Reply number 0', 'Reply number 1']);
});

test('a reply quotes the post it answers, where the reader may see that post', async () => {
  const state = makeEnv();
  const token = await member(state, 'reader@example.com');
  await api(state, 'PUT', '/profile', { token, json: { display_name: 'Rivka' } });
  const thread = await newThread(state, token);
  const [{ id: first }] = (await api(state, 'GET', `/threads/${thread}/posts`)).body;
  later(31000);
  const reply = await api(state, 'POST', `/threads/${thread}/posts`, { token, json: { body: 'Answering myself', reply_to_id: String(first) } });
  assert.equal(reply.body.reply_to_id, first);
  const posts = (await api(state, 'GET', `/threads/${thread}/posts`)).body;
  assert.deepEqual(posts[1].quote, { author_name: 'Rivka', body: 'What does Rashi mean here?' });
});

test('thanks are given once, and taken back', async () => {
  const state = makeEnv();
  const token = await member(state, 'reader@example.com');
  const thread = await newThread(state, token);
  const [{ id: postId }] = (await api(state, 'GET', `/threads/${thread}/posts`)).body;
  await api(state, 'PUT', `/posts/${postId}/todah`, { token });
  await api(state, 'PUT', `/posts/${postId}/todah`, { token });
  let [post] = (await api(state, 'GET', `/threads/${thread}/posts`, { token })).body;
  assert.equal(post.todah, 1);
  assert.equal(post.my_todah, true);
  await api(state, 'DELETE', `/posts/${postId}/todah`, { token });
  [post] = (await api(state, 'GET', `/threads/${thread}/posts`, { token })).body;
  assert.equal(post.todah, 0);
  assert.equal(post.my_todah, false);
});

test('deleting the account removes what its member posted, and keeps the threads others posted in', async () => {
  const state = makeEnv();
  const leaving = await member(state, 'leaving@example.com');
  const staying = await member(state, 'staying@example.com');
  const lonely = await newThread(state, leaving, { title: 'Nobody answered this', body: 'Alone here' });
  later(31000);
  const shared = await newThread(state, leaving, { title: 'Somebody answered this', body: 'Answer me' });
  await api(state, 'POST', `/threads/${shared}/posts`, { token: staying, json: { body: 'Here is an answer' } });
  await api(state, 'PUT', '/progress', { token: leaving, json: { data: { streak: 3 } } });

  const deleted = await api(state, 'DELETE', '/me', { token: leaving });
  assert.equal(deleted.status, 204);
  assert.equal((await api(state, 'GET', '/me', { token: leaving })).status, 401);
  assert.equal((await api(state, 'GET', `/threads/${lonely}`)).body.error, 'thread_not_found');
  const kept = (await api(state, 'GET', `/threads/${shared}`)).body;
  assert.equal(kept.author_id, null);
  assert.equal(kept.post_count, 1);
  assert.equal(state.database.prepare("SELECT count(*) AS n FROM users WHERE email = 'leaving@example.com'").get().n, 0);
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM user_progress').get().n, 0);
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM profiles').get().n, 1);
});

test('the progress backup comes back as it was saved', async () => {
  const state = makeEnv();
  const token = await signIn(state, 'reader@example.com');
  assert.deepEqual((await api(state, 'GET', '/progress', { token })).body, { data: null });
  const data = { version: 2, weeks: { 5787: [1, 2, 3] }, notes: { 'Genesis 1:1': 'בראשית' } };
  assert.equal((await api(state, 'PUT', '/progress', { token, json: { data } })).status, 204);
  assert.deepEqual((await api(state, 'GET', '/progress', { token })).body, { data });
  assert.equal((await api(state, 'GET', '/progress')).body.error, 'not_signed_in');
  assert.equal((await api(state, 'PUT', '/progress', { token, json: { data: [1] } })).body.error, 'invalid_progress');
});

test('the site\'s cookie signs the web app in, and a change with it alone must come from the site', async () => {
  const state = makeEnv();
  const verify = await (async () => {
    await api(state, 'POST', '/auth/code', { json: { email: 'reader@example.com' } });
    return api(state, 'POST', '/auth/verify', { json: { email: 'reader@example.com', code: lastCode() } });
  })();
  const cookie = verify.headers.get('set-cookie').split(';')[0];
  assert.equal((await api(state, 'GET', '/me', { cookie })).status, 200);
  const foreign = await api(state, 'POST', '/profile/guidelines', { cookie, origin: 'https://evil.example', fetchSite: 'cross-site' });
  assert.equal(foreign.status, 403);
  const own = await api(state, 'POST', '/profile/guidelines', { cookie, origin: SITE, fetchSite: 'same-origin' });
  assert.equal(own.status, 204);
  const out = await api(state, 'POST', '/auth/sign-out', { cookie, origin: SITE });
  assert.equal(out.status, 204);
  assert.match(out.headers.get('set-cookie'), /Max-Age=0/);
  assert.equal((await api(state, 'GET', '/me', { cookie })).status, 401);
});

test('a session in use is kept going', async () => {
  const state = makeEnv();
  const token = await signIn(state, 'reader@example.com');
  later(20 * 86400000);
  await api(state, 'GET', '/me', { token });
  later(20 * 86400000);
  assert.equal((await api(state, 'GET', '/me', { token })).status, 200);
});

test('the API is no visit, and takes the methods only it takes', async () => {
  const state = makeEnv();
  await api(state, 'GET', '/forums');
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM visits').get().n, 0);
  const request = new Request(`${SITE}/community`, { method: 'PUT', headers: { 'user-agent': 'Mozilla/5.0' } });
  const response = await worker.fetch(request, state.env, { waitUntil: () => {} });
  assert.equal(response.status, 405);
  assert.equal((await api(state, 'GET', '/nothing')).status, 404);
  assert.equal((await api(state, 'GET', '/threads/abc')).body.error, 'not_found');
});

test('a thread\'s excerpt is cut as the app cuts it', () => {
  assert.equal(excerptOf('  Line one\n\nline   two '), 'Line one line two');
  assert.equal(excerptOf('> בְּרֵאשִׁית'), null);
  assert.equal(excerptOf('‎> בְּרֵאשִׁית\n\nThe question'), 'The question');
  assert.equal(excerptOf('> not Hebrew\n\nrest'), '> not Hebrew rest');
  const words = Array.from({ length: 40 }, (_, i) => `word${i}`).join(' ');
  const cut = excerptOf(words);
  assert.ok(cut.endsWith('…'));
  assert.ok([...cut].length <= 141);
  assert.ok(words.startsWith(cut.slice(0, -1)));
  const link = `https://example.org/${'a'.repeat(200)}`;
  assert.equal([...excerptOf(link)].length, 140);
});

test('an account made in the app is deleted on the site without a password, with what it posted', async () => {
  const state = makeEnv();
  await api(state, 'POST', '/auth/code', { json: { email: 'reader@example.com' } });
  const verified = await api(state, 'POST', '/auth/verify', { json: { email: 'reader@example.com', code: lastCode() } });
  const token = verified.body.token;
  await api(state, 'POST', '/profile/guidelines', { token });
  await newThread(state, token);
  const cookie = verified.headers.get('set-cookie').split(';')[0];
  const site = (method, path, body) => {
    const request = new Request(`${SITE}${path}`, {
      method,
      headers: { 'user-agent': 'Mozilla/5.0', cookie, origin: SITE, 'content-type': 'application/x-www-form-urlencoded', 'cf-connecting-ip': '203.0.113.9' },
      body,
    });
    return worker.fetch(request, state.env, { waitUntil: () => {} });
  };
  const page = await (await site('GET', '/account')).text();
  assert.match(page, /no password to enter/);
  assert.doesNotMatch(page, /name="password"/);
  const deleted = await site('POST', '/account/delete', '');
  assert.equal(deleted.status, 303);
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM users').get().n, 0);
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM posts').get().n, 0);
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM threads').get().n, 0);
});

test('an account made in the app cannot sign in on the site\'s form, whatever the password', async () => {
  const state = makeEnv();
  await signIn(state, 'reader@example.com');
  passTurnstile();
  const request = new Request(`${SITE}/account/sign-in`, {
    method: 'POST',
    headers: { 'user-agent': 'Mozilla/5.0', origin: SITE, 'content-type': 'application/x-www-form-urlencoded', 'cf-connecting-ip': '203.0.113.9' },
    body: new URLSearchParams({ email: 'reader@example.com', password: 'not-the-password-of-any-account', 'cf-turnstile-response': 't' }).toString(),
  });
  const response = await worker.fetch(request, state.env, { waitUntil: () => {} });
  assert.equal(response.status, 401);
});

// Turnstile passes, for a test of the site's forms.
function passTurnstile() {
  const resend = globalThis.fetch;
  globalThis.fetch = async (url, init) => String(url).startsWith('https://challenges.cloudflare.com/')
    ? new Response(JSON.stringify({ success: true }), { headers: { 'content-type': 'application/json' } })
    : resend(url, init);
}
