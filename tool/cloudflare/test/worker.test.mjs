// Run with: node --test tool/cloudflare/test/
import assert from 'node:assert/strict';
import { test } from 'node:test';

import worker from '../src/worker.js';
import { blockedStatus, classify, clip, dayOf, firstLanguage, ipKey, isPageView, refererHost } from '../src/rules.js';

const CANONICAL = 'shnayimmikrah.org';
const VISITOR = '203.0.113.7';

// A database that records each batch, and an asset store that answers 200.
function fakeEnv({ salt = 'test-salt', failWrites = false } = {}) {
  const batches = [];
  const LOGS = {
    prepare(sql) {
      return {
        sql,
        args: [],
        bind(...args) {
          this.args = args;
          return this;
        },
      };
    },
    async batch(statements) {
      if (failWrites) throw new Error('D1 is down');
      batches.push(statements.map((s) => ({ sql: s.sql, args: s.args })));
      return [];
    },
  };
  const assetRequests = [];
  const ASSETS = {
    async fetch(request) {
      assetRequests.push(new URL(request.url).pathname);
      return new Response('the app', { status: 200 });
    },
  };
  return { env: { LOGS, ASSETS, IP_SALT: salt, CANONICAL_HOST: CANONICAL, RETENTION_DAYS: '365' }, batches, assetRequests };
}

const PAGE_HEADERS = {
  'sec-fetch-dest': 'document',
  'user-agent': 'Mozilla/5.0 (Windows NT 10.0) Chrome/130',
  'cf-connecting-ip': VISITOR,
  referer: 'https://www.google.com/search?q=private+words',
  'accept-language': 'he-IL,he;q=0.9,en;q=0.5',
};

// Runs the Worker on one request, and waits for what it queued after the response.
async function call(url, { method = 'GET', headers = PAGE_HEADERS, cf = { country: 'IL', asn: 8551, threatScore: 2 } } = {}, envOptions) {
  const fake = fakeEnv(envOptions);
  const request = new Request(url, { method, headers });
  Object.defineProperty(request, 'cf', { value: cf });
  const waits = [];
  const ctx = { waitUntil: (promise) => waits.push(promise) };
  const response = await worker.fetch(request, fake.env, ctx);
  await Promise.all(waits);
  return { response, ...fake };
}

// The rows written to one table, as objects keyed by the statement's column list.
function rows(batches, table) {
  const found = [];
  for (const batch of batches) {
    for (const { sql, args } of batch) {
      const match = sql.match(new RegExp(`^INSERT INTO ${table} \\(([^)]*)\\)`));
      if (!match) continue;
      const columns = match[1].split(',').map((c) => c.trim());
      found.push(Object.fromEntries(columns.map((c, i) => [c, args[i]])));
    }
  }
  return found;
}

const SITE = `https://${CANONICAL}`;

test('a page view is served and logged as a visit, without the address', async () => {
  const { response, batches, assetRequests } = await call(`${SITE}/community?ref=x`);
  assert.equal(response.status, 200);
  assert.deepEqual(assetRequests, ['/community']);
  const [visit] = rows(batches, 'visits');
  assert.equal(visit.path, '/community', 'the query is not stored');
  assert.equal(visit.status, 200);
  assert.equal(visit.country, 'IL');
  assert.equal(visit.asn, 8551);
  assert.equal(visit.referer_host, 'www.google.com', 'only the referring host');
  assert.equal(visit.lang, 'he-IL');
  assert.equal(visit.threat_score, 2);
  assert.equal(rows(batches, 'security_events').length, 0);
  assert.equal(JSON.stringify(batches).includes(VISITOR), false, 'the address is never written');
  assert.equal(JSON.stringify(batches).includes('private+words'), false, 'the referrer query is never written');
  assert.match(visit.ip, /^[0-9a-f]{32}$/);
});

test('a file the page loads is not a visit', async () => {
  const headers = { ...PAGE_HEADERS, 'sec-fetch-dest': 'script' };
  const { response, batches } = await call(`${SITE}/main.dart.js`, { headers });
  assert.equal(response.status, 200);
  assert.equal(rows(batches, 'visits').length, 0);
});

test('a method the site does not use is refused and logged', async () => {
  const { response, batches, assetRequests } = await call(`${SITE}/`, { method: 'POST' });
  assert.equal(response.status, 405);
  assert.equal(response.headers.get('allow'), 'GET, HEAD, OPTIONS');
  assert.deepEqual(assetRequests, []);
  const [event] = rows(batches, 'security_events');
  assert.equal(event.kind, 'bad_method');
  assert.equal(event.detail, 'POST');
  assert.equal(rows(batches, 'visits').length, 0);
});

test('a scanner probing for secrets gets a 404, not the app, and is logged', async () => {
  const { response, batches, assetRequests } = await call(`${SITE}/.env.production`);
  assert.equal(response.status, 404);
  assert.deepEqual(assetRequests, []);
  assert.equal(rows(batches, 'security_events')[0].kind, 'scanner_path');
});

test('WordPress and script probes are scanner paths', () => {
  for (const path of ['/wp-admin/install.php', '/xmlrpc.php', '/backup.sql', '/index.php', '/.git/config', '/cgi-bin/test']) {
    assert.ok(classify({ method: 'GET', host: CANONICAL, canonicalHost: CANONICAL, pathname: path, userAgent: 'x' }).some((k) => k.kind === 'scanner_path'), path);
  }
  for (const path of ['/', '/install.ps1', '/.well-known/assetlinks.json', '/community/thread/1', '/legal/privacy', '/favicon.ico']) {
    assert.equal(classify({ method: 'GET', host: CANONICAL, canonicalHost: CANONICAL, pathname: path, userAgent: 'x' }).length, 0, path);
  }
});

test('a known scanner tool gets a 403', async () => {
  const headers = { ...PAGE_HEADERS, 'user-agent': 'sqlmap/1.8' };
  const { response, batches } = await call(`${SITE}/`, { headers });
  assert.equal(response.status, 403);
  assert.equal(rows(batches, 'security_events')[0].kind, 'scanner_agent');
});

test('the workers.dev address redirects to the site, and is logged, not counted', async () => {
  const { response, batches, assetRequests } = await call('https://shnayimmikrah-org.example.workers.dev/legal/privacy?x=1');
  assert.equal(response.status, 301);
  assert.equal(response.headers.get('location'), `${SITE}/legal/privacy?x=1`);
  assert.deepEqual(assetRequests, []);
  assert.equal(rows(batches, 'security_events')[0].kind, 'bad_host');
  assert.equal(rows(batches, 'security_events')[0].detail, 'shnayimmikrah-org.example.workers.dev');
  assert.equal(rows(batches, 'visits').length, 0);
});

test('a write to another host is refused with 421', async () => {
  const { response, batches } = await call('https://other.example/', { method: 'POST' });
  assert.equal(response.status, 421);
  const kinds = rows(batches, 'security_events').map((r) => r.kind).sort();
  assert.deepEqual(kinds, ['bad_host', 'bad_method']);
});

test('a path or query too long is refused with 414', async () => {
  const { response, batches } = await call(`${SITE}/${'a'.repeat(600)}`);
  assert.equal(response.status, 414);
  assert.equal(rows(batches, 'security_events')[0].kind, 'too_long');
});

test('an encoded slash, which a traversal needs, is refused with 404', async () => {
  const { response, batches } = await call(`${SITE}/legal%2fprivacy`);
  assert.equal(response.status, 404);
  assert.equal(rows(batches, 'security_events')[0].kind, 'traversal');
});

test('a request with no User-Agent is still served, and noted', async () => {
  const headers = { ...PAGE_HEADERS };
  delete headers['user-agent'];
  const { response, batches } = await call(`${SITE}/`, { headers });
  assert.equal(response.status, 200);
  assert.equal(rows(batches, 'security_events')[0].kind, 'no_user_agent');
  assert.equal(rows(batches, 'visits').length, 1);
});

test('a threat score at or above the threshold is noted with its score', async () => {
  const { batches } = await call(`${SITE}/`, { cf: { country: 'US', threatScore: 35 } });
  const [event] = rows(batches, 'security_events');
  assert.equal(event.kind, 'threat_score');
  assert.equal(event.detail, '35');
  assert.equal(rows(batches, 'visits')[0].threat_score, 35);
});

test('a database failure never breaks the site', async () => {
  const originalError = console.error;
  console.error = () => {};
  try {
    const { response } = await call(`${SITE}/`, {}, { failWrites: true });
    assert.equal(response.status, 200);
    assert.equal(await response.text(), 'the app');
  } finally {
    console.error = originalError;
  }
});

test('without the salt, the visit is logged with no address key', async () => {
  const { batches } = await call(`${SITE}/`, {}, { salt: '' });
  assert.equal(rows(batches, 'visits')[0].ip, null);
});

test('the daily retention removes rows older than the period', async () => {
  const fake = fakeEnv();
  const waits = [];
  const before = Date.now();
  await worker.scheduled({}, fake.env, { waitUntil: (p) => waits.push(p) });
  await Promise.all(waits);
  const [visits, events] = fake.batches[0];
  assert.equal(visits.sql, 'DELETE FROM visits WHERE ts < ?');
  assert.equal(events.sql, 'DELETE FROM security_events WHERE ts < ?');
  const cutoff = visits.args[0];
  const days = (before - cutoff) / 86400000;
  assert.ok(days > 364.9 && days < 365.1, `cutoff ${days} days back`);
  assert.equal(events.args[0], cutoff);
});

test('the address key is stable within a day, changes with the day and the address, and is not the address', async () => {
  const day = '2026-10-22';
  const a = await ipKey(VISITOR, 'salt', day);
  assert.equal(a, await ipKey(VISITOR, 'salt', day));
  assert.notEqual(a, await ipKey(VISITOR, 'salt', '2026-10-23'));
  assert.notEqual(a, await ipKey('198.51.100.1', 'salt', day));
  assert.notEqual(a, await ipKey(VISITOR, 'other', day));
  assert.equal(a.includes(VISITOR), false);
  assert.equal(await ipKey(VISITOR, '', day), null);
  assert.equal(await ipKey('', 'salt', day), null);
});

test('only page views are visits', () => {
  assert.equal(isPageView({ method: 'GET', headers: new Headers({ 'sec-fetch-dest': 'document' }) }), true);
  assert.equal(isPageView({ method: 'GET', headers: new Headers({ 'sec-fetch-dest': 'image' }) }), false);
  assert.equal(isPageView({ method: 'HEAD', headers: new Headers({ 'sec-fetch-dest': 'document' }) }), false);
  assert.equal(isPageView({ method: 'GET', headers: new Headers({ accept: 'text/html,*/*' }) }), true);
  assert.equal(isPageView({ method: 'GET', headers: new Headers({ accept: 'image/png' }) }), false);
});

test('the status of a refused request', () => {
  assert.equal(blockedStatus([]), null);
  assert.equal(blockedStatus([{ kind: 'bad_host' }]), 301);
  assert.equal(blockedStatus([{ kind: 'bad_method' }]), 405);
  assert.equal(blockedStatus([{ kind: 'scanner_path' }]), 404);
  assert.equal(blockedStatus([{ kind: 'no_user_agent' }]), null, 'noted, but served');
});

test('the logged strings are cut, and the referrer keeps only its host', () => {
  assert.equal(clip('x'.repeat(300), 200).length, 200);
  assert.equal(clip('', 5), null);
  assert.equal(clip(undefined, 5), null);
  assert.equal(refererHost('https://example.org/a/b?secret=1'), 'example.org');
  assert.equal(refererHost('not a url'), null);
  assert.equal(refererHost(null), null);
  assert.equal(firstLanguage('he-IL,he;q=0.9'), 'he-IL');
  assert.equal(firstLanguage(null), null);
  assert.equal(dayOf(Date.UTC(2026, 9, 22, 23, 30)), '2026-10-22');
});
