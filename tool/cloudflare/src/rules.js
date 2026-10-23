// What a request to the site is, and what the site's logs keep of it. Pure
// functions, so that the tests can run them without Cloudflare. No raw
// address is returned from here: the visitor's address only ever becomes
// the keyed hash of ipKey.

// Paths that only scanners ask for: secrets and repositories, WordPress,
// server panels, and script or backup files a static site never has.
const SCANNER_PATH = new RegExp(
  [
    String.raw`(^|/)\.(env|git|svn|hg|aws|ssh|htaccess|htpasswd|DS_Store)([./]|$)`,
    String.raw`(^|/)wp-[^/]*`,
    String.raw`(^|/)(xmlrpc\.php|phpmyadmin|phpinfo|server-status|actuator|cgi-bin|web\.config|id_rsa|boot\.ini)(/|$)`,
    String.raw`(^|/)etc/passwd`,
    String.raw`\.(php\d?|asp|aspx|jsp|cgi|bak|sql|old|swp)$`,
  ].join('|'),
  'i',
);

// Escapes and separators that only a path traversal needs.
const TRAVERSAL = /%2e|%2f|%5c|%00|\\|\.\./i;

// Tools that identify themselves as scanners.
const SCANNER_AGENT = /sqlmap|nikto|nmap|masscan|zgrab|acunetix|nuclei|dirbuster|gobuster|wpscan|netsparker|havij|zmeu|censys|shodan/i;

// Cloudflare's threat score runs from 0 to 100, higher being worse.
export const THREAT_SCORE_LOGGED = 20;

const METHODS_OK = ['GET', 'HEAD', 'OPTIONS'];
// The accounts' forms are the one place the site takes a POST.
export function isAccountPath(pathname) {
  return pathname === '/account' || pathname.startsWith('/account/');
}
const MAX_PATH = 512;
const MAX_QUERY = 2048;

// The kinds a request shows, each with what it's about. The worker answers
// some of them with an error instead of the site.
export function classify({ method, host, canonicalHost, pathname, search = '', userAgent, threatScore }) {
  const found = [];
  if (host !== canonicalHost) found.push({ kind: 'bad_host', detail: String(host).slice(0, 253) });
  const methodOk = METHODS_OK.includes(method) || (method === 'POST' && isAccountPath(pathname));
  if (!methodOk) found.push({ kind: 'bad_method', detail: String(method).slice(0, 10) });
  if (pathname.length > MAX_PATH || search.length > MAX_QUERY) found.push({ kind: 'too_long', detail: '' });
  if (SCANNER_PATH.test(pathname)) found.push({ kind: 'scanner_path', detail: '' });
  if (TRAVERSAL.test(pathname)) found.push({ kind: 'traversal', detail: '' });
  if (!userAgent) found.push({ kind: 'no_user_agent', detail: '' });
  else if (SCANNER_AGENT.test(userAgent)) found.push({ kind: 'scanner_agent', detail: '' });
  if (typeof threatScore === 'number' && threatScore >= THREAT_SCORE_LOGGED) {
    found.push({ kind: 'threat_score', detail: String(threatScore) });
  }
  return found;
}

// The status a blocked request gets, or null when the site answers it.
export function blockedStatus(kinds) {
  const has = (kind) => kinds.some((k) => k.kind === kind);
  if (has('bad_host')) return 301;
  if (has('bad_method')) return 405;
  if (has('too_long')) return 414;
  if (has('scanner_agent')) return 403;
  if (has('scanner_path') || has('traversal')) return 404;
  return null;
}

// A page the visitor opened, not a file the page loads. A file is a
// subresource (a script, a font, an image), and a visit has one page view
// for many of them.
export function isPageView({ method, headers }) {
  if (method !== 'GET') return false;
  const dest = headers.get('sec-fetch-dest');
  if (dest) return dest === 'document';
  return (headers.get('accept') || '').includes('text/html');
}

// The visitor's address as a keyed hash: HMAC-SHA256 of the UTC day and the
// address, with the secret salt as the key. The same visitor gets the same
// key within a day and a different one the next, so a day's visitors can be
// counted and told apart, but not followed from one day to the next. Null
// without the salt or the address: nothing is logged in its place.
export async function ipKey(ip, salt, day) {
  if (!ip || !salt) return null;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', enc.encode(salt), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = await crypto.subtle.sign('HMAC', key, enc.encode(`${day}|${ip}`));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, '0')).join('').slice(0, 32);
}

// The UTC day of a time in milliseconds, as YYYY-MM-DD.
export function dayOf(ts) {
  return new Date(ts).toISOString().slice(0, 10);
}

// A value cut to at most n characters, or null.
export function clip(value, n) {
  if (value === undefined || value === null || value === '') return null;
  return String(value).slice(0, n);
}

// The host of a referring page, and nothing of its path or query, which can
// carry a search or an address.
export function refererHost(referer) {
  if (!referer) return null;
  try {
    return clip(new URL(referer).hostname, 253);
  } catch {
    return null;
  }
}

// The first language the visitor's browser asks for, such as "he-IL".
export function firstLanguage(acceptLanguage) {
  if (!acceptLanguage) return null;
  return clip(acceptLanguage.split(',')[0].trim(), 16);
}
