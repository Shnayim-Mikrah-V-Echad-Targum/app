#!/usr/bin/env bash
# Deploys the site and its Worker: the built web app (build/web, or the folder
# given) is staged beside the Worker, with _headers, and wrangler deploys both.
# Needs CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID in the environment.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
site="${1:-$here/../../build/web}"
[ -f "$site/index.html" ] || { echo "No built site in $site (run flutter build web first)" >&2; exit 1; }
rm -rf "$here/site"
cp -R "$site" "$here/site"
cp "$here/_headers" "$here/site/_headers"
cd "$here"
npx --yes wrangler@4 deploy --config wrangler.toml
