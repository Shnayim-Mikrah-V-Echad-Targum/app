// The community's rules, as the app's forum keeps them (tool/cloudflare/README.md,
// Community): who may post and how often, what a reader may see, reports,
// blocks and moderation. Each function takes the member (null when signed out) and
// returns what api.js sends as JSON, or throws an ApiError with the code the
// app shows a message for (lib/features/community/ui/community_ui.dart).

import * as cdb from './community_db.js';

export class ApiError extends Error {
  constructor(code, status = 400) {
    super(code);
    this.code = code;
    this.status = status;
  }
}

const REASONS = ['spam', 'lashon_hara', 'disrespect', 'misinformation', 'off_topic', 'other'];
const KINDS = ['discussion', 'weekly', 'question', 'announcement'];
// The most rows a page holds, as the app expects of the server: it fetches a
// thread again 400 posts at a time, and one more to learn whether any remain
// (ThreadPostsNotifier.refetchChunk, lib/features/community/data/community_providers.dart).
const PAGE_MAX = 500;

// Staff: an admin, who may do everything, or a moderator.
export function isStaff(member) {
  return member?.role === 'admin' || member?.role === 'moderator';
}

function signedIn(member) {
  if (!member) throw new ApiError('not_signed_in', 401);
  return member;
}

// Characters, as the app and Postgres count them, not UTF-16 units.
function length(text) {
  return [...text].length;
}

function id(value) {
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n <= 0) throw new ApiError('not_found', 404);
  return n;
}

function optionalId(value) {
  return value === undefined || value === null || value === '' ? null : id(value);
}

// --- Profiles -------------------------------------------------------------------

// Gives the member a profile, the first time the account reaches the
// community: "user_" and hex from a random number, lengthened on the rare
// clash, as the app reads a name it has not chosen (Profile.hasChosenName).
export async function ensureProfile(env, member, now) {
  if (member.display_name != null) return member;
  for (let digits = 8; digits <= 32; digits += 4) {
    const bytes = crypto.getRandomValues(new Uint8Array(digits / 2));
    const name = `user_${[...bytes].map((b) => b.toString(16).padStart(2, '0')).join('')}`;
    if (await cdb.insertProfile(env.LOGS, { userId: member.id, name, now }).first()) {
      return { ...member, display_name: name, trust_level: 0, accepted_terms_at: null, silenced_until: null, banned_at: null };
    }
    // Made meanwhile, by another request?
    const made = await cdb.findProfile(env.LOGS, member.id).first();
    if (made) return { ...member, display_name: made.display_name, trust_level: 0 };
  }
  throw new Error('no profile name was free');
}

export function myProfile(member) {
  signedIn(member);
  return {
    id: String(member.id),
    display_name: member.display_name,
    accepted_terms: member.accepted_terms_at != null,
    is_moderator: isStaff(member),
    role: member.role ?? null,
  };
}

export async function updateName(env, member, body) {
  signedIn(member);
  const name = String(body?.display_name ?? '').trim();
  if (length(name) < cdb.NAME_MIN || length(name) > cdb.NAME_MAX) throw new ApiError('invalid_name');
  const holder = await cdb.findNameKey(env.LOGS, name.toLowerCase()).first();
  if (holder && holder.user_id !== member.id) throw new ApiError('name_taken', 409);
  try {
    await cdb.setName(env.LOGS, member.id, name).run();
  } catch (error) {
    // Taken meanwhile: the index on name_key refuses it.
    if (/UNIQUE/i.test(String(error.message))) throw new ApiError('name_taken', 409);
    throw error;
  }
  return null;
}

export async function acceptGuidelines(env, member, now) {
  signedIn(member);
  await cdb.acceptTerms(env.LOGS, member.id, now).run();
  return null;
}

// --- Reading ----------------------------------------------------------------------

export async function forums(env) {
  const { results } = await cdb.forums(env.LOGS).all();
  return results.map((r) => ({ ...r, locked: Boolean(r.locked) }));
}

export async function forumStats(env) {
  const { results } = await cdb.forumStats(env.LOGS).all();
  return results.map((r) => ({ forum_id: r.forum_id, thread_count: r.thread_count, last_post_at: time(r.last_post_at) }));
}

function time(ms) {
  return ms == null ? null : new Date(ms).toISOString();
}

// A cursor as the app sends it: "<milliseconds>:<id>".
function cursor(value) {
  if (!value) return null;
  const match = /^(\d{1,15}):(\d{1,15})$/.exec(value);
  if (!match) throw new ApiError('invalid_cursor');
  return { time: Number(match[1]), id: Number(match[2]) };
}

function limitOf(value, fallback) {
  const n = value == null ? fallback : Number(value);
  return Number.isInteger(n) && n > 0 ? Math.min(n, PAGE_MAX) : fallback;
}

function threadJson(r) {
  return {
    id: r.id,
    forum_id: r.forum_id,
    parsha_id: r.parsha_id,
    hebrew_year: r.hebrew_year,
    kind: KINDS.includes(r.kind) ? r.kind : 'discussion',
    title: r.title,
    author_id: r.author_id == null ? null : String(r.author_id),
    author_name: r.author_name ?? '',
    pinned: Boolean(r.pinned),
    locked: Boolean(r.locked),
    post_count: r.post_count,
    last_post_at: time(r.last_post_at),
    created_at: time(r.created_at),
    excerpt: r.first_body == null ? null : excerptOf(r.first_body),
    todah_total: r.todah_total ?? 0,
  };
}

// The threads of a forum, or of every forum: the first page (no cursor)
// holds every pinned thread, then up to [limit] others; a later page, the
// next [limit] unpinned threads after the cursor.
export async function threads(env, member, query) {
  const forumId = optionalId(query.get('forum'));
  const parshaId = optionalId(query.get('parsha'));
  const after = cursor(query.get('after'));
  const limit = limitOf(query.get('limit'), 30);
  const common = { viewer: member?.id ?? 0, staff: isStaff(member), forumId, parshaId };
  const pages = await Promise.all([
    after ? { results: [] } : cdb.threads(env.LOGS, { ...common, pinned: true, after: null, limit: -1 }).all(),
    cdb.threads(env.LOGS, { ...common, pinned: false, after, limit }).all(),
  ]);
  return pages.flatMap((page) => page.results).map(threadJson);
}

export async function thread(env, member, threadId) {
  const row = await cdb.thread(env.LOGS, { id: id(threadId), staff: isStaff(member) }).first();
  if (!row) throw new ApiError('thread_not_found', 404);
  return threadJson(row);
}

export async function posts(env, member, threadId, query) {
  const before = cursor(query.get('before'));
  const limit = limitOf(query.get('limit'), 100);
  const { results } = await cdb.posts(env.LOGS, {
    viewer: member?.id ?? 0,
    staff: isStaff(member),
    threadId: id(threadId),
    before,
    limit,
  }).all();
  return results.reverse().map(postJson);
}

function postJson(r) {
  return {
    id: r.id,
    thread_id: r.thread_id,
    author_id: r.author_id == null ? null : String(r.author_id),
    author_name: r.author_name ?? '',
    body: r.body,
    created_at: time(r.created_at),
    edited_at: time(r.edited_at),
    hidden: r.hidden_at != null,
    reply_to_id: r.reply_to_id,
    quote: r.quote_id == null ? null : { author_name: r.quote_author ?? '', body: r.quote_body },
    todah: r.todah ?? 0,
    my_todah: Boolean(r.my_todah),
  };
}

// The weekly thread of a parasha in a year, opened on first use. Only the
// years about now: a weekly thread is listed in its forum, and no caller
// should fill the forum with years to come.
export async function weeklyThread(env, body, now) {
  const parshaId = Number(body?.parsha);
  const year = Number(body?.year);
  if (!Number.isInteger(parshaId) || !(await cdb.parshaExists(env.LOGS, parshaId).first())) throw new ApiError('invalid_parasha');
  const thisYear = new Date(now).getUTCFullYear() + 3760;
  if (!Number.isInteger(year) || year < thisYear - 1 || year > thisYear + 2) throw new ApiError('invalid_year');
  await cdb.insertWeekly(env.LOGS, parshaId, year, now).run();
  const row = await cdb.findWeekly(env.LOGS, parshaId, year).first();
  return { id: row.id };
}

// --- Writing ----------------------------------------------------------------------

// The posting gate: the guidelines accepted, and not banned or silenced.
function assertCanPost(member, now) {
  signedIn(member);
  if (member.accepted_terms_at == null) throw new ApiError('terms_not_accepted', 403);
  if (member.banned_at != null) throw new ApiError('banned', 403);
  if (member.silenced_until != null && member.silenced_until > now) throw new ApiError('silenced_until', 403);
}

function bodyOf(value) {
  const body = String(value ?? '').trim();
  if (length(body) < cdb.POST_MIN) throw new ApiError('too_short');
  if (length(body) > cdb.POST_MAX) throw new ApiError('too_long');
  return body;
}

// The limits on a new post, as Discourse sets them: 30 seconds between posts
// for a new member (5 after), 10 posts a day for a new member, the same post
// twice within 5 minutes refused, and at most 2 links from a new member.
async function assertMayPostNow(env, member, body, now) {
  const isNew = (member.trust_level ?? 0) === 0;
  const history = await cdb.postingHistory(env.LOGS, { userId: member.id, body, now }).first();
  const gap = isNew ? 30000 : 5000;
  if (history?.last_at != null && history.last_at > now - gap) throw new ApiError('rate_limited', 429);
  if (isNew && (history?.today ?? 0) >= 10) throw new ApiError('daily_limit_new_user', 429);
  if ((history?.same ?? 0) > 0) throw new ApiError('duplicate_post', 409);
  if (isNew && (body.match(/https?:\/\//g) ?? []).length > 2) throw new ApiError('too_many_links');
}

export async function createThread(env, member, body, now) {
  assertCanPost(member, now);
  const forum = await cdb.findForum(env.LOGS, Number(body?.forum_id)).first();
  if (!forum) throw new ApiError('not_found', 404);
  if (forum.locked && !isStaff(member)) throw new ApiError('category_restricted', 403);
  const title = String(body?.title ?? '').trim();
  if (length(title) < cdb.TITLE_MIN) throw new ApiError('title_too_short');
  if (length(title) > cdb.TITLE_MAX) throw new ApiError('title_too_long');
  const text = bodyOf(body?.body);
  const parshaId = body?.parsha == null ? null : Number(body.parsha);
  if (parshaId != null && !(await cdb.parshaExists(env.LOGS, parshaId).first())) throw new ApiError('invalid_parasha');
  if ((member.trust_level ?? 0) === 0 && (await cdb.threadsToday(env.LOGS, member.id, now).first()).n >= 3) {
    throw new ApiError('daily_thread_limit_new_user', 429);
  }
  await assertMayPostNow(env, member, text, now);
  const [created] = await env.LOGS.batch(cdb.insertThread(env.LOGS, { forumId: forum.id, parshaId, title, body: text, userId: member.id, now }));
  return { id: created.results[0].id };
}

export async function reply(env, member, threadId, body, now) {
  assertCanPost(member, now);
  const target = await cdb.threadForPosting(env.LOGS, id(threadId)).first();
  if (!target || target.deleted_at != null) throw new ApiError('thread_not_found', 404);
  if (target.locked && !isStaff(member)) throw new ApiError('thread_locked', 403);
  const text = bodyOf(body?.body);
  let replyToId = optionalId(body?.reply_to_id);
  if (replyToId != null) {
    const answered = await cdb.findPost(env.LOGS, replyToId).first();
    if (!answered || answered.thread_id !== target.id) replyToId = null;
  }
  await assertMayPostNow(env, member, text, now);
  const [inserted] = await env.LOGS.batch(cdb.insertPost(env.LOGS, { threadId: target.id, userId: member.id, body: text, replyToId, now }));
  return postJson({
    id: inserted.results[0].id,
    thread_id: target.id,
    author_id: member.id,
    author_name: member.display_name,
    body: text,
    created_at: now,
    reply_to_id: replyToId,
    todah: 0,
  });
}

export async function editPost(env, member, postId, body, now) {
  assertCanPost(member, now);
  const post = await cdb.findPost(env.LOGS, id(postId)).first();
  if (!post || post.deleted_at != null) throw new ApiError('not_found', 404);
  if (post.author_id !== member.id) throw new ApiError('forbidden', 403);
  await env.LOGS.batch(cdb.editPost(env.LOGS, { postId: post.id, userId: member.id, body: bodyOf(body?.body), now }));
  return null;
}

// Its author deletes a post, or staff do, which the log keeps.
export async function deletePost(env, member, postId, now) {
  signedIn(member);
  const post = await cdb.findPost(env.LOGS, id(postId)).first();
  if (!post || post.deleted_at != null) throw new ApiError('not_found', 404);
  const own = post.author_id === member.id;
  if (!own && !isStaff(member)) throw new ApiError('forbidden', 403);
  const statements = cdb.softDeletePost(env.LOGS, { postId: post.id, userId: member.id, now });
  if (!own) {
    statements.push(cdb.logModeration(env.LOGS, { actorId: member.id, action: 'delete_post', targetType: 'post', target: post.id, now }));
  }
  await env.LOGS.batch(statements);
  return null;
}

export async function setTodah(env, member, postId, on, now) {
  signedIn(member);
  const post = await cdb.findPost(env.LOGS, id(postId)).first();
  if (!post || post.deleted_at != null) throw new ApiError('not_found', 404);
  await (on ? cdb.giveTodah(env.LOGS, post.id, member.id, now) : cdb.takeTodah(env.LOGS, post.id, member.id)).run();
  return null;
}

// --- Safety -----------------------------------------------------------------------

export async function report(env, member, body, now) {
  signedIn(member);
  const reason = String(body?.reason ?? '');
  if (!REASONS.includes(reason)) throw new ApiError('invalid_reason');
  const details = body?.details == null ? null : String(body.details).trim() || null;
  if (details && length(details) > cdb.DETAILS_MAX) throw new ApiError('too_long');
  const postId = optionalId(body?.post_id);
  const threadId = optionalId(body?.thread_id);
  if (postId == null && threadId == null) throw new ApiError('not_found', 404);
  if (postId != null && !(await cdb.findPost(env.LOGS, postId).first())) throw new ApiError('not_found', 404);
  if (threadId != null && !(await cdb.threadForPosting(env.LOGS, threadId).first())) throw new ApiError('not_found', 404);
  const filed = await cdb.insertReport(env.LOGS, { reporterId: member.id, postId, threadId, reason, details, now }).first();
  if (!filed) throw new ApiError('already_reported', 409);
  if (postId != null) await cdb.hideIfReported(env.LOGS, postId, now).run();
  return null;
}

export async function block(env, member, userId, on, now) {
  signedIn(member);
  const other = id(userId);
  if (other === member.id) throw new ApiError('forbidden', 403);
  if (on) {
    if (!(await cdb.findUserRole(env.LOGS, other).first())) throw new ApiError('not_found', 404);
    await cdb.block(env.LOGS, member.id, other, now).run();
  } else {
    await cdb.unblock(env.LOGS, member.id, other).run();
  }
  return null;
}

export async function blockedMembers(env, member) {
  if (!member) return [];
  const { results } = await cdb.blocked(env.LOGS, member.id).all();
  return results.map((r) => ({ id: String(r.id), name: r.name ?? '' }));
}

// --- Moderation ---------------------------------------------------------------------

export async function openReports(env, member) {
  if (!isStaff(signedIn(member))) throw new ApiError('forbidden', 403);
  const { results } = await cdb.openReports(env.LOGS).all();
  return results.map((r) => ({
    id: String(r.id),
    post_id: r.post_id == null ? null : String(r.post_id),
    reason: r.reason,
    details: r.details,
    created_at: time(r.created_at),
    post_body: r.post_body ?? null,
  }));
}

const USER_ACTIONS = ['silence_user', 'ban_user', 'unban_user', 'set_trust', 'grant_moderator', 'revoke_moderator'];
const ADMIN_ACTIONS = ['grant_moderator', 'revoke_moderator'];
const PROFILE_ACTIONS = ['silence_user', 'ban_user', 'unban_user', 'set_trust'];

// A moderation action, logged. On a member: staff are acted on by an admin
// alone, and the moderators are named by an admin alone.
export async function moderate(env, member, body, now) {
  if (!isStaff(signedIn(member))) throw new ApiError('forbidden', 403);
  const action = String(body?.action ?? '');
  const target = id(body?.target_id);
  const reason = body?.reason == null ? null : String(body.reason).slice(0, 500);
  if (ADMIN_ACTIONS.includes(action) && member.role !== 'admin') throw new ApiError('forbidden', 403);
  if (USER_ACTIONS.includes(action)) {
    const other = await cdb.findUserRole(env.LOGS, target).first();
    if (!other) throw new ApiError('not_found', 404);
    if (isStaff(other) && member.role !== 'admin') throw new ApiError('forbidden', 403);
    if (other.role === 'admin' && action !== 'set_trust') throw new ApiError('forbidden', 403);
  }
  if (action === 'set_trust' && !/^[0-4]$/.test(reason ?? '')) throw new ApiError('invalid_trust');
  const statements = cdb.moderation(env.LOGS, { action, target, actorId: member.id, reason, now });
  if (!statements) throw new ApiError('unknown_action');
  // A ban, say, holds for an account that has not reached the community yet:
  // it is given its profile first.
  if (PROFILE_ACTIONS.includes(action) && !(await cdb.findProfile(env.LOGS, target).first())) {
    await ensureProfile(env, { id: target, display_name: null }, now);
  }
  statements.push(cdb.logModeration(env.LOGS, { actorId: member.id, action, targetType: action.split('_')[1], target, reason, now }));
  await env.LOGS.batch(statements);
  return null;
}

// --- Progress backup -----------------------------------------------------------------

export async function loadProgress(env, member) {
  signedIn(member);
  const row = await cdb.loadProgress(env.LOGS, member.id).first();
  return { data: row ? JSON.parse(row.data) : null };
}

export async function saveProgress(env, member, body, now) {
  signedIn(member);
  const data = body?.data;
  if (data === null || typeof data !== 'object' || Array.isArray(data)) throw new ApiError('invalid_progress');
  await cdb.saveProgress(env.LOGS, member.id, JSON.stringify(data), now).run();
  return null;
}

// --- The excerpt ------------------------------------------------------------------------

// How a body that quotes a verse begins, up to the verse's first letter, as
// the app reads it (splitVerseQuote, lib/features/community/data/models.dart).
const VERSE_QUOTE = /^‎?> (?=[֐-׿])/;
const EXCERPT_LENGTH = 140;

// A thread's excerpt from its first post, as the app's threadExcerpt makes
// one: after the verse it quotes, if any; the spaces and line breaks run
// together; past 140 characters cut after the last whole word that fits (or
// one short of the length, where that would lose more than 40), with an
// ellipsis. Null for a post of nothing but spaces, or but the verse.
export function excerptOf(body) {
  let rest = body;
  const quote = VERSE_QUOTE.exec(body);
  if (quote) {
    const end = body.indexOf('\n\n', quote[0].length);
    rest = end < 0 ? '' : body.slice(end + 2);
  }
  const text = rest.trim().replace(/\s+/g, ' ');
  if (!text) return null;
  const chars = [...text];
  if (chars.length <= EXCERPT_LENGTH) return text;
  const cut = /^(.*\S)\s/s.exec(chars.slice(0, EXCERPT_LENGTH + 1).join(''))?.[1];
  const word = cut != null && [...cut].length >= EXCERPT_LENGTH - 40 ? cut : chars.slice(0, EXCERPT_LENGTH - 1).join('');
  return `${word}…`;
}
