// The site's Worker: every request to shnayimmikrah.org passes through here
// before the app's files (the Workers assets, run_worker_first). It answers
// the requests that aren't the site's, logs each page a visitor opens, and
// logs each security event (tool/cloudflare/README.md says what, and why).
//
// Logging never slows or breaks the site: the writes run after the response,
// and a failed write is reported to the Worker's logs and nothing else.

import { blockedStatus, classify, clip, dayOf, firstLanguage, ipKey, isAccountPath, isPageView, refererHost } from './rules.js';
import { accountCleanup, handleAccount } from './accounts.js';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const ts = Date.now();
    const cf = request.cf || {};
    const headers = request.headers;

    const kinds = classify({
      method: request.method,
      host: url.hostname,
      canonicalHost: env.CANONICAL_HOST,
      pathname: url.pathname,
      search: url.search,
      userAgent: headers.get('user-agent'),
      threatScore: cf.threatScore,
    });

    const blocked = blockedStatus(kinds);
    let response;
    if (blocked === 301) {
      const location = new URL(url.pathname + url.search, `https://${env.CANONICAL_HOST}`);
      const readable = request.method === 'GET' || request.method === 'HEAD';
      response = readable
        ? Response.redirect(location.toString(), 301)
        : new Response('Misdirected Request', { status: 421 });
    } else if (blocked !== null) {
      const headersOut = blocked === 405 ? { Allow: 'GET, HEAD, OPTIONS' } : undefined;
      response = new Response(`${blocked}`, { status: blocked, headers: headersOut });
    } else if (isAccountPath(url.pathname)) {
      response = await handleAccount(request, env, url);
    } else {
      response = await env.ASSETS.fetch(request);
    }

    // A visit is a page the site served to its own address; a request that
    // was refused, or for another host, is not a visitor. The accounts' pages
    // are not visits either: each would write a row, for little use.
    const visit = blocked === null && url.hostname === env.CANONICAL_HOST && isPageView(request) && !isAccountPath(url.pathname);
    const day = dayOf(ts);
    const row = {
      ts,
      status: response.status,
      method: clip(request.method, 10),
      path: clip(url.pathname, 200),
      country: clip(cf.country, 8),
      asn: typeof cf.asn === 'number' ? cf.asn : null,
      ua: clip(headers.get('user-agent'), 200),
      threatScore: typeof cf.threatScore === 'number' ? cf.threatScore : null,
    };

    if (visit || kinds.length) {
      ctx.waitUntil(
        (async () => {
          const ip = await ipKey(headers.get('cf-connecting-ip'), env.IP_SALT, day);
          await record(env, {
            ...row,
            ip,
            visit: visit ? {
              refererHost: refererHost(headers.get('referer')),
              lang: firstLanguage(headers.get('accept-language')),
            } : null,
            kinds,
          });
        })(),
      );
    }

    return response;
  },

  // Once a day: the rows older than the retention period are removed, and the
  // accounts' rows that have passed their time (accounts.js).
  async scheduled(controller, env, ctx) {
    const days = Number(env.RETENTION_DAYS) || 365;
    const cutoff = Date.now() - days * 86400000;
    ctx.waitUntil(
      env.LOGS.batch([
        env.LOGS.prepare('DELETE FROM visits WHERE ts < ?').bind(cutoff),
        env.LOGS.prepare('DELETE FROM security_events WHERE ts < ?').bind(cutoff),
      ]).catch((error) => console.error('retention failed', error.message)),
    );
    ctx.waitUntil(accountCleanup(env, Date.now()).catch((error) => console.error('account clean-up failed', error.name)));
  },
};

// Writes a request's rows in one transaction, and reports a failure.
export async function record(env, { ts, ip, status, method, path, country, asn, ua, threatScore, visit, kinds }) {
  const statements = [];
  if (visit) {
    statements.push(
      env.LOGS.prepare(
        'INSERT INTO visits (ts, ip, path, status, method, country, asn, ua, referer_host, lang, threat_score) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      ).bind(ts, ip, path, status, method, country, asn, ua, visit.refererHost, visit.lang, threatScore),
    );
  }
  for (const { kind, detail } of kinds) {
    statements.push(
      env.LOGS.prepare(
        'INSERT INTO security_events (ts, kind, detail, ip, path, method, status, ua, country, asn) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      ).bind(ts, kind, clip(detail, 253), ip, path, method, status, ua, country, asn),
    );
  }
  if (statements.length === 0) return;
  try {
    await env.LOGS.batch(statements);
  } catch (error) {
    console.error('log write failed', error.message);
  }
}
