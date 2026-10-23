// The app's API, under /api/: the community's forums (community.js), its
// sign-in and the reading-progress backup, as JSON, for the app on every
// platform (lib/features/community/data/worker_forum_repository.dart).
//
// The accounts are the site's (accounts.js): the app signs in with a code
// sent by email, as the app always has, which makes the account the first
// time, without a password (pw_alg 'none'; a password reset on the site
// gives it one). A session is the site's too: the app sends its token as a
// bearer token, and the web app, on the site's own address, its cookie. A
// request with the cookie alone that changes anything must come from the
// site itself, as the account forms must.

import {
  ApiError,
  acceptGuidelines,
  block,
  blockedMembers,
  createThread,
  deletePost,
  editPost,
  ensureProfile,
  forumStats,
  forums,
  loadProgress,
  moderate,
  myProfile,
  openReports,
  posts,
  reply,
  report,
  saveProgress,
  setTodah,
  thread,
  threads,
  updateName,
  weeklyThread,
} from './community.js';
import {
  clearCookie,
  configured,
  deleteEverything,
  emailOf,
  limited,
  readCookie,
  recordTry,
  sameOrigin,
  sendCode,
  sessionCookie,
} from './accounts.js';
import { constantTimeEqual, keyedHash, randomToken, tokenHash } from './account_crypto.js';
import * as db from './account_db.js';
import * as cdb from './community_db.js';

export { isApiPath } from './rules.js';

const BASE = '/api';
const MAX_BODY = 16 * 1024;
// The progress backup holds the reader's notes too.
const MAX_PROGRESS = 900 * 1024;
const UNSAFE = ['POST', 'PUT', 'PATCH', 'DELETE'];
// An account made by the app's code has no password to sign in with.
const NO_PASSWORD = { pw_alg: 'none', pw_iter: 0, pw_salt: '', pw_hash: '' };

const HEADERS = {
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
};

export async function handleApi(request, env, url, now = Date.now()) {
  if (!configured(env)) return json({ error: 'unavailable' }, 503);
  try {
    return await route(request, env, url, now);
  } catch (error) {
    if (error instanceof ApiError) return json({ error: error.code }, error.status);
    console.error('api request failed', error.name);
    return json({ error: 'unavailable' }, 500);
  }
}

async function route(request, env, url, now) {
  const { method } = request;
  const path = url.pathname.replace(/\/+$/, '');
  const limit = path === `${BASE}/progress` ? MAX_PROGRESS : MAX_BODY;
  if (Number(request.headers.get('content-length') || 0) > limit) throw new ApiError('too_large', 413);

  // Signing in, out, and the account itself.
  if (method === 'POST' && path === `${BASE}/auth/code`) return requestCode(request, env, now);
  if (method === 'POST' && path === `${BASE}/auth/verify`) return verifyCode(request, env, now);

  const session = await sessionOf(request, env, now);
  const member = session.member;
  const answer = (value, status = 200) => session.reply(value === null ? new Response(null, { status: 204, headers: HEADERS }) : json(value, status));
  const body = UNSAFE.includes(method) && method !== 'DELETE' ? await readJson(request, limit) : null;
  const match = (pattern) => pattern.exec(path.slice(BASE.length));
  let m;

  switch (`${method} ${path.slice(BASE.length)}`) {
    case 'POST /auth/sign-out':
      if (session.token) await db.deleteSession(env.LOGS, await tokenHash(session.token)).run();
      return new Response(null, { status: 204, headers: { ...HEADERS, 'Set-Cookie': clearCookie() } });
    case 'GET /me':
      if (!member) throw new ApiError('not_signed_in', 401);
      return answer({ user: { id: String(member.id), email: member.email } });
    case 'DELETE /me':
      if (!member) throw new ApiError('not_signed_in', 401);
      await deleteEverything(env, member.id);
      return new Response(null, { status: 204, headers: { ...HEADERS, 'Set-Cookie': clearCookie() } });
    case 'GET /profile':
      return answer(member ? myProfile(member) : null);
    case 'PUT /profile':
      return answer(await updateName(env, member, body));
    case 'POST /profile/guidelines':
      return answer(await acceptGuidelines(env, member, now));
    case 'GET /forums':
      return answer(await forums(env));
    case 'GET /forum-stats':
      return answer(await forumStats(env));
    case 'GET /threads':
      return answer(await threads(env, member, url.searchParams));
    case 'POST /threads':
      return answer(await createThread(env, member, body, now), 201);
    case 'POST /weekly':
      return answer(await weeklyThread(env, body, now));
    case 'POST /reports':
      return answer(await report(env, member, body, now), 201);
    case 'GET /reports':
      return answer(await openReports(env, member));
    case 'GET /blocks':
      return answer(await blockedMembers(env, member));
    case 'POST /moderate':
      return answer(await moderate(env, member, body, now));
    case 'GET /progress':
      return answer(await loadProgress(env, member));
    case 'PUT /progress':
      return answer(await saveProgress(env, member, body, now));
    default:
      break;
  }

  if ((m = match(/^\/threads\/([^/]+)$/)) && method === 'GET') return answer(await thread(env, member, m[1]));
  if ((m = match(/^\/threads\/([^/]+)\/posts$/))) {
    if (method === 'GET') return answer(await posts(env, member, m[1], url.searchParams));
    if (method === 'POST') return answer(await reply(env, member, m[1], body, now), 201);
  }
  if ((m = match(/^\/posts\/([^/]+)$/))) {
    if (method === 'PATCH') return answer(await editPost(env, member, m[1], body, now));
    if (method === 'DELETE') return answer(await deletePost(env, member, m[1], now));
  }
  if ((m = match(/^\/posts\/([^/]+)\/todah$/)) && (method === 'PUT' || method === 'DELETE')) {
    return answer(await setTodah(env, member, m[1], method === 'PUT', now));
  }
  if ((m = match(/^\/blocks\/([^/]+)$/)) && (method === 'PUT' || method === 'DELETE')) {
    return answer(await block(env, member, m[1], method === 'PUT', now));
  }
  throw new ApiError('not_found', 404);
}

// The member a request is signed in as, if any, from its bearer token or
// its cookie, with a profile once it reaches the community. A session in
// use is kept going: past half its time, it runs for its full time again.
async function sessionOf(request, env, now) {
  const bearer = /^Bearer\s+(\S+)$/i.exec(request.headers.get('authorization') || '')?.[1];
  const cookie = bearer ? null : readCookie(request);
  const token = bearer ?? cookie;
  const none = { member: null, token: null, reply: (response) => response };
  if (!token) return none;
  if (cookie && UNSAFE.includes(request.method) && !sameOrigin(request, env)) throw new ApiError('forbidden', 403);
  const hash = await tokenHash(token);
  const row = await cdb.findMember(env.LOGS, hash, now).first();
  if (!row) return { ...none, token };
  const member = await ensureProfile(env, row, now);
  let refreshed = false;
  if (row.expires_at - now < db.SESSION_MS / 2) {
    await cdb.extendSession(env.LOGS, hash, now + db.SESSION_MS).run();
    refreshed = Boolean(cookie);
  }
  return {
    member,
    token,
    reply: (response) => {
      if (refreshed) response.headers.append('Set-Cookie', sessionCookie(token));
      return response;
    },
  };
}

// Emails a sign-in code, making the account the first time. The answer is
// the same whether or not the address had an account.
async function requestCode(request, env, now) {
  const body = await readJson(request, MAX_BODY);
  const email = emailOf(body?.email);
  if (!email) throw new ApiError('invalid_email');
  if (await limited(env, request, 'appCode', email, now)) throw new ApiError('rate_limited', 429);
  await recordTry(env, request, 'appCode', email, now);
  let user = await db.findUserByEmail(env.LOGS, email).first();
  user ??= await db.insertUser(env.LOGS, { email, password: NO_PASSWORD, now }).first();
  try {
    await sendCode(env, user.id, email, now);
  } catch (error) {
    console.error('app code email failed', error.name);
    throw new ApiError('email_failed', 503);
  }
  return new Response(null, { status: 204, headers: HEADERS });
}

// Checks the code and signs in: the token for the app, and the cookie for
// the site. An address confirmed here for the first time loses any password
// set before it was confirmed, which whoever set it could not prove theirs.
async function verifyCode(request, env, now) {
  const body = await readJson(request, MAX_BODY);
  const email = emailOf(body?.email);
  const code = String(body?.code ?? '').trim();
  if (!email || !/^\d{6}$/.test(code)) throw new ApiError('invalid_code');
  if (await limited(env, request, 'verify', email, now)) throw new ApiError('rate_limited', 429);
  await recordTry(env, request, 'verify', email, now);

  const user = await db.findUserByEmail(env.LOGS, email).first();
  const row = user && await db.findCode(env.LOGS, user.id).first();
  if (!row || row.expires_at <= now || row.attempts >= db.CODE_TRIES) {
    if (row) await db.deleteCode(env.LOGS, row.id).run();
    throw new ApiError('invalid_code');
  }
  const expected = await keyedHash(env.ACCOUNTS_KEY, `code|${user.id}|${code}`);
  if (!constantTimeEqual(expected, row.code_hash)) {
    const tries = await db.countCodeTry(env.LOGS, row.id).first();
    if (tries.attempts >= db.CODE_TRIES) await db.deleteCode(env.LOGS, row.id).run();
    throw new ApiError('invalid_code');
  }

  const token = randomToken();
  const statements = [];
  if (!user.email_verified_at) {
    statements.push(db.setPassword(env.LOGS, user.id, NO_PASSWORD), db.deleteSessionsOf(env.LOGS, user.id));
  }
  statements.push(
    db.markVerified(env.LOGS, user.id, now),
    db.deleteCodesOf(env.LOGS, user.id),
    db.insertSession(env.LOGS, { tokenHash: await tokenHash(token), userId: user.id, now }),
  );
  await env.LOGS.batch(statements);
  const response = json({ token, user: { id: String(user.id), email } });
  response.headers.append('Set-Cookie', sessionCookie(token));
  return response;
}

async function readJson(request, limit) {
  const text = await request.text();
  if (text.length > limit) throw new ApiError('too_large', 413);
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    throw new ApiError('invalid_json');
  }
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: HEADERS });
}
