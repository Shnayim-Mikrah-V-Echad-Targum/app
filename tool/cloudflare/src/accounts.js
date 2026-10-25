// The accounts on shnayimmikrah.org: sign-up with a code sent by email, sign-in,
// sign-out, a password reset by emailed link, and deleting an account. The
// pages are plain forms (account_pages.js), the rows are in D1 (account_db.js),
// the secrets are hashed (account_crypto.js) and the email goes through Resend
// (mail.js). Every answer that could tell whether an address has an account is
// the same for both, and the limits count per address and per email.

import { dayOf, ipKey, isAccountPath } from './rules.js';
import {
  PBKDF2_ITERATIONS,
  PW_ALG,
  constantTimeEqual,
  dummyPasswordRow,
  hashPassword,
  keyedHash,
  randomCode,
  randomToken,
  tokenHash,
  verifyPassword,
} from './account_crypto.js';
import * as db from './account_db.js';
import { deleteMember } from './community_db.js';
import { codeMail, resetMail, sendMail } from './mail.js';
import * as methods from './account_methods.js';
import {
  langOf,
  render,
  resetBody,
  resetCompleteBody,
  signInBody,
  signUpBody,
  strings,
  verifyBody,
} from './account_pages.js';

const BASE = '/account';
const COOKIE = '__Host-sm_session';
const VERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';
// A passkey's registration is the largest post the pages make.
const MAX_BODY = 8192;
const MINUTE = 60000;
const HOUR = 60 * MINUTE;

// Tries allowed in a window, per email and per address (see limited()).
const LIMITS = {
  signup: { email: [5, HOUR], address: [20, HOUR] },
  verify: { email: [10, 15 * MINUTE], address: [30, 15 * MINUTE] },
  resend: { email: [3, 15 * MINUTE], address: [10, 15 * MINUTE] },
  signin: { email: [10, 15 * MINUTE], address: [30, 15 * MINUTE] },
  reset: { email: [5, HOUR], address: [20, HOUR] },
  resetComplete: { address: [30, 15 * MINUTE] },
  // The app's sign-in code (api.js), which has no Turnstile to pass, and
  // the site's (account_methods.js).
  appCode: { email: [5, 15 * MINUTE], address: [20, 15 * MINUTE] },
  // Wrong codes at the second step, per account and per address.
  secondStep: { email: [10, 15 * MINUTE], address: [30, 15 * MINUTE] },
  // Passkey sign-ins begun, and failed, per address.
  passkey: { address: [60, 15 * MINUTE] },
};

const SECURITY = {
  'Cache-Control': 'no-store',
  // Not no-referrer: under that policy a browser sends "Origin: null" with a
  // form, and sameOrigin() would refuse every post.
  'Referrer-Policy': 'same-origin',
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'Content-Security-Policy': [
    "default-src 'none'",
    // The site's own passkey script (account_methods.js), and Turnstile's.
    "script-src 'self' https://challenges.cloudflare.com",
    "style-src 'unsafe-inline'",
    'frame-src https://challenges.cloudflare.com',
    "connect-src 'self' https://challenges.cloudflare.com",
    "form-action 'self'",
    "base-uri 'none'",
    "frame-ancestors 'none'",
  ].join('; '),
};

// The accounts run only once their secrets and their email are set up.
export function configured(env) {
  return Boolean(
    env.LOGS && env.ACCOUNTS_KEY && env.IP_SALT && env.TURNSTILE_SECRET_KEY
      && env.TURNSTILE_SITE_KEY && env.RESEND_API_KEY && env.ACCOUNTS_EMAIL_FROM,
  );
}

export async function handleAccount(request, env, url, now = Date.now()) {
  const lang = langOf(url, request.headers.get('accept-language'));
  if (!configured(env)) return page(render(lang, { title: strings(lang).accountTitle, error: 'unavailable', status: 503 }));
  try {
    return await route(request, env, url, lang, now);
  } catch (error) {
    console.error('account request failed', error.name);
    return page(render(lang, { title: strings(lang).accountTitle, error: 'unavailable', status: 500 }));
  }
}

async function route(request, env, url, lang, now) {
  const t = strings(lang);
  const siteKey = env.TURNSTILE_SITE_KEY;
  const path = url.pathname.replace(/\/+$/, '');
  const isPost = request.method === 'POST';

  if (isPost && (!sameOrigin(request, env) || Number(request.headers.get('content-length') || 0) > MAX_BODY)) {
    return page(render(lang, { title: t.accountTitle, error: 'forbidden', status: 403 }));
  }

  switch (`${request.method} ${path}`) {
    case `GET ${BASE}`: {
      const user = await currentUser(request, env, now);
      if (!user) return see(to(`${BASE}/sign-in`, lang));
      return methods.accountPage(env, user, lang, { notice: url.searchParams.get('notice'), error: url.searchParams.get('error') });
    }
    case `GET ${BASE}/sign-in/email`:
      return methods.emailCodeForm(env, lang);
    case `POST ${BASE}/sign-in/email`:
      return methods.requestSignInCode(request, env, lang, now);
    case `GET ${BASE}/sign-in/code`:
      return methods.enterCodeForm(lang, url.searchParams.get('email') || '');
    case `POST ${BASE}/sign-in/code`:
      return methods.signInWithCode(request, env, lang, now);
    case `GET ${BASE}/two-step`:
      return methods.twoStepForm(request, env, lang, now);
    case `POST ${BASE}/two-step`:
      return methods.twoStep(request, env, lang, now);
    case `POST ${BASE}/totp/start`:
      return methods.startTotp(request, env, lang, now);
    case `GET ${BASE}/totp`:
      return methods.totpSetup(request, env, lang, now);
    case `POST ${BASE}/totp/confirm`:
      return methods.confirmTotp(request, env, lang, now);
    case `POST ${BASE}/totp/disable`:
      return methods.disableTotp(request, env, lang, now);
    case `POST ${BASE}/recovery/new`:
      return methods.newRecovery(request, env, lang, now);
    case `GET ${BASE}/passkey.js`:
      return methods.passkeyScript();
    case `POST ${BASE}/passkey/register-options`:
      return methods.registerOptions(request, env, now);
    case `POST ${BASE}/passkey/register`:
      return methods.register(request, env, now);
    case `POST ${BASE}/passkey/signin-options`:
      return methods.signInOptions(request, env, now);
    case `POST ${BASE}/passkey/signin`:
      return methods.signInWithPasskey(request, env, now);
    case `POST ${BASE}/passkey/remove`:
      return methods.removePasskey(request, env, lang, now);
    case `GET ${BASE}/sign-up`:
      return page(render(lang, { title: t.signUpTitle, body: signUpBody(lang, siteKey) }));
    case `POST ${BASE}/sign-up`:
      return signUp(request, env, lang, now);
    case `GET ${BASE}/sign-in`:
      return page(render(lang, { title: t.signInTitle, body: signInBody(lang, siteKey), notice: url.searchParams.get('notice'), script: true }));
    case `POST ${BASE}/sign-in`:
      return signIn(request, env, lang, now);
    case `POST ${BASE}/sign-out`: {
      const token = readCookie(request);
      if (token) await db.deleteSession(env.LOGS, await tokenHash(token)).run();
      return see(to(`${BASE}/sign-in`, lang, { notice: 'signed-out' }), clearCookie());
    }
    case `GET ${BASE}/verify`:
      return page(render(lang, {
        title: t.verifyTitle,
        body: verifyBody(lang, url.searchParams.get('email') || ''),
        notice: url.searchParams.get('notice'),
      }));
    case `POST ${BASE}/verify`:
      return verify(request, env, lang, now);
    case `POST ${BASE}/verify/resend`:
      return resend(request, env, lang, now);
    case `GET ${BASE}/reset`:
      return page(render(lang, { title: t.resetTitle, body: resetBody(lang, siteKey), notice: url.searchParams.get('notice') }));
    case `POST ${BASE}/reset`:
      return requestReset(request, env, lang, now);
    case `GET ${BASE}/reset/complete`:
      return resetForm(url, env, lang, now);
    case `POST ${BASE}/reset/complete`:
      return resetComplete(request, env, lang, now);
    case `POST ${BASE}/delete`:
      return deleteAccount(request, env, lang, now);
    default:
      return page(render(lang, { title: t.accountTitle, error: 'notFound', status: 404 }));
  }
}

async function signUp(request, env, lang, now) {
  const t = strings(lang);
  const form = await request.formData();
  const email = emailOf(form.get('email'));
  const password = passwordOf(form.get('password'));
  const again = (error, status) => page(render(lang, { title: t.signUpTitle, body: signUpBody(lang, env.TURNSTILE_SITE_KEY), error, status }));

  if (!email) return again('email', 400);
  if (!password) return again('password', 400);
  if (!(await humanOk(env, form))) return again('human', 403);
  if (await limited(env, request, 'signup', email, now)) return again('limited', 429);
  await recordTry(env, request, 'signup', email, now);

  // The password is hashed for every address, present or not, so the answer
  // takes the same time either way.
  const hashed = await hashPassword(password);
  const user = await db.findUserByEmail(env.LOGS, email).first();
  try {
    if (!user) {
      const created = await db.insertUser(env.LOGS, { email, password: hashed, now }).first();
      await sendCode(env, created.id, email, now);
    } else if (!user.email_verified_at) {
      await env.LOGS.batch([db.setPassword(env.LOGS, user.id, hashed)]);
      await sendCode(env, user.id, email, now);
    }
  } catch (error) {
    console.error('sign-up email failed', error.name);
    return page(render(lang, { title: t.signUpTitle, error: 'email_send', status: 503 }));
  }
  // A verified address gets this same answer, and no email.
  return see(to(`${BASE}/verify`, lang, { notice: 'check-email', email }));
}

async function verify(request, env, lang, now) {
  const t = strings(lang);
  const form = await request.formData();
  const email = emailOf(form.get('email'));
  const code = String(form.get('code') ?? '').trim();
  const again = (error, status) => page(render(lang, {
    title: t.verifyTitle,
    body: verifyBody(lang, email || ''),
    error,
    status,
  }));

  if (!email || !/^\d{6}$/.test(code)) return again('code', 400);
  if (await limited(env, request, 'verify', email, now)) return again('limited', 429);
  await recordTry(env, request, 'verify', email, now);

  const user = await db.findUserByEmail(env.LOGS, email).first();
  if (!user || user.email_verified_at) return again('code', 400);
  const row = await db.findCode(env.LOGS, user.id).first();
  if (!row || row.expires_at <= now || row.attempts >= db.CODE_TRIES) {
    if (row) await db.deleteCode(env.LOGS, row.id).run();
    return again('code', 400);
  }
  const expected = await keyedHash(env.ACCOUNTS_KEY, `code|${user.id}|${code}`);
  if (!constantTimeEqual(expected, row.code_hash)) {
    const tries = await db.countCodeTry(env.LOGS, row.id).first();
    if (tries.attempts >= db.CODE_TRIES) await db.deleteCode(env.LOGS, row.id).run();
    return again('code', 400);
  }

  const token = randomToken();
  await env.LOGS.batch([
    db.markVerified(env.LOGS, user.id, now),
    db.deleteCodesOf(env.LOGS, user.id),
    db.insertSession(env.LOGS, { tokenHash: await tokenHash(token), userId: user.id, now }),
  ]);
  return see(BASE, sessionCookie(token));
}

async function resend(request, env, lang, now) {
  const t = strings(lang);
  const form = await request.formData();
  const email = emailOf(form.get('email'));
  if (!email) return see(to(`${BASE}/verify`, lang, { notice: 'check-email' }));
  if (await limited(env, request, 'resend', email, now)) {
    return page(render(lang, { title: t.verifyTitle, body: verifyBody(lang, email), error: 'limited', status: 429 }));
  }
  await recordTry(env, request, 'resend', email, now);
  const user = await db.findUserByEmail(env.LOGS, email).first();
  if (user && !user.email_verified_at) {
    try {
      await sendCode(env, user.id, email, now);
    } catch (error) {
      console.error('resend email failed', error.name);
    }
  }
  return see(to(`${BASE}/verify`, lang, { notice: 'check-email', email }));
}

async function signIn(request, env, lang, now) {
  const t = strings(lang);
  const form = await request.formData();
  const email = emailOf(form.get('email'));
  const password = String(form.get('password') ?? '');
  const again = (error, status) => page(render(lang, { title: t.signInTitle, body: signInBody(lang, env.TURNSTILE_SITE_KEY), error, status }));

  if (!(await humanOk(env, form))) return again('human', 403);
  if (await limited(env, request, 'signin', email, now)) return again('limited', 429);
  if (!email || !password || password.length > 128) {
    await recordTry(env, request, 'signin', email, now);
    return again('credentials', 401);
  }

  // Only a failed try counts toward the limits: a sign-in that works writes nothing.
  // An account made in the app has no password: it is checked against the
  // dummy row too, so that it takes as long to refuse as any other.
  const user = await db.findUserByEmail(env.LOGS, email).first();
  const usable = user?.pw_alg === PW_ALG;
  const ok = await verifyPassword(password, usable ? user : await dummyPasswordRow());
  if (!usable || !ok) {
    await recordTry(env, request, 'signin', email, now);
    return again('credentials', 401);
  }

  if (user.pw_iter < PBKDF2_ITERATIONS) {
    await env.LOGS.batch([db.setPassword(env.LOGS, user.id, await hashPassword(password))]);
  }
  if (!user.email_verified_at) {
    try {
      await sendCode(env, user.id, email, now);
    } catch (error) {
      console.error('sign-in email failed', error.name);
    }
    return see(to(`${BASE}/verify`, lang, { notice: 'unverified', email }));
  }

  return methods.finishSignIn(env, user.id, lang, now);
}

async function requestReset(request, env, lang, now) {
  const t = strings(lang);
  const form = await request.formData();
  const email = emailOf(form.get('email'));
  const again = (error, status) => page(render(lang, { title: t.resetTitle, body: resetBody(lang, env.TURNSTILE_SITE_KEY), error, status }));

  if (!email) return again('email', 400);
  if (!(await humanOk(env, form))) return again('human', 403);
  if (await limited(env, request, 'reset', email, now)) return again('limited', 429);
  await recordTry(env, request, 'reset', email, now);

  const user = await db.findUserByEmail(env.LOGS, email).first();
  if (user && user.email_verified_at) {
    const token = randomToken();
    await env.LOGS.batch(db.replaceResetToken(env.LOGS, { userId: user.id, tokenHash: await tokenHash(token), now }));
    const link = `https://${env.CANONICAL_HOST}${BASE}/reset/complete?${lang === 'he' ? 'lang=he&' : ''}token=${token}`;
    try {
      await sendMail(env, email, resetMail(link));
    } catch (error) {
      console.error('reset email failed', error.name);
    }
  }
  return see(to(`${BASE}/reset`, lang, { notice: 'reset-sent' }));
}

async function resetForm(url, env, lang, now) {
  const t = strings(lang);
  const token = url.searchParams.get('token') || '';
  const valid = token && await db.findResetToken(env.LOGS, await tokenHash(token), now).first();
  if (!valid) return page(render(lang, { title: t.resetTitle, body: resetBody(lang, env.TURNSTILE_SITE_KEY), error: 'link', status: 400 }));
  return page(render(lang, { title: t.resetCompleteTitle, body: resetCompleteBody(lang, token, env.TURNSTILE_SITE_KEY) }));
}

async function resetComplete(request, env, lang, now) {
  const t = strings(lang);
  const form = await request.formData();
  const token = String(form.get('token') ?? '');
  const password = passwordOf(form.get('password'));
  const again = (error, status) => page(render(lang, {
    title: t.resetCompleteTitle,
    body: resetCompleteBody(lang, token, env.TURNSTILE_SITE_KEY),
    error,
    status,
  }));

  if (!password) return again('password', 400);
  if (!(await humanOk(env, form))) return again('human', 403);
  if (await limited(env, request, 'resetComplete', null, now)) return again('limited', 429);
  await recordTry(env, request, 'resetComplete', null, now);

  // The link is claimed first, so that only one request can use it.
  const claimed = await db.claimResetToken(env.LOGS, await tokenHash(token), now).first();
  if (!claimed) return again('link', 400);
  const hashed = await hashPassword(password);
  await env.LOGS.batch([
    db.setPassword(env.LOGS, claimed.user_id, hashed),
    db.deleteSessionsOf(env.LOGS, claimed.user_id),
    db.deleteResetTokensOf(env.LOGS, claimed.user_id),
  ]);
  return see(to(`${BASE}/sign-in`, lang, { notice: 'reset-done' }));
}

async function deleteAccount(request, env, lang, now) {
  const t = strings(lang);
  const user = await currentUser(request, env, now);
  if (!user) return see(to(`${BASE}/sign-in`, lang));
  const form = await request.formData();
  const password = String(form.get('password') ?? '');
  const again = (error, status) => methods.accountPage(env, user, lang, { error, status });

  // An account made in the app, by code, has no password to ask for: the
  // session is the proof, as it is in the app.
  if (user.pw_alg === PW_ALG) {
    if (await limited(env, request, 'signin', user.email, now)) return again('limited', 429);
    const row = await db.findUserByEmail(env.LOGS, user.email).first();
    if (!row || !(await verifyPassword(password, row))) {
      await recordTry(env, request, 'signin', user.email, now);
      return again('credentials', 401);
    }
  }
  await deleteEverything(env, user.id);
  return see(to(`${BASE}/sign-in`, lang, { notice: 'deleted' }), clearCookie());
}

// Deletes an account with everything its owner posted in the community.
export async function deleteEverything(env, userId) {
  await env.LOGS.batch([...deleteMember(env.LOGS, userId), ...db.deleteAccount(env.LOGS, userId)]);
}

// The daily clean-up: the accounts' rows that have passed their time.
export async function accountCleanup(env, now) {
  await env.LOGS.batch(db.accountCleanup(env.LOGS, now));
}

export async function sendCode(env, userId, email, now) {
  const code = randomCode();
  const codeHash = await keyedHash(env.ACCOUNTS_KEY, `code|${userId}|${code}`);
  await env.LOGS.batch(db.replaceCode(env.LOGS, { userId, codeHash, now }));
  await sendMail(env, email, codeMail(code));
}

// The Turnstile check on a form. A form without the widget's answer fails.
export async function humanOk(env, form) {
  const token = form.get('cf-turnstile-response');
  if (!token) return false;
  const response = await fetch(VERIFY_URL, {
    method: 'POST',
    body: new URLSearchParams({ secret: env.TURNSTILE_SECRET_KEY, response: String(token) }),
  });
  if (!response.ok) return false;
  const result = await response.json().catch(() => null);
  return result?.success === true;
}

// The keys a try counts against in a scope: a keyed hash of the email, and the
// visitor's address as the visit log's keyed hash (never the address itself).
async function limitKeys(env, request, scope, email, now) {
  const limits = LIMITS[scope];
  const keys = [];
  if (email && limits.email) {
    const [limit, windowMs] = limits.email;
    keys.push({ key: await keyedHash(env.ACCOUNTS_KEY, `${scope}|${email}`), limit, windowMs });
  }
  const address = await ipKey(request.headers.get('cf-connecting-ip'), env.IP_SALT, dayOf(now));
  if (address && limits.address) {
    const [limit, windowMs] = limits.address;
    keys.push({ key: `${scope}|${address}`, limit, windowMs });
  }
  return keys;
}

// Whether a try is refused, because a key has used up its tries in its window.
// Reads only, so a refused try writes nothing.
export async function limited(env, request, scope, email, now) {
  for (const { key, limit, windowMs } of await limitKeys(env, request, scope, email, now)) {
    if (await db.isOverLimit(env.LOGS, key, limit, windowMs, now)) return true;
  }
  return false;
}

// Counts a try against the scope's windows, per email and per address.
export async function recordTry(env, request, scope, email, now) {
  const counts = (await limitKeys(env, request, scope, email, now))
    .map(({ key, windowMs }) => db.countTry(env.LOGS, key, windowMs, now));
  if (counts.length) await env.LOGS.batch(counts);
}

// The account signed in, from the session cookie, or null.
export async function sessionUser(request, env, now) {
  return currentUser(request, env, now);
}

async function currentUser(request, env, now) {
  const token = readCookie(request);
  if (!token) return null;
  return (await db.findSession(env.LOGS, await tokenHash(token), now).first()) ?? null;
}

export function emailOf(value) {
  const email = String(value ?? '').trim().toLowerCase();
  return email.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : null;
}

function passwordOf(value) {
  const password = String(value ?? '');
  return password.length >= 10 && password.length <= 128 ? password : null;
}

// A post from the site's own pages: its Origin is the site, or the browser,
// whose Sec-Fetch-Site a page can't set, says it is same-origin.
export function sameOrigin(request, env) {
  return request.headers.get('origin') === `https://${env.CANONICAL_HOST}`
    || request.headers.get('sec-fetch-site') === 'same-origin';
}

export function readCookie(request, cookie = COOKIE) {
  for (const part of (request.headers.get('cookie') || '').split(';')) {
    const [name, ...value] = part.trim().split('=');
    if (name === cookie) return value.join('=');
  }
  return null;
}

export function sessionCookie(token) {
  return `${COOKIE}=${token}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${db.SESSION_MS / 1000}`;
}

export function clearCookie() {
  return `${COOKIE}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0`;
}

// A path with the language and a notice, an error, or an email, for the next page.
export function to(path, lang, { notice, error, email } = {}) {
  const query = new URLSearchParams();
  if (lang === 'he') query.set('lang', 'he');
  if (notice) query.set('notice', notice);
  if (error) query.set('error', error);
  if (email) query.set('email', email);
  const text = query.toString();
  return text ? `${path}?${text}` : path;
}

export function page({ html, status }, cookie) {
  const headers = new Headers({ ...SECURITY, 'Content-Type': 'text/html; charset=utf-8' });
  if (cookie) headers.append('Set-Cookie', cookie);
  return new Response(html, { status, headers });
}

export function see(location, cookie) {
  const headers = new Headers({ ...SECURITY, Location: location });
  if (cookie) headers.append('Set-Cookie', cookie);
  return new Response(null, { status: 303, headers });
}
