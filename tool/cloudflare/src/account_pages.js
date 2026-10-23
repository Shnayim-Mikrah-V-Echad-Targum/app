// The accounts' pages: plain HTML forms, which the Worker answers itself. The
// forms that the spec protects carry the Turnstile widget. English and Hebrew,
// by ?lang=he or the browser's first language. The Hebrew needs a native
// speaker's review before release.

const STRINGS = {
  en: {
    dir: 'ltr',
    site: 'Shnayim Mikrah · Account',
    email: 'Email address',
    password: 'Password (at least 10 characters)',
    newPassword: 'New password (at least 10 characters)',
    code: 'The six-digit code',
    signUpTitle: 'Create an account',
    signUpButton: 'Create account',
    signUpSwitch: 'Already have an account? Sign in',
    signInTitle: 'Sign in',
    signInButton: 'Sign in',
    signInSwitch: 'New here? Create an account',
    forgot: 'Forgot your password?',
    verifyTitle: 'Check your email',
    verifyLead: 'Enter the six-digit code we sent. It works for 15 minutes.',
    verifyButton: 'Confirm',
    resendButton: 'Send a new code',
    resetTitle: 'Reset your password',
    resetLead: 'If an account exists for this address, we will email a link that works for an hour.',
    resetButton: 'Send the link',
    resetCompleteTitle: 'Choose a new password',
    resetCompleteButton: 'Save the new password',
    accountTitle: 'Your account',
    signedInAs: 'Signed in as',
    signOut: 'Sign out',
    deleteTitle: 'Delete your account',
    deleteLead: 'This deletes your account, its sessions and its codes. Enter your password to confirm.',
    deleteButton: 'Delete my account',
    notices: {
      'check-email': 'If the address is new, we have sent it a code.',
      'reset-sent': 'If an account exists for this address, we have sent it a link.',
      'signed-out': 'You are signed out.',
      'reset-done': 'Your password is changed. Sign in with the new one.',
      deleted: 'Your account is deleted.',
      unverified: 'Confirm your email first. We have sent a new code.',
    },
    errors: {
      email: 'That address does not look right.',
      password: 'The password must be between 10 and 128 characters.',
      credentials: 'The address or the password is wrong.',
      code: 'The code is wrong or has expired. You can ask for a new one.',
      limited: 'Too many tries. Wait a while, then try again.',
      human: 'The check failed. Try again.',
      link: 'This link has expired or was already used. Ask for a new one.',
      unavailable: 'Accounts are not set up yet.',
      email_send: 'We could not send the email. Try again later.',
      forbidden: 'This request was refused.',
      notFound: 'This page does not exist.',
    },
    footer: 'Protected by Cloudflare Turnstile.',
  },
  he: {
    dir: 'rtl',
    site: 'שמע מקרא · חשבון',
    email: 'כתובת דוא״ל',
    password: 'סיסמה (לפחות 10 תווים)',
    newPassword: 'סיסמה חדשה (לפחות 10 תווים)',
    code: 'קוד בן שש ספרות',
    signUpTitle: 'יצירת חשבון',
    signUpButton: 'יצירת חשבון',
    signUpSwitch: 'כבר יש לכם חשבון? להתחברות',
    signInTitle: 'התחברות',
    signInButton: 'התחברות',
    signInSwitch: 'חדשים כאן? יצירת חשבון',
    forgot: 'שכחתם את הסיסמה?',
    verifyTitle: 'בדקו את הדוא״ל',
    verifyLead: 'הזינו את הקוד בן שש הספרות שלחנו. הוא תקף 15 דקות.',
    verifyButton: 'אישור',
    resendButton: 'שליחת קוד חדש',
    resetTitle: 'איפוס סיסמה',
    resetLead: 'אם יש חשבון לכתובת הזאת, נשלח אליה קישור שתקף שעה.',
    resetButton: 'שליחת הקישור',
    resetCompleteTitle: 'בחירת סיסמה חדשה',
    resetCompleteButton: 'שמירת הסיסמה החדשה',
    accountTitle: 'החשבון שלכם',
    signedInAs: 'מחוברים בתור',
    signOut: 'יציאה',
    deleteTitle: 'מחיקת החשבון',
    deleteLead: 'הפעולה מוחקת את החשבון, החיבורים והקודים שלו. הזינו את הסיסמה לאישור.',
    deleteButton: 'מחיקת החשבון שלי',
    notices: {
      'check-email': 'אם הכתובת חדשה, שלחנו אליה קוד.',
      'reset-sent': 'אם יש חשבון לכתובת הזאת, שלחנו אליה קישור.',
      'signed-out': 'יצאתם מהחשבון.',
      'reset-done': 'הסיסמה שונתה. התחברו עם הסיסמה החדשה.',
      deleted: 'החשבון נמחק.',
      unverified: 'יש לאמת את הדוא״ל לפני ההתחברות. שלחנו קוד חדש.',
    },
    errors: {
      email: 'כתובת הדוא״ל אינה נראית תקינה.',
      password: 'הסיסמה חייבת להיות בין 10 ל־128 תווים.',
      credentials: 'הכתובת או הסיסמה שגויים.',
      code: 'הקוד שגוי או שפג תוקפו. אפשר לבקש קוד חדש.',
      limited: 'יותר מדי ניסיונות. המתינו זמן מה ונסו שוב.',
      human: 'הבדיקה נכשלה. נסו שוב.',
      link: 'הקישור פג תוקף או שכבר נוצל. אפשר לבקש קישור חדש.',
      unavailable: 'החשבונות עדיין לא הוגדרו.',
      email_send: 'לא הצלחנו לשלוח דוא״ל. נסו שוב מאוחר יותר.',
      forbidden: 'הבקשה נדחתה.',
      notFound: 'הדף הזה אינו קיים.',
    },
    footer: 'מוגן באמצעות Cloudflare Turnstile.',
  },
};

export function langOf(url, acceptLanguage) {
  const asked = url.searchParams.get('lang');
  if (asked === 'he' || asked === 'en') return asked;
  return /^he\b/i.test(acceptLanguage || '') ? 'he' : 'en';
}

export function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

// A link within the accounts, keeping the language.
function link(path, lang) {
  return lang === 'he' ? `${path}?lang=he` : path;
}

function turnstile(siteKey) {
  if (!siteKey) return '';
  return `<div class="cf-turnstile" data-sitekey="${escapeHtml(siteKey)}"></div>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>`;
}

function field(name, label, type, extra = '') {
  return `<label>${label}<input name="${name}" type="${type}" ${extra}></label>`;
}

// A page with its notice or error, and its body.
export function render(lang, { title, body, notice, error, status = 200 }) {
  const t = STRINGS[lang];
  const known = notice && Object.hasOwn(t.notices, notice);
  const message = error ? `<p class="error" role="alert">${t.errors[error]}</p>`
    : known ? `<p class="notice" role="status">${t.notices[notice]}</p>` : '';
  const html = `<!doctype html>
<html lang="${lang}" dir="${t.dir}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${escapeHtml(title)} · ${t.site}</title>
<style>
  :root { color-scheme: light dark; --fg: #1d1b18; --bg: #fbf9f4; --accent: #2e5c4a; --err: #9b2c1f; }
  @media (prefers-color-scheme: dark) { :root { --fg: #efeae0; --bg: #1a1916; --accent: #8fc2a8; --err: #f0a090; } }
  body { margin: 0; background: var(--bg); color: var(--fg); font: 1rem/1.5 system-ui, sans-serif; }
  main { max-width: 26rem; margin: 0 auto; padding: 2.5rem 1rem; }
  h1 { font-size: 1.5rem; margin: 0 0 1rem; }
  form { display: grid; gap: 1rem; margin: 1.25rem 0; }
  label { display: grid; gap: .35rem; }
  input { font: inherit; padding: .6rem .7rem; border: 1px solid currentColor; border-radius: .4rem; background: transparent; color: inherit; }
  button { font: inherit; padding: .7rem 1rem; border: 0; border-radius: .4rem; background: var(--accent); color: #fff; cursor: pointer; }
  a { color: var(--accent); }
  .error { color: var(--err); font-weight: 600; }
  .notice { font-weight: 600; }
  .muted { font-size: .875rem; opacity: .8; }
</style>
</head>
<body>
<main>
<h1>${escapeHtml(title)}</h1>
${message}
${body}
<p class="muted">${t.footer}</p>
</main>
</body>
</html>`;
  return { html, status };
}

export function signUpBody(lang, siteKey) {
  const t = STRINGS[lang];
  return `<form method="post" action="${link('/account/sign-up', lang)}">
${field('email', t.email, 'email', 'autocomplete="email" required maxlength="254"')}
${field('password', t.password, 'password', 'autocomplete="new-password" required minlength="10" maxlength="128"')}
${turnstile(siteKey)}
<button type="submit">${t.signUpButton}</button>
</form>
<p><a href="${link('/account/sign-in', lang)}">${t.signInSwitch}</a></p>`;
}

export function signInBody(lang, siteKey) {
  const t = STRINGS[lang];
  return `<form method="post" action="${link('/account/sign-in', lang)}">
${field('email', t.email, 'email', 'autocomplete="email" required maxlength="254"')}
${field('password', t.password, 'password', 'autocomplete="current-password" required maxlength="128"')}
${turnstile(siteKey)}
<button type="submit">${t.signInButton}</button>
</form>
<p><a href="${link('/account/reset', lang)}">${t.forgot}</a></p>
<p><a href="${link('/account/sign-up', lang)}">${t.signUpSwitch}</a></p>`;
}

export function verifyBody(lang, email) {
  const t = STRINGS[lang];
  return `<p>${t.verifyLead}</p>
<form method="post" action="${link('/account/verify', lang)}">
${field('email', t.email, 'email', `autocomplete="email" required maxlength="254" value="${escapeHtml(email)}"`)}
${field('code', t.code, 'text', 'inputmode="numeric" autocomplete="one-time-code" required pattern="[0-9]{6}" maxlength="6"')}
<button type="submit">${t.verifyButton}</button>
</form>
<form method="post" action="${link('/account/verify/resend', lang)}">
<input type="hidden" name="email" value="${escapeHtml(email)}">
<button type="submit">${t.resendButton}</button>
</form>`;
}

export function resetBody(lang, siteKey) {
  const t = STRINGS[lang];
  return `<p>${t.resetLead}</p>
<form method="post" action="${link('/account/reset', lang)}">
${field('email', t.email, 'email', 'autocomplete="email" required maxlength="254"')}
${turnstile(siteKey)}
<button type="submit">${t.resetButton}</button>
</form>`;
}

export function resetCompleteBody(lang, token, siteKey) {
  const t = STRINGS[lang];
  return `<form method="post" action="${link('/account/reset/complete', lang)}">
<input type="hidden" name="token" value="${escapeHtml(token)}">
${field('password', t.newPassword, 'password', 'autocomplete="new-password" required minlength="10" maxlength="128"')}
${turnstile(siteKey)}
<button type="submit">${t.resetCompleteButton}</button>
</form>`;
}

export function accountBody(lang, email, verified) {
  const t = STRINGS[lang];
  return `<p>${t.signedInAs} <strong>${escapeHtml(email)}</strong></p>
${verified ? '' : `<p>${t.unverified}</p>`}
<form method="post" action="${link('/account/sign-out', lang)}">
<button type="submit">${t.signOut}</button>
</form>
<h2>${t.deleteTitle}</h2>
<p class="muted">${t.deleteLead}</p>
<form method="post" action="${link('/account/delete', lang)}">
${field('password', t.password, 'password', 'autocomplete="current-password" required maxlength="128"')}
<button type="submit">${t.deleteButton}</button>
</form>`;
}

export function strings(lang) {
  return STRINGS[lang];
}
