// What a session signed in from, coarsely, for the account page's list of
// signed-in devices and the admin panel's: a browser and its system, or the
// app on its system. Never the whole user agent (README, Accounts, What is
// stored). Kept as "browser|Chrome|Android" or "app||Windows", and named in
// the page's language when shown.

const SYSTEMS = [
  [/Windows/, 'Windows'],
  [/iPhone|iPad|iPod/, 'iOS'],
  [/Android/, 'Android'],
  [/CrOS/, 'ChromeOS'],
  [/Macintosh|Mac OS X/, 'macOS'],
  [/Linux/, 'Linux'],
];

// In order: each later one's token is in the earlier ones' user agents too.
const BROWSERS = [
  [/Edg(A|iOS)?\//, 'Edge'],
  [/OPR\/|Opera/, 'Opera'],
  [/SamsungBrowser\//, 'Samsung Internet'],
  [/DuckDuckGo\/|Ddg\//, 'DuckDuckGo'],
  [/Firefox\/|FxiOS\//, 'Firefox'],
  [/CriOS\/|Chrome\//, 'Chrome'],
  [/Safari\//, 'Safari'],
];

// The systems the app sends in X-App-Platform (WorkerForumRepository).
const APP_SYSTEMS = { android: 'Android', ios: 'iOS', windows: 'Windows', macos: 'macOS', linux: 'Linux' };

function first(list, ua) {
  return list.find(([pattern]) => pattern.test(ua))?.[1] ?? '';
}

export function deviceOf(request) {
  const ua = request.headers.get('user-agent') || '';
  const app = (request.headers.get('x-app-platform') || '').toLowerCase();
  if (Object.hasOwn(APP_SYSTEMS, app) || /^Dart\//.test(ua)) return `app||${APP_SYSTEMS[app] ?? first(SYSTEMS, ua)}`;
  return `browser|${first(BROWSERS, ua)}|${first(SYSTEMS, ua)}`;
}

const NAMES = {
  en: {
    app: 'The app',
    browser: 'A browser',
    on: (what, system) => `${what} on ${system}`,
    unknown: 'A device',
  },
  he: {
    app: 'האפליקציה',
    browser: 'דפדפן',
    on: (what, system) => `${what} ב־${system}`,
    unknown: 'מכשיר',
  },
};

// A session's device, named: "Chrome on Android", "The app on Windows".
export function deviceName(device, lang) {
  const n = NAMES[lang] ?? NAMES.en;
  const [kind, browser, system] = String(device ?? '').split('|');
  if (kind !== 'app' && kind !== 'browser') return n.unknown;
  const what = kind === 'app' ? n.app : browser || n.browser;
  return system ? n.on(what, system) : what;
}
