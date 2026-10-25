// The ways of signing in beyond the password (README, Accounts, Second step
// and passkeys): a code sent by email; the second step, a code from an
// authenticator app or a recovery code, asked for after the password or the
// emailed code once the account has turned it on; and passkeys, which sign
// in on their own. The pages are account_pages.js's; a passkey needs the
// browser's WebAuthn, which /account/passkey.js calls.

import {
  FRESH_MS,
  emailOf,
  humanOk,
  limited,
  page,
  readCookie,
  recordTry,
  see,
  sendCode,
  sessionCookie,
  sessionUser,
  to,
} from './accounts.js';
import { constantTimeEqual, keyedHash, randomToken, tokenHash } from './account_crypto.js';
import * as db from './account_db.js';
import {
  RECOVERY_COUNT,
  base32,
  newRecoveryCodes,
  newSecret,
  openSecret,
  otpauthUri,
  recoveryForm,
  sealSecret,
  totpStep,
} from './account_mfa.js';
import {
  accountBody,
  handoffBody,
  emailCodeBody,
  emailCodeEnterBody,
  recoveryBody,
  render,
  strings,
  totpSetupBody,
  twoStepBody,
} from './account_pages.js';
import { PasskeyError, assertionChallenge, b64u, verifyAssertion, verifyRegistration } from './passkeys.js';
import { renderSVG } from './vendor/uqr.mjs';
import { deviceOf } from './devices.js';

const BASE = '/account';
const PENDING_COOKIE = '__Host-sm_pending';
const NO_PASSWORD = { pw_alg: 'none', pw_iter: 0, pw_salt: '', pw_hash: '' };

// --- Sessions -------------------------------------------------------------------

export async function startSession(env, request, userId, now) {
  const token = randomToken();
  await env.LOGS.batch([db.insertSession(env.LOGS, { tokenHash: await tokenHash(token), userId, now, device: deviceOf(request) })]);
  return token;
}

// A __Host- cookie, as the session's is: its path is the whole site's.
function pendingCookie(token) {
  return `${PENDING_COOKIE}=${token}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${db.PENDING_MS / 1000}`;
}

function clearPendingCookie() {
  return `${PENDING_COOKIE}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0`;
}

// Whether the account asks for a second step.
export async function hasSecondStep(env, userId) {
  const totp = await db.findTotp(env.LOGS, userId).first();
  return Boolean(totp?.confirmed_at);
}

// The first step of a sign-in is right (the password, or an emailed code):
// the session, or where the account asks for one, the second step first.
export async function finishSignIn(env, request, userId, lang, now) {
  if (await hasSecondStep(env, userId)) {
    const token = randomToken();
    await db.insertPending(env.LOGS, { tokenHash: await tokenHash(token), userId, now }).run();
    return see(to(`${BASE}/two-step`, lang), pendingCookie(token));
  }
  return see(BASE, sessionCookie(await startSession(env, request, userId, now)));
}

// Whether [input] is the account's second step: a code from its
// authenticator app, used once, or one of its recovery codes, used up.
export async function secondStepOk(env, userId, input, now) {
  const text = String(input ?? '').trim();
  const totp = await db.findTotp(env.LOGS, userId).first();
  if (!totp?.confirmed_at) return false;
  const digits = text.replace(/\s/g, '');
  if (/^\d{6}$/.test(digits)) {
    const step = await totpStep(await openSecret(env, totp.secret_sealed), digits, now, totp.last_step);
    return step != null && Boolean(await db.useTotpStep(env.LOGS, { userId, step, now }).first());
  }
  const code = recoveryForm(text);
  if (code.length !== 8) return false;
  const hash = await keyedHash(env.ACCOUNTS_KEY, `recovery|${userId}|${code}`);
  return Boolean(await db.useRecoveryCode(env.LOGS, userId, hash, now).first());
}

// --- Signing in with an emailed code ----------------------------------------------

// Checks an emailed code for an account, counting a wrong one against it;
// returns the account, or null. A code locks after its tries.
export async function checkCode(env, email, code, now) {
  const user = await db.findUserByEmail(env.LOGS, email).first();
  const row = user && await db.findCode(env.LOGS, user.id).first();
  if (!row || row.expires_at <= now || row.attempts >= db.CODE_TRIES) {
    if (row) await db.deleteCode(env.LOGS, row.id).run();
    return null;
  }
  const expected = await keyedHash(env.ACCOUNTS_KEY, `code|${user.id}|${code}`);
  if (!constantTimeEqual(expected, row.code_hash)) {
    const tries = await db.countCodeTry(env.LOGS, row.id).first();
    if (tries.attempts >= db.CODE_TRIES) await db.deleteCode(env.LOGS, row.id).run();
    return null;
  }
  return user;
}

// What a right code does to its account: the address is confirmed, and if
// this is the first time, any password set before it was confirmed goes,
// as whoever set it never proved the address theirs. The code is used up.
export function confirmedByCode(user, now, LOGS) {
  return [
    ...(user.email_verified_at ? [] : [db.setPassword(LOGS, user.id, NO_PASSWORD), db.deleteSessionsOf(LOGS, user.id)]),
    db.markVerified(LOGS, user.id, now),
    db.deleteCodesOf(LOGS, user.id),
  ];
}

// Emails a code, making the account the first time, without a password.
export async function sendSignInCode(env, email, now) {
  let user = await db.findUserByEmail(env.LOGS, email).first();
  user ??= await db.insertUser(env.LOGS, { email, password: NO_PASSWORD, now }).first();
  await sendCode(env, user.id, email, now);
}

export function emailCodeForm(env, lang, error, status = 200) {
  return page(render(lang, { title: strings(lang).emailCodeTitle, body: emailCodeBody(lang, env.TURNSTILE_SITE_KEY), error, status }));
}

export async function requestSignInCode(request, env, lang, now) {
  const form = await request.formData();
  const email = emailOf(form.get('email'));
  if (!email) return emailCodeForm(env, lang, 'email', 400);
  if (!(await humanOk(env, form))) return emailCodeForm(env, lang, 'human', 403);
  if (await limited(env, request, 'appCode', email, now)) return emailCodeForm(env, lang, 'limited', 429);
  await recordTry(env, request, 'appCode', email, now);
  try {
    await sendSignInCode(env, email, now);
  } catch (error) {
    console.error('sign-in code email failed', error.name);
    return emailCodeForm(env, lang, 'email_send', 503);
  }
  return see(to(`${BASE}/sign-in/code`, lang, { email }));
}

export function enterCodeForm(lang, email, error, status = 200) {
  return page(render(lang, { title: strings(lang).emailCodeTitle, body: emailCodeEnterBody(lang, email), error, status }));
}

export async function signInWithCode(request, env, lang, now) {
  const form = await request.formData();
  const email = emailOf(form.get('email'));
  const code = String(form.get('code') ?? '').trim();
  if (!email || !/^\d{6}$/.test(code)) return enterCodeForm(lang, email ?? '', 'code', 400);
  if (await limited(env, request, 'verify', email, now)) return enterCodeForm(lang, email, 'limited', 429);
  await recordTry(env, request, 'verify', email, now);
  const user = await checkCode(env, email, code, now);
  if (!user) return enterCodeForm(lang, email, 'code', 400);
  await env.LOGS.batch(confirmedByCode(user, now, env.LOGS));
  return finishSignIn(env, request, user.id, lang, now);
}

// --- The second step ------------------------------------------------------------------

async function pendingOf(request, env, now) {
  const token = readCookie(request, PENDING_COOKIE);
  if (!token) return null;
  const hash = await tokenHash(token);
  const row = await db.findPending(env.LOGS, hash, now).first();
  return row ? { ...row, hash } : null;
}

export async function twoStepForm(request, env, lang, now) {
  if (!(await pendingOf(request, env, now))) return see(to(`${BASE}/sign-in`, lang));
  return page(render(lang, { title: strings(lang).twoStepTitle, body: twoStepBody(lang) }));
}

export async function twoStep(request, env, lang, now) {
  const pending = await pendingOf(request, env, now);
  if (!pending) return see(to(`${BASE}/sign-in`, lang));
  const again = (error, status) => page(render(lang, { title: strings(lang).twoStepTitle, body: twoStepBody(lang), error, status }));
  if (pending.attempts >= db.PENDING_TRIES || await limited(env, request, 'secondStep', pending.email, now)) {
    await db.deletePending(env.LOGS, pending.hash).run();
    return page(render(lang, { title: strings(lang).signInTitle, error: 'limited', status: 429 }), clearPendingCookie());
  }
  const form = await request.formData();
  if (!(await secondStepOk(env, pending.user_id, form.get('code'), now))) {
    await db.countPendingTry(env.LOGS, pending.hash).run();
    await recordTry(env, request, 'secondStep', pending.email, now);
    return again('second', 401);
  }
  await db.deletePending(env.LOGS, pending.hash).run();
  const response = see(BASE, sessionCookie(await startSession(env, request, pending.user_id, now)));
  response.headers.append('Set-Cookie', clearPendingCookie());
  return response;
}

// --- The authenticator app, on the account page ------------------------------------

// Starts setting one up: a new secret, kept until it is confirmed.
export async function startTotp(request, env, lang, now) {
  const user = await sessionUser(request, env, now);
  if (!user) return see(to(`${BASE}/sign-in`, lang));
  if (await hasSecondStep(env, user.id)) return see(to(BASE, lang));
  await db.startTotp(env.LOGS, { userId: user.id, sealed: await sealSecret(env, newSecret()), now }).run();
  return see(to(`${BASE}/totp`, lang));
}

async function setupPage(env, user, lang, error, status = 200) {
  const totp = await db.findTotp(env.LOGS, user.id).first();
  if (!totp || totp.confirmed_at) return see(to(BASE, lang));
  const secret = await openSecret(env, totp.secret_sealed);
  const uri = otpauthUri(secret, user.email);
  const qr = renderSVG(uri, { border: 2, pixelSize: 6, blackColor: '#000', whiteColor: '#fff' });
  const key = base32(secret).replace(/(.{4})/g, '$1 ').trim();
  return page(render(lang, { title: strings(lang).totpSetupTitle, body: totpSetupBody(lang, { qr, key, uri }), error, status }));
}

export async function totpSetup(request, env, lang, now) {
  const user = await sessionUser(request, env, now);
  if (!user) return see(to(`${BASE}/sign-in`, lang));
  return setupPage(env, user, lang);
}

async function issueRecoveryCodes(env, userId) {
  const codes = newRecoveryCodes();
  const hashes = await Promise.all(codes.map((c) => keyedHash(env.ACCOUNTS_KEY, `recovery|${userId}|${recoveryForm(c)}`)));
  await env.LOGS.batch(db.replaceRecoveryCodes(env.LOGS, userId, hashes));
  return codes;
}

// Confirms the set-up with a code from the app, and shows the recovery
// codes, once.
export async function confirmTotp(request, env, lang, now) {
  const user = await sessionUser(request, env, now);
  if (!user) return see(to(`${BASE}/sign-in`, lang));
  const totp = await db.findTotp(env.LOGS, user.id).first();
  if (!totp || totp.confirmed_at) return see(to(BASE, lang));
  if (await limited(env, request, 'secondStep', user.email, now)) return setupPage(env, user, lang, 'limited', 429);
  const form = await request.formData();
  const code = String(form.get('code') ?? '').replace(/\s/g, '');
  const step = await totpStep(await openSecret(env, totp.secret_sealed), code, now, totp.last_step);
  if (step == null || !(await db.useTotpStep(env.LOGS, { userId: user.id, step, now, confirm: true }).first())) {
    await recordTry(env, request, 'secondStep', user.email, now);
    return setupPage(env, user, lang, 'second', 400);
  }
  const codes = await issueRecoveryCodes(env, user.id);
  return page(render(lang, { title: strings(lang).recoveryTitle, body: recoveryBody(lang, codes), notice: 'totp-on' }));
}

// Turning it off, or making new recovery codes, asks for the second step.
async function withSecondStep(request, env, lang, now, then) {
  const user = await sessionUser(request, env, now);
  if (!user) return see(to(`${BASE}/sign-in`, lang));
  const form = await request.formData();
  if (await limited(env, request, 'secondStep', user.email, now)) return see(to(BASE, lang, { error: 'limited' }));
  if (!(await secondStepOk(env, user.id, form.get('code'), now))) {
    await recordTry(env, request, 'secondStep', user.email, now);
    return see(to(BASE, lang, { error: 'second' }));
  }
  return then(user);
}

export function disableTotp(request, env, lang, now) {
  return withSecondStep(request, env, lang, now, async (user) => {
    await env.LOGS.batch(db.deleteTotp(env.LOGS, user.id));
    return see(to(BASE, lang, { notice: 'totp-off' }));
  });
}

export function newRecovery(request, env, lang, now) {
  return withSecondStep(request, env, lang, now, async (user) => {
    const codes = await issueRecoveryCodes(env, user.id);
    return page(render(lang, { title: strings(lang).recoveryTitle, body: recoveryBody(lang, codes) }));
  });
}

// The account page, with its ways of signing in.
export async function accountPage(env, user, lang, { notice, error, status = 200 } = {}, now = Date.now()) {
  const [totp, left, keys, sessions, backup] = await Promise.all([
    db.findTotp(env.LOGS, user.id).first(),
    db.recoveryLeft(env.LOGS, user.id).first(),
    db.passkeysOf(env.LOGS, user.id).all(),
    db.sessionsOf(env.LOGS, user.id, now).all(),
    db.backedUpStreak(env.LOGS, user.id).first(),
  ]);
  const security = {
    totp: Boolean(totp?.confirmed_at),
    recoveryLeft: left?.n ?? 0,
    passkeys: keys.results,
    recoveryCount: RECOVERY_COUNT,
    sessions: sessions.results,
    thisSession: user.session_id,
    // An account with no password may be given one soon after signing in.
    fresh: now - (user.session_at ?? 0) <= FRESH_MS,
    streak: streakOf(backup),
  };
  return page(render(lang, { title: strings(lang).accountTitle, body: accountBody(lang, user, security), notice, error, status, script: true }));
}

// The streak in the app's backup, if it holds one this can read: the days
// on track, the parsha streak in weeks, and the day the app counted them.
export function streakOf(backup) {
  let streak = null;
  try {
    streak = backup?.streak ? JSON.parse(backup.streak) : null;
  } catch {
    return null;
  }
  const count = (n) => (Number.isSafeInteger(n) && n >= 0 && n < 100000 ? n : null);
  const days = count(streak?.days);
  const weeks = count(streak?.weeks);
  if (days == null || weeks == null) return null;
  const asOf = typeof streak.asOf === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(streak.asOf) ? streak.asOf : null;
  return { days, weeks, asOf };
}

// --- From the app ---------------------------------------------------------------------

// A link from the app, signed in, to a page of the site (api.js, handoff):
// it asks before signing this browser in, so that a link someone else sent
// can't sign it in to their account unasked.
export async function handoffForm(env, url, lang, now) {
  const t = strings(lang);
  const token = url.searchParams.get('t') || '';
  const row = /^[A-Za-z0-9_-]{20,100}$/.test(token) ? await db.findHandoff(env.LOGS, await tokenHash(token), now).first() : null;
  if (!row) return page(render(lang, { title: t.handoffTitle, error: 'handoff', status: 410 }));
  return page(render(lang, { title: t.handoffTitle, body: handoffBody(lang, row.email, token) }));
}

export async function handoff(request, env, lang, now) {
  const t = strings(lang);
  const form = await request.formData();
  const token = String(form.get('token') ?? '');
  const row = /^[A-Za-z0-9_-]{20,100}$/.test(token) ? await db.claimHandoff(env.LOGS, await tokenHash(token), now).first() : null;
  const user = row && await db.findUserById(env.LOGS, row.user_id).first();
  if (!user?.email_verified_at) return page(render(lang, { title: t.handoffTitle, error: 'handoff', status: 410 }));
  return see(to(/^\/account(\/admin)?$/.test(row.next) ? row.next : BASE, lang), sessionCookie(await startSession(env, request, user.id, now)));
}

// --- Passkeys ------------------------------------------------------------------------

const JSON_HEADERS = {
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
};

function json(value, status = 200, cookie) {
  const headers = new Headers(JSON_HEADERS);
  if (cookie) headers.append('Set-Cookie', cookie);
  return new Response(JSON.stringify(value), { status, headers });
}

async function readJson(request) {
  try {
    return await request.json();
  } catch {
    return {};
  }
}

async function challengeHash(challenge) {
  return tokenHash(String(challenge));
}

async function newChallenge(env, purpose, userId, now) {
  const challenge = randomToken(32);
  await db.insertChallenge(env.LOGS, { challengeHash: await challengeHash(challenge), userId, purpose, now }).run();
  return challenge;
}

function relyingParty(env) {
  return { rpId: env.CANONICAL_HOST, origin: `https://${env.CANONICAL_HOST}` };
}

// What the browser needs to make a passkey for the account signed in.
export async function registerOptions(request, env, now) {
  const user = await sessionUser(request, env, now);
  if (!user) return json({ error: 'not_signed_in' }, 401);
  const { results } = await db.passkeysOf(env.LOGS, user.id).all();
  if (results.length >= 20) return json({ error: 'too_many' }, 400);
  const challenge = await newChallenge(env, 'register', user.id, now);
  return json({
    options: {
      challenge,
      rp: { id: env.CANONICAL_HOST, name: 'Shnayim Mikrah' },
      user: { id: b64u(new TextEncoder().encode(String(user.id))), name: user.email, displayName: user.email },
      pubKeyCredParams: [{ type: 'public-key', alg: -7 }, { type: 'public-key', alg: -257 }],
      timeout: db.CHALLENGE_MS,
      attestation: 'none',
      authenticatorSelection: { residentKey: 'required', requireResidentKey: true, userVerification: 'preferred' },
      excludeCredentials: results.map((k) => ({ type: 'public-key', id: k.id })),
    },
  });
}

export async function register(request, env, now) {
  const user = await sessionUser(request, env, now);
  if (!user) return json({ error: 'not_signed_in' }, 401);
  const body = await readJson(request);
  try {
    const made = await verifyRegistration(body, relyingParty(env));
    const claimed = await db.claimChallenge(env.LOGS, { challengeHash: await challengeHash(made.challenge), purpose: 'register', now }).first();
    if (!claimed || claimed.user_id !== user.id) return json({ error: 'challenge' }, 400);
    if (await db.findPasskey(env.LOGS, made.credentialId).first()) return json({ error: 'exists' }, 409);
    await db.insertPasskey(env.LOGS, { id: made.credentialId, userId: user.id, jwk: made.jwk, alg: made.alg, signCount: made.signCount, now }).run();
    return json({ ok: true });
  } catch (error) {
    if (error instanceof PasskeyError) return json({ error: error.message }, 400);
    throw error;
  }
}

// A challenge for signing in with a passkey, whichever account it is for:
// the browser offers the passkeys it has for the site.
export async function signInOptions(request, env, now) {
  if (await limited(env, request, 'passkey', null, now)) return json({ error: 'limited' }, 429);
  // Each challenge is a row: they count against the address's limit too.
  await recordTry(env, request, 'passkey', null, now);
  const challenge = await newChallenge(env, 'signin', null, now);
  return json({ challenge, rpId: env.CANONICAL_HOST, timeout: db.CHALLENGE_MS, userVerification: 'preferred' });
}

export async function signInWithPasskey(request, env, now) {
  if (await limited(env, request, 'passkey', null, now)) return json({ error: 'limited' }, 429);
  const body = await readJson(request);
  const refused = async (error) => {
    await recordTry(env, request, 'passkey', null, now);
    return json({ error }, 401);
  };
  try {
    const challenge = assertionChallenge(body.clientDataJSON, relyingParty(env).origin);
    const claimed = await db.claimChallenge(env.LOGS, { challengeHash: await challengeHash(challenge), purpose: 'signin', now }).first();
    if (!claimed) return refused('challenge');
    const key = typeof body.id === 'string' ? await db.findPasskey(env.LOGS, body.id).first() : null;
    if (!key || !key.email_verified_at) return refused('unknown');
    if (body.userHandle && body.userHandle !== b64u(new TextEncoder().encode(String(key.user_id)))) return refused('unknown');
    const signCount = await verifyAssertion(body, { rpId: relyingParty(env).rpId, jwk: JSON.parse(key.public_key), alg: key.alg, signCount: key.sign_count });
    await db.usePasskey(env.LOGS, { id: key.id, signCount, now }).run();
    return json({ ok: true, next: BASE }, 200, sessionCookie(await startSession(env, request, key.user_id, now)));
  } catch (error) {
    if (error instanceof PasskeyError) return refused(error.message);
    throw error;
  }
}

export async function removePasskey(request, env, lang, now) {
  const user = await sessionUser(request, env, now);
  if (!user) return see(to(`${BASE}/sign-in`, lang));
  const form = await request.formData();
  await db.deletePasskey(env.LOGS, user.id, String(form.get('id') ?? '')).run();
  return see(to(BASE, lang, { notice: 'passkey-removed' }));
}

// The pages' script for passkeys: making one on the account page, and
// signing in with one, each from a button the page shows only where the
// browser can. Its messages are the page's (data-* on the buttons).
export function passkeyScript() {
  return new Response(PASSKEY_JS, {
    headers: {
      'Content-Type': 'text/javascript; charset=utf-8',
      'Cache-Control': 'no-cache',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

const PASSKEY_JS = `'use strict';
(() => {
  const b64u = (buffer) => btoa(String.fromCharCode(...new Uint8Array(buffer))).replace(/\\+/g, '-').replace(/\\//g, '_').replace(/=+$/, '');
  const bytes = (text) => Uint8Array.from(atob(text.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
  const post = async (path, body) => {
    const response = await fetch(path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}), credentials: 'same-origin' });
    const data = await response.json().catch(() => ({}));
    return { ok: response.ok, ...data };
  };
  const supported = Boolean(window.PublicKeyCredential && navigator.credentials);
  for (const el of document.querySelectorAll('[data-passkey]')) el.hidden = !supported;
  const status = document.getElementById('passkey-status');
  const say = (text) => { if (status) status.textContent = text; };

  const add = document.getElementById('passkey-add');
  if (add) add.addEventListener('click', async () => {
    add.disabled = true;
    try {
      const got = await post('/account/passkey/register-options');
      if (!got.ok) throw new Error(got.error);
      const o = got.options;
      const credential = await navigator.credentials.create({ publicKey: {
        ...o,
        challenge: bytes(o.challenge),
        user: { ...o.user, id: bytes(o.user.id) },
        excludeCredentials: o.excludeCredentials.map((c) => ({ ...c, id: bytes(c.id) })),
      } });
      const saved = await post('/account/passkey/register', {
        clientDataJSON: b64u(credential.response.clientDataJSON),
        attestationObject: b64u(credential.response.attestationObject),
      });
      if (!saved.ok) throw new Error(saved.error);
      location.assign(add.dataset.done);
    } catch (error) {
      say(add.dataset.failed);
      add.disabled = false;
    }
  });

  const signIn = document.getElementById('passkey-signin');
  if (signIn) signIn.addEventListener('click', async () => {
    signIn.disabled = true;
    try {
      const o = await post('/account/passkey/signin-options');
      if (!o.ok) throw new Error(o.error);
      const credential = await navigator.credentials.get({ publicKey: {
        challenge: bytes(o.challenge),
        rpId: o.rpId,
        timeout: o.timeout,
        userVerification: o.userVerification,
      } });
      const r = credential.response;
      const done = await post('/account/passkey/signin', {
        id: b64u(credential.rawId),
        clientDataJSON: b64u(r.clientDataJSON),
        authenticatorData: b64u(r.authenticatorData),
        signature: b64u(r.signature),
        userHandle: r.userHandle ? b64u(r.userHandle) : null,
      });
      if (!done.ok) throw new Error(done.error);
      location.assign(signIn.dataset.next || done.next);
    } catch (error) {
      say(signIn.dataset.failed);
      signIn.disabled = false;
    }
  });
})();
`;
