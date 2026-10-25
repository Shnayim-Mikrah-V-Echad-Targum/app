// Run with: node --test tool/cloudflare/test/methods.test.mjs
// The ways of signing in beyond the password (src/account_methods.js): an
// emailed code on the site, the authenticator app and its recovery codes,
// and passkeys, made here with a real P-256 key as a device would make one.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { afterEach, beforeEach, test } from 'node:test';

import worker from '../src/worker.js';
import { base32, fromBase32, hotp, newRecoveryCodes, openSecret, recoveryForm, sealSecret, stepAt, totpStep } from '../src/account_mfa.js';
import { cborDecode, derToRaw } from '../src/passkeys.js';
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

async function send(state, method, path, { cookie, form, json, origin = SITE } = {}) {
  const headers = { 'user-agent': 'Mozilla/5.0', 'cf-connecting-ip': '203.0.113.9', 'accept-language': 'en' };
  if (cookie) headers.cookie = cookie;
  const init = { method, headers, redirect: 'manual' };
  if (method === 'POST') {
    headers.origin = origin;
    headers['sec-fetch-site'] = origin === SITE ? 'same-origin' : 'cross-site';
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
  const response = await worker.fetch(request, state.env, { waitUntil: () => {} });
  return response;
}

function lastCode() {
  return mail.at(-1).text.match(/Your code is (\d{6})/)[1];
}

function cookieNamed(response, name) {
  const all = response.headers.getSetCookie?.() ?? [response.headers.get('set-cookie')];
  const found = all.find((c) => c?.startsWith(`${name}=`));
  return found ? found.split(';')[0] : null;
}

// Signs in on the site with an emailed code, and returns the session cookie,
// or the pending cookie where a second step is asked for.
async function signInByCode(state, email) {
  await send(state, 'POST', '/account/sign-in/email', { form: { email, 'cf-turnstile-response': 't' } });
  return send(state, 'POST', '/account/sign-in/code', { form: { email, code: lastCode() } });
}

async function signedIn(state, email = 'reader@example.com') {
  const response = await signInByCode(state, email);
  assert.equal(response.status, 303);
  return cookieNamed(response, '__Host-sm_session');
}

// Turns the authenticator on for the account signed in, and returns its
// secret and the recovery codes shown.
async function turnOnTotp(state, cookie) {
  assert.equal((await send(state, 'POST', '/account/totp/start', { cookie })).headers.get('location'), '/account/totp');
  const setup = await (await send(state, 'GET', '/account/totp', { cookie })).text();
  assert.match(setup, /<svg[^>]*viewBox/);
  const key = setup.match(/<span class="key">([A-Z2-7 ]+)<\/span>/)[1];
  const secret = fromBase32(key);
  assert.match(setup, /otpauth:\/\/totp\/Shnayim%20Mikrah%3Areader%40example\.com\?secret=/);
  const code = await hotp(secret, stepAt(clock));
  const confirmed = await send(state, 'POST', '/account/totp/confirm', { cookie, form: { code } });
  assert.equal(confirmed.status, 200);
  const page = await confirmed.text();
  const codes = [...page.matchAll(/<li>([a-z0-9]{4}-[a-z0-9]{4})<\/li>/g)].map((m) => m[1]);
  assert.equal(codes.length, 10);
  return { secret, codes };
}

test('a TOTP code is RFC 6238’s, and works once, within a step of now', async () => {
  // RFC 6238's SHA-1 vectors, to six digits.
  const secret = new TextEncoder().encode('12345678901234567890');
  assert.equal(await hotp(secret, Math.floor(59 / 30)), '287082');
  assert.equal(await hotp(secret, Math.floor(1111111109 / 30)), '081804');
  const now = 1111111109 * 1000;
  assert.equal(await totpStep(secret, '081804', now), stepAt(now));
  assert.equal(await totpStep(secret, '081804', now + 30000), stepAt(now), 'a step late still counts');
  assert.equal(await totpStep(secret, '081804', now + 90000), null);
  assert.equal(await totpStep(secret, '081804', now, stepAt(now)), null, 'never twice');
  assert.equal(await totpStep(secret, 'abcdef', now), null);
  assert.deepEqual(fromBase32(base32(secret)), secret);
  for (const code of newRecoveryCodes()) assert.match(code, /^[a-hj-km-np-z2-9]{4}-[a-hj-km-np-z2-9]{4}$/);
  assert.equal(recoveryForm(' KQ7M-3XZP '), 'kq7m3xzp');
  const env = { ACCOUNTS_KEY: 'k' };
  const sealed = await sealSecret(env, secret);
  assert.ok(!sealed.includes(base32(secret)));
  assert.deepEqual(await openSecret(env, sealed), secret);
});

test('the site signs in with an emailed code, as the app does', async () => {
  const state = makeEnv();
  const page = await (await send(state, 'GET', '/account/sign-in')).text();
  assert.match(page, /href="\/account\/sign-in\/email"/);
  assert.match(page, /<script src="\/account\/passkey.js" defer><\/script>/);
  const cookie = await signedIn(state);
  assert.ok(cookie);
  const account = await (await send(state, 'GET', '/account', { cookie })).text();
  assert.match(account, /reader@example\.com/);
  assert.match(account, /No password yet/);
  assert.match(account, /Set up an authenticator app/);
  assert.match(account, /Add a passkey/);
  const wrong = await send(state, 'POST', '/account/sign-in/code', { form: { email: 'reader@example.com', code: '000000' } });
  assert.equal(wrong.status, 400);
});

test('with the authenticator on, a sign-in asks for its code, then a recovery code works once', async () => {
  const state = makeEnv();
  const cookie = await signedIn(state);
  const { secret, codes } = await turnOnTotp(state, cookie);
  assert.match(await (await send(state, 'GET', '/account', { cookie })).text(), /On\. Recovery codes left: 10/);

  // An emailed code alone is not enough now.
  const first = await signInByCode(state, 'reader@example.com');
  assert.equal(first.headers.get('location'), '/account/two-step');
  assert.equal(cookieNamed(first, '__Host-sm_session'), null);
  const pending = cookieNamed(first, '__Host-sm_pending');
  assert.ok(pending);
  assert.equal((await send(state, 'GET', '/account/two-step', { cookie: pending })).status, 200);
  const wrong = await send(state, 'POST', '/account/two-step', { cookie: pending, form: { code: '000000' } });
  assert.equal(wrong.status, 401);
  // The code used to turn it on doesn't work again; the next one does.
  clock += 30000;
  const done = await send(state, 'POST', '/account/two-step', { cookie: pending, form: { code: await hotp(secret, stepAt(clock)) } });
  assert.equal(done.status, 303);
  assert.ok(cookieNamed(done, '__Host-sm_session'));
  assert.match(cookieNamed(done, '__Host-sm_pending'), /^__Host-sm_pending=$/);

  // A recovery code, as typed, once.
  const again = cookieNamed(await signInByCode(state, 'reader@example.com'), '__Host-sm_pending');
  assert.equal((await send(state, 'POST', '/account/two-step', { cookie: again, form: { code: codes[0].toUpperCase() } })).status, 303);
  const third = cookieNamed(await signInByCode(state, 'reader@example.com'), '__Host-sm_pending');
  assert.equal((await send(state, 'POST', '/account/two-step', { cookie: third, form: { code: codes[0] } })).status, 401);

  // Five wrong codes (the reused one, and four more) end the pending sign-in,
  // even for a right code after them.
  for (let i = 0; i < 4; i++) await send(state, 'POST', '/account/two-step', { cookie: third, form: { code: '111111' } });
  const ended = await send(state, 'POST', '/account/two-step', { cookie: third, form: { code: codes[1] } });
  assert.equal(ended.status, 429);
  assert.equal(cookieNamed(ended, '__Host-sm_session'), null);
  assert.equal((await send(state, 'GET', '/account/two-step', { cookie: third })).headers.get('location'), '/account/sign-in');
});

test('the app’s sign-in asks for the authenticator’s code too, and keeps the emailed one good meanwhile', async () => {
  const state = makeEnv();
  const cookie = await signedIn(state);
  const { secret } = await turnOnTotp(state, cookie);
  await send(state, 'POST', '/api/auth/code', { json: { email: 'reader@example.com' } });
  const code = lastCode();
  const asked = await send(state, 'POST', '/api/auth/verify', { json: { email: 'reader@example.com', code } });
  assert.equal(asked.status, 401);
  assert.deepEqual(await asked.json(), { error: 'totp_required' });
  const wrong = await send(state, 'POST', '/api/auth/verify', { json: { email: 'reader@example.com', code, totp: '000000' } });
  assert.deepEqual(await wrong.json(), { error: 'invalid_totp' });
  clock += 30000;
  const ok = await send(state, 'POST', '/api/auth/verify', { json: { email: 'reader@example.com', code, totp: await hotp(secret, stepAt(clock)) } });
  assert.equal(ok.status, 200);
  assert.ok((await ok.json()).token);
});

test('turning the authenticator off, or making new recovery codes, asks for a code', async () => {
  const state = makeEnv();
  const cookie = await signedIn(state);
  const { secret, codes } = await turnOnTotp(state, cookie);
  const refused = await send(state, 'POST', '/account/totp/disable', { cookie, form: { code: '123456' } });
  assert.equal(refused.headers.get('location'), '/account?error=second');
  const fresh = await send(state, 'POST', '/account/recovery/new', { cookie, form: { code: codes[3] } });
  const newCodes = [...(await fresh.text()).matchAll(/<li>([a-z0-9]{4}-[a-z0-9]{4})<\/li>/g)].map((m) => m[1]);
  assert.equal(newCodes.length, 10);
  assert.ok(!newCodes.includes(codes[4]));
  clock += 30000;
  const off = await send(state, 'POST', '/account/totp/disable', { cookie, form: { code: await hotp(secret, stepAt(clock)) } });
  assert.equal(off.headers.get('location'), '/account?notice=totp-off');
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM totp').get().n, 0);
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM recovery_codes').get().n, 0);
  assert.equal((await signInByCode(state, 'reader@example.com')).headers.get('location'), '/account');
});

// --- Passkeys, as a device makes and uses one ---------------------------------------

function cbor(value) {
  const out = [];
  const head = (major, n) => {
    if (n < 24) out.push((major << 5) | n);
    else if (n < 256) out.push((major << 5) | 24, n);
    else out.push((major << 5) | 25, n >> 8, n & 255);
  };
  const write = (v) => {
    if (v instanceof Uint8Array) { head(2, v.length); out.push(...v); }
    else if (typeof v === 'string') { const b = new TextEncoder().encode(v); head(3, b.length); out.push(...b); }
    else if (typeof v === 'number') { if (v >= 0) head(0, v); else head(1, -1 - v); }
    else if (v instanceof Map) { head(5, v.size); for (const [k, x] of v) { write(k); write(x); } }
    else throw new Error('unsupported');
  };
  write(value);
  return Uint8Array.from(out);
}

const b64u = (bytes) => Buffer.from(bytes).toString('base64url');
const fromB64u = (text) => new Uint8Array(Buffer.from(text, 'base64url'));
const sha256 = async (bytes) => new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));

function rawToDer(raw) {
  const int = (bytes) => {
    let b = [...bytes];
    while (b.length > 1 && b[0] === 0 && !(b[1] & 0x80)) b = b.slice(1);
    if (b[0] & 0x80) b = [0, ...b];
    return [0x02, b.length, ...b];
  };
  const body = [...int(raw.slice(0, 32)), ...int(raw.slice(32))];
  return Uint8Array.from([0x30, body.length, ...body]);
}

// A device: a P-256 key pair made for the site, and what it answers.
async function device() {
  const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const jwk = await crypto.subtle.exportKey('jwk', pair.publicKey);
  const credentialId = crypto.getRandomValues(new Uint8Array(16));
  let count = 0;
  const authData = async (attested) => {
    const flags = attested ? 0x45 : 0x05; // user present and verified, with attested data
    const parts = [...(await sha256(new TextEncoder().encode('shnayimmikrah.org'))), flags, 0, 0, 0, count];
    if (attested) {
      const cose = cbor(new Map([[1, 2], [3, -7], [-1, 1], [-2, fromB64u(jwk.x)], [-3, fromB64u(jwk.y)]]));
      parts.push(...new Uint8Array(16), 0, credentialId.length, ...credentialId, ...cose);
    }
    return Uint8Array.from(parts);
  };
  const client = (type, challenge, origin = SITE) => new TextEncoder().encode(JSON.stringify({ type, challenge, origin }));
  return {
    id: b64u(credentialId),
    async create(options, origin) {
      const clientData = client('webauthn.create', options.challenge, origin);
      return {
        clientDataJSON: b64u(clientData),
        attestationObject: b64u(cbor(new Map([['fmt', 'none'], ['attStmt', new Map()], ['authData', await authData(true)]]))),
      };
    },
    async get(challenge, origin, userHandle) {
      count++;
      const clientData = client('webauthn.get', challenge, origin);
      const auth = await authData(false);
      const signed = Uint8Array.from([...auth, ...(await sha256(clientData))]);
      const raw = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, pair.privateKey, signed));
      return {
        id: b64u(credentialId),
        clientDataJSON: b64u(clientData),
        authenticatorData: b64u(auth),
        signature: b64u(rawToDer(raw)),
        userHandle,
      };
    },
  };
}

test('a passkey is added on the account page, and signs in on its own', async () => {
  const state = makeEnv();
  const cookie = await signedIn(state);
  const phone = await device();

  const script = await send(state, 'GET', '/account/passkey.js');
  assert.match(script.headers.get('content-type'), /javascript/);
  assert.match(await script.text(), /navigator\.credentials\.create/);
  assert.match((await send(state, 'GET', '/account', { cookie })).headers.get('content-security-policy'), /script-src 'self'/);

  // Signed out, there is nothing to add a passkey to.
  assert.equal((await send(state, 'POST', '/account/passkey/register-options', { json: {} })).status, 401);
  const { options } = await (await send(state, 'POST', '/account/passkey/register-options', { cookie, json: {} })).json();
  assert.equal(options.rp.id, 'shnayimmikrah.org');
  assert.equal(options.attestation, 'none');
  assert.equal(options.authenticatorSelection.residentKey, 'required');
  // Made for another site, it is refused.
  const elsewhere = await send(state, 'POST', '/account/passkey/register', { cookie, json: await phone.create(options, 'https://evil.example') });
  assert.equal(elsewhere.status, 400);
  const { options: again } = await (await send(state, 'POST', '/account/passkey/register-options', { cookie, json: {} })).json();
  const made = await send(state, 'POST', '/account/passkey/register', { cookie, json: await phone.create(again) });
  assert.equal(made.status, 200, await made.clone().text());
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM passkeys').get().n, 1);
  // Its challenge is used up.
  assert.equal((await send(state, 'POST', '/account/passkey/register', { cookie, json: await phone.create(again) })).status, 400);
  assert.match(await (await send(state, 'GET', '/account', { cookie })).text(), /Passkey added 2026-10-20/);

  // Signing in: a challenge for whichever passkey the browser offers.
  const userHandle = options.user.id;
  const { challenge } = await (await send(state, 'POST', '/account/passkey/signin-options', { json: {} })).json();
  const answer = await phone.get(challenge, SITE, userHandle);
  const signedInNow = await send(state, 'POST', '/account/passkey/signin', { json: answer });
  assert.equal(signedInNow.status, 200, await signedInNow.clone().text());
  assert.deepEqual(await signedInNow.json(), { ok: true, next: '/account' });
  const session = cookieNamed(signedInNow, '__Host-sm_session');
  assert.equal((await send(state, 'GET', '/account', { cookie: session })).status, 200);
  // The same answer again is refused: its challenge is spent.
  assert.equal((await send(state, 'POST', '/account/passkey/signin', { json: answer })).status, 401);
  // So is one signed for another origin, or with another key's signature.
  const { challenge: c2 } = await (await send(state, 'POST', '/account/passkey/signin-options', { json: {} })).json();
  assert.equal((await send(state, 'POST', '/account/passkey/signin', { json: await phone.get(c2, 'https://evil.example', userHandle) })).status, 401);
  const { challenge: c3 } = await (await send(state, 'POST', '/account/passkey/signin-options', { json: {} })).json();
  const forged = { ...(await phone.get(c3, SITE, userHandle)), signature: (await (await device()).get(c3, SITE, userHandle)).signature };
  assert.equal((await send(state, 'POST', '/account/passkey/signin', { json: forged })).status, 401);
  // A passkey skips the second step: it is one already.
  await turnOnTotp(state, cookie);
  const { challenge: c4 } = await (await send(state, 'POST', '/account/passkey/signin-options', { json: {} })).json();
  assert.equal((await send(state, 'POST', '/account/passkey/signin', { json: await phone.get(c4, SITE, userHandle) })).status, 200);

  // Removed, it no longer signs in.
  assert.equal((await send(state, 'POST', '/account/passkey/remove', { cookie, form: { id: phone.id } })).headers.get('location'), '/account?notice=passkey-removed');
  const { challenge: c5 } = await (await send(state, 'POST', '/account/passkey/signin-options', { json: {} })).json();
  assert.equal((await send(state, 'POST', '/account/passkey/signin', { json: await phone.get(c5, SITE, userHandle) })).status, 401);
});

test('an admin can clear a locked-out member’s authenticator and passkeys', async () => {
  const state = makeEnv();
  state.database.prepare("INSERT INTO roles (email, role, granted_at) VALUES ('admin@example.com', 'admin', 0)").run();
  const admin = await signedIn(state, 'admin@example.com');
  const cookie = await signedIn(state, 'reader@example.com');
  await turnOnTotp(state, cookie);
  const id = state.database.prepare("SELECT id FROM users WHERE email = 'reader@example.com'").get().id;
  const page = await (await send(state, 'GET', `/account/admin/accounts/${id}`, { cookie: admin })).text();
  assert.match(page, /<dt>Authenticator<\/dt><dd>on since/);
  const reset = await send(state, 'POST', '/account/admin/action', { cookie: admin, form: { action: 'reset_sign_in', target: String(id), back: `/account/admin/accounts/${id}` } });
  assert.match(reset.headers.get('location'), /done=reset_sign_in/);
  assert.equal(state.database.prepare('SELECT count(*) AS n FROM totp').get().n, 0);
  assert.equal((await signInByCode(state, 'reader@example.com')).headers.get('location'), '/account');
});

test('the CBOR and the signatures a passkey sends are read as WebAuthn writes them', () => {
  const map = cborDecode(cbor(new Map([['fmt', 'none'], [3, -7], ['b', new Uint8Array([1, 2])]]))).value;
  assert.equal(map.get('fmt'), 'none');
  assert.equal(map.get(3), -7);
  assert.deepEqual(map.get('b'), new Uint8Array([1, 2]));
  const raw = Uint8Array.from({ length: 64 }, (_, i) => (i === 0 || i === 32 ? 0x80 : i));
  assert.deepEqual(derToRaw(rawToDer(raw)), raw);
  assert.throws(() => cborDecode(new Uint8Array([0x5f])));
});
