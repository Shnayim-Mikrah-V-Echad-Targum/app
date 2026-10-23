// The admin panel, at /account/admin (and /admin, which leads there): the accounts, the community's reports and
// moderation, and the site's security and visit logs, for the site's
// administrators (an address with the role admin, tool/cloudflare/README.md,
// Accounts) and no one else. Plain pages and forms, as the account pages are,
// in English; signed in with the site's session cookie. Every change goes
// through a form posted from the site itself, and is logged.

import { escapeHtml } from './account_pages.js';
import { configured, deleteEverything, readCookie, sameOrigin } from './accounts.js';
import { tokenHash } from './account_crypto.js';
import * as db from './account_db.js';
import * as adb from './admin_db.js';
import * as cdb from './community_db.js';
import { ApiError, deletePost, excerptOf, moderate } from './community.js';

// Under /account, which the app's offline service worker already leaves to
// the server (tool/web/sw_build.cjs), even in a browser with an older one.
const BASE = '/account/admin';
const MAX_BODY = 4096;
const PAGE = 50;
const DAY = 86400000;

const SECURITY = {
  'Cache-Control': 'no-store',
  'Referrer-Policy': 'same-origin',
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'X-Robots-Tag': 'noindex',
  'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
};

export async function handleAdmin(request, env, url, now = Date.now()) {
  if (!configured(env)) return page('Admin', '<p class="error">The accounts are not set up.</p>', { status: 503 });
  const token = readCookie(request);
  const admin = token ? await db.findSession(env.LOGS, await tokenHash(token), now).first() : null;
  if (!admin) return see('/account/sign-in');
  if (admin.role !== 'admin') {
    return page('Admin', '<p class="error">This page is for the site’s administrators.</p>', { status: 403, admin: null });
  }
  try {
    return await route(request, env, url, admin, now);
  } catch (error) {
    console.error('admin request failed', error.name);
    return page('Admin', '<p class="error">Something went wrong. Try again.</p>', { status: 500, admin });
  }
}

async function route(request, env, url, admin, now) {
  const path = url.pathname.replace(/\/+$/, '') || BASE;
  if (request.method === 'POST') {
    if (path !== `${BASE}/action` || !sameOrigin(request, env) || Number(request.headers.get('content-length') || 0) > MAX_BODY) {
      return page('Admin', '<p class="error">This request was refused.</p>', { status: 403, admin });
    }
    return act(request, env, admin, now);
  }
  const notice = noticeOf(url);
  if (path === BASE) return overview(env, admin, now, notice);
  if (path === `${BASE}/accounts`) return accounts(env, admin, url, now, notice);
  const one = /^\/account\/admin\/accounts\/(\d+)$/.exec(path);
  if (one) return account(env, admin, Number(one[1]), now, notice);
  if (path === `${BASE}/reports`) return reports(env, admin, notice);
  if (path === `${BASE}/security`) return security(env, admin, url, now);
  if (path === `${BASE}/log`) return log(env, admin);
  return page('Not found', '<p>There is no such page.</p>', { status: 404, admin });
}

// --- Actions ----------------------------------------------------------------------

const ACCOUNT_ACTIONS = ['sign_out_everywhere', 'delete_account'];

// A change from one of the panel's forms; then back to the page it came from.
async function act(request, env, admin, now) {
  const form = await request.formData();
  const action = String(form.get('action') ?? '');
  const target = String(form.get('target') ?? '');
  const reason = form.get('reason') == null ? null : String(form.get('reason')).trim() || null;
  const back = String(form.get('back') ?? BASE);
  const to = /^\/account\/admin(\/[a-z0-9/]*)?$/.test(back) ? back : BASE;
  try {
    if (ACCOUNT_ACTIONS.includes(action)) {
      await accountAction(env, admin, action, Number(target), form, now);
    } else if (action === 'delete_post') {
      await deletePost(env, admin, target, now);
    } else {
      await moderate(env, admin, { action, target_id: target, reason }, now);
    }
  } catch (error) {
    if (!(error instanceof ApiError)) throw error;
    return see(`${to}?error=${encodeURIComponent(error.code)}`);
  }
  // A deleted account has no page to go back to.
  return see(`${action === 'delete_account' ? `${BASE}/accounts` : to}?done=${encodeURIComponent(action)}`);
}

// Signing an account out everywhere, or deleting it with all it posted: never
// another admin's, and never the panel's own account deleted from here.
async function accountAction(env, admin, action, target, form, now) {
  const other = await cdb.findUserRole(env.LOGS, target).first();
  if (!other) throw new ApiError('not_found', 404);
  if (other.role === 'admin' && other.id !== admin.id) throw new ApiError('forbidden', 403);
  if (action === 'delete_account') {
    if (other.id === admin.id) throw new ApiError('own_account', 403);
    if (form.get('confirm') !== 'yes') throw new ApiError('not_confirmed');
    await deleteEverything(env, other.id);
  } else {
    await db.deleteSessionsOf(env.LOGS, other.id).run();
  }
  await cdb.logModeration(env.LOGS, { actorId: admin.id, action, targetType: 'account', target: other.id, now }).run();
}

// --- Pages --------------------------------------------------------------------------

async function overview(env, admin, now, notice) {
  const [counts, days, kinds] = await Promise.all([
    adb.overview(env.LOGS, now).first(),
    adb.visitsByDay(env.LOGS, now, 14).all(),
    adb.eventsByKind(env.LOGS, now - DAY).all(),
  ]);
  const card = (label, value, href) => `<a class="card" href="${href}"><span class="n">${value}</span><span>${label}</span></a>`;
  const body = `${notice}
<div class="cards">
${card('accounts', counts.accounts, `${BASE}/accounts`)}
${card('confirmed', counts.confirmed, `${BASE}/accounts`)}
${card('new this week', counts.new_week, `${BASE}/accounts`)}
${card('signed in now', counts.signed_in, `${BASE}/accounts`)}
${card('open reports', counts.open_reports, `${BASE}/reports`)}
${card('posts hidden', counts.hidden, `${BASE}/reports`)}
${card('threads', counts.threads, '/community')}
${card('posts', counts.posts, '/community')}
${card('posts this week', counts.posts_week, '/community')}
${card('banned', counts.banned, `${BASE}/accounts`)}
${card('silenced', counts.silenced, `${BASE}/accounts`)}
${card('security events today', counts.events_day, `${BASE}/security`)}
</div>
<h2>Visits, last 14 days</h2>
${table(['Day (UTC)', 'Visits', 'Visitors'], days.results.map((d) => [d.day, d.visits, d.visitors]), 'No visits yet.')}
<h2>Security events, last 24 hours</h2>
${table(['Kind', 'Events'], kinds.results.map((k) => [kindLink(k.kind), k.n]), 'None.')}`;
  return page('Overview', body, { admin });
}

async function accounts(env, admin, url, now, notice) {
  const query = (url.searchParams.get('q') ?? '').trim().slice(0, 100);
  const pageNo = Math.max(1, Number(url.searchParams.get('page')) || 1);
  const { results } = await adb.accounts(env.LOGS, { query, now, limit: PAGE + 1, offset: (pageNo - 1) * PAGE }).all();
  const more = results.length > PAGE;
  const rows = results.slice(0, PAGE).map((a) => [
    `<a href="${BASE}/accounts/${a.id}">${escapeHtml(a.email)}</a>`,
    escapeHtml(a.display_name ?? '—'),
    escapeHtml(a.role ?? ''),
    escapeHtml(status(a, now)),
    a.posts,
    time(a.created_at),
    a.last_sign_in ? time(a.last_sign_in) : '—',
  ]);
  const q = query ? `&q=${encodeURIComponent(query)}` : '';
  const pager = [
    pageNo > 1 ? `<a href="${BASE}/accounts?page=${pageNo - 1}${q}">← Newer</a>` : '',
    more ? `<a href="${BASE}/accounts?page=${pageNo + 1}${q}">Older →</a>` : '',
  ].filter(Boolean).join(' · ');
  const body = `${notice}
<form method="get" action="${BASE}/accounts" class="search">
<input name="q" value="${escapeHtml(query)}" placeholder="Email or display name" aria-label="Search accounts">
<button type="submit">Search</button>
</form>
${table(['Email', 'Name', 'Role', 'Status', 'Posts', 'Made', 'Last sign-in'], rows, 'No accounts found.')}
<p>${pager}</p>`;
  return page('Accounts', body, { admin });
}

function status(a, now) {
  const parts = [];
  if (!a.email_verified_at) parts.push('unconfirmed');
  if (a.banned_at) parts.push('banned');
  if (a.silenced_until > now) parts.push(`silenced until ${time(a.silenced_until)}`);
  if (a.sessions > 0) parts.push(`${a.sessions} session${a.sessions === 1 ? '' : 's'}`);
  return parts.join(', ') || 'ok';
}

async function account(env, admin, id, now, notice) {
  const a = await adb.account(env.LOGS, id, now).first();
  if (!a) return page('Not found', '<p>There is no such account.</p>', { status: 404, admin });
  const [posts, history] = await Promise.all([
    adb.postsBy(env.LOGS, id).all(),
    adb.moderationLog(env.LOGS, { target: String(id), limit: 50 }).all(),
  ]);
  const back = `${BASE}/accounts/${id}`;
  const self = a.id === admin.id;
  const protectedStaff = a.role === 'admin' && !self;
  const actions = [];
  if (!protectedStaff) {
    actions.push(a.banned_at || a.silenced_until > now
      ? button('unban_user', id, back, 'Lift ban and silence')
      : `${button('silence_user', id, back, 'Silence for 7 days')} ${button('ban_user', id, back, 'Ban', 'danger')}`);
    actions.push(`<form method="post" action="${BASE}/action" class="inline">${hidden('set_trust', id, back)}
<label>Trust <select name="reason">${[0, 1, 2, 3, 4].map((n) => `<option${n === a.trust_level ? ' selected' : ''}>${n}</option>`).join('')}</select></label>
<button type="submit">Set</button></form>`);
  }
  if (!protectedStaff && a.email_verified_at && a.role !== 'admin') {
    actions.push(a.role === 'moderator'
      ? button('revoke_moderator', id, back, 'Remove moderator')
      : button('grant_moderator', id, back, 'Make moderator'));
  }
  if (!protectedStaff) actions.push(button('sign_out_everywhere', id, back, self ? 'Sign out everywhere (you too)' : 'Sign out everywhere'));
  if (!protectedStaff && !self) {
    actions.push(`<form method="post" action="${BASE}/action" class="inline">${hidden('delete_account', id, back)}
<label><input type="checkbox" name="confirm" value="yes" required> I am sure</label>
<button type="submit" class="danger">Delete account and all it posted</button></form>`);
  }
  const postRows = posts.results.map((p) => [
    time(p.created_at),
    `<a href="/community/thread/${p.thread_id}">${escapeHtml(p.title)}</a>`,
    escapeHtml(excerptOf(p.body) ?? ''),
    p.deleted_at ? 'deleted' : p.hidden_at ? 'hidden' : '',
    p.deleted_at ? '' : postActions(p, back),
  ]);
  const body = `${notice}
<dl>
<dt>Email</dt><dd>${escapeHtml(a.email)}</dd>
<dt>Display name</dt><dd>${escapeHtml(a.display_name ?? 'no profile yet')}</dd>
<dt>Role</dt><dd>${escapeHtml(a.role ?? 'member')}</dd>
<dt>Status</dt><dd>${escapeHtml(status(a, now))}</dd>
<dt>Password</dt><dd>${a.pw_alg === 'none' ? 'none (made in the app, by code)' : 'set'}</dd>
<dt>Made</dt><dd>${time(a.created_at)}</dd>
<dt>Confirmed</dt><dd>${a.email_verified_at ? time(a.email_verified_at) : 'not yet'}</dd>
<dt>Guidelines</dt><dd>${a.accepted_terms_at ? `accepted ${time(a.accepted_terms_at)}` : 'not accepted'}</dd>
<dt>Trust level</dt><dd>${a.trust_level ?? '—'}</dd>
<dt>Last sign-in</dt><dd>${a.last_sign_in ? time(a.last_sign_in) : '—'}</dd>
</dl>
${actions.length ? `<h2>Actions</h2><div class="actions">${actions.join('\n')}</div>` : '<p class="muted">Another administrator’s account: no actions here.</p>'}
<h2>Posts</h2>
${table(['When', 'Thread', 'Post', '', ''], postRows, 'No posts.')}
<h2>Moderation</h2>
${table(['When', 'Action', 'By', 'Reason'], history.results.map((m) => [time(m.created_at), escapeHtml(m.action), escapeHtml(m.actor ?? '—'), escapeHtml(m.reason ?? '')]), 'Nothing yet.')}`;
  return page(a.email, body, { admin });
}

function postActions(p, back) {
  return [
    p.hidden_at ? button('restore_post', p.id, back, 'Restore') : button('hide_post', p.id, back, 'Hide'),
    button('delete_post', p.id, back, 'Delete', 'danger'),
  ].join(' ');
}

async function reports(env, admin, notice) {
  const { results } = await adb.openReports(env.LOGS).all();
  const back = `${BASE}/reports`;
  const items = results.map((r) => `<article class="report">
<p><strong>${escapeHtml(r.reason)}</strong> · ${time(r.created_at)} · by ${escapeHtml(r.reporter_name ?? 'a member')}${r.reporters > 1 ? ` · ${r.reporters} reporters` : ''}</p>
${r.details ? `<p>“${escapeHtml(r.details)}”</p>` : ''}
${r.t_id ? `<p>In <a href="/community/thread/${r.t_id}">${escapeHtml(r.title ?? '')}</a></p>` : ''}
${r.post_id ? `<blockquote>${escapeHtml(String(r.post_body ?? '').slice(0, 800))}</blockquote>
<p class="muted">By ${r.author_id ? `<a href="${BASE}/accounts/${r.author_id}">${escapeHtml(r.author_name ?? '')}</a>` : 'a deleted account'}${r.deleted_at ? ' · deleted' : r.hidden_at ? ' · hidden' : ''}</p>` : ''}
<div class="actions">
${button('resolve_report', r.id, back, 'Resolve')}
${button('dismiss_report', r.id, back, 'Dismiss')}
${r.post_id && !r.deleted_at ? postActions({ id: r.post_id, hidden_at: r.hidden_at }, back) : ''}
${r.thread_id && !r.post_id ? button('lock_thread', r.thread_id, back, 'Lock thread') : ''}
</div>
</article>`);
  return page('Reports', `${notice}${items.join('\n') || '<p>No open reports.</p>'}`, { admin });
}

async function security(env, admin, url, now) {
  const kind = url.searchParams.get('kind');
  const kindFilter = kind && /^[a-z_]{1,32}$/.test(kind) ? kind : null;
  const week = now - 7 * DAY;
  const [day, weekKinds, month, offenders, events, visits, paths, countries, referrers, langs] = await Promise.all([
    adb.eventsByKind(env.LOGS, now - DAY).all(),
    adb.eventsByKind(env.LOGS, week).all(),
    adb.eventsByKind(env.LOGS, now - 30 * DAY).all(),
    adb.topOffenders(env.LOGS, week).all(),
    adb.recentEvents(env.LOGS, { kind: kindFilter, limit: 100 }).all(),
    adb.visitsByDay(env.LOGS, now, 30).all(),
    adb.topVisits(env.LOGS, 'path', week).all(),
    adb.topVisits(env.LOGS, 'country', week).all(),
    adb.topVisits(env.LOGS, 'referer_host', week).all(),
    adb.topVisits(env.LOGS, 'lang', week).all(),
  ]);
  const counts = new Map();
  for (const [i, list] of [day, weekKinds, month].entries()) {
    for (const k of list.results) {
      const row = counts.get(k.kind) ?? [0, 0, 0];
      row[i] = k.n;
      counts.set(k.kind, row);
    }
  }
  const pairs = (list) => list.results.map((r) => [escapeHtml(r.value), r.n]);
  const body = `<p class="muted">Addresses are never stored: each is a keyed hash that changes every UTC day (README, What is logged).</p>
<h2>Events by kind</h2>
${table(['Kind', '24 hours', '7 days', '30 days'], [...counts].map(([k, [d, w, m]]) => [kindLink(k), d, w, m]), 'No security events.')}
<h2>Most events from one address, last 7 days</h2>
${table(['Address (day’s hash)', 'Events', 'Kinds', 'Country', 'Network'], offenders.results.map((o) => [escapeHtml(String(o.ip).slice(0, 12)), o.n, escapeHtml(o.kinds ?? ''), escapeHtml(o.country ?? ''), o.asn ?? '']), 'None.')}
<h2>Latest events${kindFilter ? `: ${escapeHtml(kindFilter)} <a href="${BASE}/security">(all)</a>` : ''}</h2>
${table(['When', 'Kind', 'Detail', 'Request', 'Status', 'Country', 'Browser'], events.results.map((e) => [
    time(e.ts), escapeHtml(e.kind), escapeHtml(e.detail ?? ''), escapeHtml(`${e.method ?? ''} ${e.path ?? ''}`), e.status ?? '', escapeHtml(e.country ?? ''), escapeHtml(String(e.ua ?? '').slice(0, 60)),
  ]), 'None.')}
<h2>Visits, last 30 days</h2>
${table(['Day (UTC)', 'Visits', 'Visitors'], visits.results.map((d) => [d.day, d.visits, d.visitors]), 'No visits yet.')}
<div class="cols">
<div><h2>Pages, 7 days</h2>${table(['Path', 'Visits'], pairs(paths), 'None.')}</div>
<div><h2>Countries, 7 days</h2>${table(['Country', 'Visits'], pairs(countries), 'None.')}</div>
<div><h2>Came from, 7 days</h2>${table(['Site', 'Visits'], pairs(referrers), 'None.')}</div>
<div><h2>Languages, 7 days</h2>${table(['Language', 'Visits'], pairs(langs), 'None.')}</div>
</div>`;
  return page('Security', body, { admin });
}

async function log(env, admin) {
  const { results } = await adb.moderationLog(env.LOGS, { target: null, limit: 200 }).all();
  const target = (m) => (['user', 'moderator', 'trust', 'account'].includes(m.target_type)
    ? `<a href="${BASE}/accounts/${escapeHtml(m.target_id)}">account ${escapeHtml(m.target_id)}</a>`
    : `${escapeHtml(m.target_type)} ${escapeHtml(m.target_id)}`);
  const rows = results.map((m) => [time(m.created_at), escapeHtml(m.action), target(m), escapeHtml(m.actor ?? '—'), escapeHtml(m.reason ?? '')]);
  return page('Moderation log', table(['When', 'Action', 'Target', 'By', 'Reason'], rows, 'Nothing has been moderated yet.'), { admin });
}

// --- Pieces -------------------------------------------------------------------------

const MESSAGES = {
  forbidden: 'That is not allowed on this account.',
  own_account: 'Delete your own account from your account page.',
  not_confirmed: 'Tick “I am sure” to delete an account.',
  not_found: 'It is not there any more.',
  invalid_trust: 'Choose a trust level from 0 to 4.',
  unknown_action: 'There is no such action.',
};

function noticeOf(url) {
  const done = url.searchParams.get('done');
  const error = url.searchParams.get('error');
  if (error) return `<p class="error" role="alert">${escapeHtml(Object.hasOwn(MESSAGES, error) ? MESSAGES[error] : 'That didn’t work.')}</p>`;
  if (done) return `<p class="notice" role="status">Done: ${escapeHtml(done.replace(/_/g, ' '))}.</p>`;
  return '';
}

function hidden(action, target, back) {
  return `<input type="hidden" name="action" value="${escapeHtml(action)}"><input type="hidden" name="target" value="${escapeHtml(target)}"><input type="hidden" name="back" value="${escapeHtml(back)}">`;
}

function button(action, target, back, label, kind = '') {
  return `<form method="post" action="${BASE}/action" class="inline">${hidden(action, target, back)}<button type="submit"${kind ? ` class="${kind}"` : ''}>${escapeHtml(label)}</button></form>`;
}

function kindLink(kind) {
  return `<a href="${BASE}/security?kind=${encodeURIComponent(kind)}">${escapeHtml(kind)}</a>`;
}

// A table; the cells are escaped by the caller, so numbers and links pass as they are.
function table(headings, rows, empty) {
  if (!rows.length) return `<p class="muted">${escapeHtml(empty)}</p>`;
  return `<div class="scroll"><table>
<thead><tr>${headings.map((h) => `<th>${escapeHtml(h)}</th>`).join('')}</tr></thead>
<tbody>${rows.map((r) => `<tr>${r.map((c) => `<td>${c ?? ''}</td>`).join('')}</tr>`).join('\n')}</tbody>
</table></div>`;
}

function time(ms) {
  return ms == null ? '' : `${new Date(ms).toISOString().slice(0, 16).replace('T', ' ')}`;
}

const NAV = [['Overview', ''], ['Accounts', '/accounts'], ['Reports', '/reports'], ['Security', '/security'], ['Log', '/log']];

function page(title, body, { status = 200, admin } = {}) {
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${escapeHtml(title)} · Admin · Shnayim Mikrah</title>
<style>
  :root { color-scheme: light dark; --fg: #1d1b18; --bg: #fbf9f4; --line: #d9d3c6; --card: #f2eee5; --accent: #2e5c4a; --err: #9b2c1f; }
  @media (prefers-color-scheme: dark) { :root { --fg: #efeae0; --bg: #1a1916; --line: #3a3732; --card: #24221e; --accent: #8fc2a8; --err: #f0a090; } }
  body { margin: 0; background: var(--bg); color: var(--fg); font: 0.95rem/1.45 system-ui, sans-serif; }
  header { border-bottom: 1px solid var(--line); padding: .75rem 1rem; display: flex; flex-wrap: wrap; gap: .25rem 1rem; align-items: baseline; }
  header strong { margin-inline-end: auto; }
  nav a { margin-inline-end: .9rem; }
  main { max-width: 72rem; margin: 0 auto; padding: 1rem; }
  h1 { font-size: 1.35rem; margin: .25rem 0 1rem; overflow-wrap: anywhere; }
  h2 { font-size: 1.05rem; margin: 1.75rem 0 .5rem; }
  a { color: var(--accent); }
  .cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(9.5rem, 1fr)); gap: .6rem; }
  .card { display: grid; padding: .75rem; border-radius: .5rem; background: var(--card); color: inherit; text-decoration: none; }
  .card .n { font-size: 1.6rem; font-weight: 700; }
  .scroll { overflow-x: auto; }
  table { border-collapse: collapse; width: 100%; font-size: .9rem; }
  th, td { text-align: start; padding: .4rem .5rem; border-bottom: 1px solid var(--line); vertical-align: top; }
  th { white-space: nowrap; }
  td { overflow-wrap: anywhere; }
  dl { display: grid; grid-template-columns: max-content 1fr; gap: .3rem 1rem; }
  dt { font-weight: 600; }
  dd { margin: 0; overflow-wrap: anywhere; }
  form.inline { display: inline-flex; gap: .4rem; align-items: center; margin: .2rem .3rem .2rem 0; }
  form.search { display: flex; gap: .5rem; margin-bottom: 1rem; }
  input, select { font: inherit; padding: .4rem .5rem; border: 1px solid var(--line); border-radius: .35rem; background: transparent; color: inherit; }
  form.search input { flex: 1; min-width: 0; }
  button { font: inherit; padding: .4rem .75rem; border: 0; border-radius: .35rem; background: var(--accent); color: #fff; cursor: pointer; }
  @media (prefers-color-scheme: dark) { button { color: #10201a; } }
  button.danger { background: var(--err); }
  .actions { display: flex; flex-wrap: wrap; align-items: center; }
  .report { border: 1px solid var(--line); border-radius: .5rem; padding: .25rem .9rem .6rem; margin-bottom: .8rem; }
  blockquote { margin: .5rem 0; padding: .5rem .75rem; border-inline-start: 3px solid var(--line); white-space: pre-wrap; overflow-wrap: anywhere; }
  .cols { display: grid; grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr)); gap: 0 1.5rem; }
  .error { color: var(--err); font-weight: 600; }
  .notice { font-weight: 600; }
  .muted { opacity: .75; }
</style>
</head>
<body>
<header><strong>Shnayim Mikrah · Admin</strong>${admin ? `<nav>${NAV.map(([label, p]) => `<a href="${BASE}${p}">${label}</a>`).join('')}</nav><span class="muted">${escapeHtml(admin.email)} · <a href="/account">Account</a></span>` : ''}</header>
<main>
<h1>${escapeHtml(title)}</h1>
${body}
</main>
</body>
</html>`;
  return new Response(html, { status, headers: { ...SECURITY, 'Content-Type': 'text/html; charset=utf-8' } });
}

function see(location) {
  return new Response(null, { status: 303, headers: { ...SECURITY, Location: location } });
}
