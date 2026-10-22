# The site's Worker and its logs

`shnayimmikrah.org` is served by the Cloudflare Worker `shnayimmikrah-org`. Every request passes through `src/worker.js` first: it answers the requests that aren't the site's, serves the app's files for the rest, and writes the logs described here. The rules are in `src/rules.js`, and `test/worker.test.mjs` checks them (`node --test tool/cloudflare/test/worker.test.mjs`, also run by CI).

## What is logged

Logs go to the D1 database **`shnayimmikrah-logs`**, in two tables (`schema.sql`).

**`visits`**: one row per page a visitor opened on the site, with the time, the path (without its query), the status, the country and network number (`asn`) Cloudflare gives, the browser's User-Agent, the referring site's host (never its path or query), the first language the browser asks for, and the visitor's address as a keyed hash (below). Files the page loads (scripts, fonts, images) are not visits, so one visit is one row.

**`security_events`**: one row per request that is refused or looks like an attack, with the kind and what it's about:

| Kind | When |
|---|---|
| `bad_host` | the request came to another address (such as the `workers.dev` one): redirected to the site |
| `bad_method` | a method the site doesn't use (anything but GET, HEAD, OPTIONS): 405 |
| `too_long` | a path over 512 or a query over 2048 characters: 414 |
| `scanner_path` | a path only scanners ask for (`/.env`, `/.git`, WordPress, `.php` and backup files): 404 |
| `traversal` | an encoded slash or dots in the path: 404 |
| `scanner_agent` | a User-Agent of a known scanning tool (sqlmap, nikto, nmap…): 403 |
| `no_user_agent` | no User-Agent at all: noted, and served |
| `threat_score` | Cloudflare's threat score of 20 or more, when the plan gives one |

The site's own requests never make a security event, and a refused request is not a visit.

## What is not logged

- **Addresses.** The visitor's address is never stored. It becomes a keyed hash (HMAC-SHA256, with a secret salt, `IP_SALT`, set as a Worker secret and not in the repository) of the UTC day and the address. The same visitor has the same hash within a day and a different one the next day, so a day's visitors can be counted and told apart, but a visitor can't be followed from one day to the next. To keep a longer link, change the code; that's a decision to make with the privacy policy in view.
- **Query strings and referrer paths**, which can carry searches and addresses.
- **Request bodies, cookies and headers** other than those named above.
- **Workers request logs** are turned off, so the full URLs of requests are not kept by Cloudflare's Workers logs.

Cloudflare keeps its own security events for the zone for its own period; they aren't copied here.

## How long

Both tables keep **365 days** (`RETENTION_DAYS` in `wrangler.toml`). A daily job, at 03:17 UTC, removes the rows older than that.

## Reading the logs

Until the admin panel exists, query the database from the terminal, or in the Cloudflare dashboard (*Storage & databases → D1 → shnayimmikrah-logs → Console*):

```sql
-- Page views per day, last 30 days
SELECT date(ts/1000, 'unixepoch') AS day, count(*) AS views, count(DISTINCT ip) AS visitors
FROM visits WHERE ts > (strftime('%s','now') - 30*86400) * 1000 GROUP BY day ORDER BY day;

-- Security events by kind, last 7 days
SELECT kind, count(*) FROM security_events
WHERE ts > (strftime('%s','now') - 7*86400) * 1000 GROUP BY kind ORDER BY 2 DESC;

-- The paths that scanners asked for
SELECT path, count(*) FROM security_events WHERE kind = 'scanner_path' GROUP BY path ORDER BY 2 DESC LIMIT 50;
```

From the terminal: `npx wrangler@4 d1 execute shnayimmikrah-logs --remote --command "SELECT count(*) FROM visits"` (with `CLOUDFLARE_API_TOKEN` set, and the token able to use D1).

## Setting it up, and deploying

Done once: the database (`wrangler d1 create shnayimmikrah-logs`, or in the dashboard), its tables (`wrangler d1 execute shnayimmikrah-logs --remote --file schema.sql`), and the salt: `openssl rand -hex 32 | npx wrangler@4 secret put IP_SALT --config wrangler.toml`. The `database_id` in `wrangler.toml` is the database's id.

Deploying the site and the Worker together, from a built site (`flutter build web` first, or the folder of a CI build):

```sh
tool/cloudflare/deploy.sh build/web
```

It needs `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`, and a token with Workers Scripts: Edit and D1: Edit. Changing the salt makes every visitor's hash new from then on.

## Before this is live for visitors to rely on

The privacy policy (`assets/legal/legal.json`) has to say that the site keeps these logs: what they hold, that addresses are hashed, and for how long. Until it does, the logs run without that disclosure.
