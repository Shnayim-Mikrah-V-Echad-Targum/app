// The accounts' pages: plain HTML forms, which the Worker answers itself. The
// forms that the spec protects carry the Turnstile widget. English and Hebrew,
// by ?lang=he or the browser's first language. The Hebrew needs a native
// speaker's review before release.

import { deviceName } from './devices.js';

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
    roles: {
      owner: 'Role: site owner (super admin), with every permission, who names the administrators.',
      admin: 'Role: site administrator, with every permission.',
      moderator: 'Role: community moderator.',
    },
    unverified: 'Your email address is not confirmed yet.',
    streakLabel: 'Your streak',
    streakDays: (n) => `<strong>${n}</strong> ${n === 1 ? 'day' : 'days'} on track`,
    streakWeeks: (n) => `Parsha streak: ${n === 1 ? '1 week' : `${n} weeks`}`,
    streakAsOf: (date) => `From the app’s backup, as of ${date}.`,
    streakStart: 'Read today’s portion in the app to start your streak.',
    streakNone: 'Turn on “Back up progress” in the app’s account page to see your streak here.',
    passwordTitle: 'Password',
    passwordIsSet: 'You have a password.',
    passwordIsNone: 'No password yet: you sign in with an emailed code or a passkey. You can add one.',
    currentPassword: 'Current password',
    passwordChange: 'Change password',
    passwordAdd: 'Add a password',
    passwordStale: 'For your safety, a password can be added only within 15 minutes of signing in. Sign out, then sign in again with an emailed code, and add it then.',
    passwordOthers: 'Your other devices are signed out when it changes.',
    devicesTitle: 'Signed-in devices',
    devicesSince: 'signed in',
    devicesLastUsed: 'last used',
    devicesThis: 'this device',
    devicesSignOut: 'Sign out',
    devicesSignOutOthers: 'Sign out every other device',
    handoffTitle: 'Continue from the app',
    handoffLead: (email) => `The app is signed in as <strong>${email}</strong>. Continue to sign this browser in too.`,
    handoffButton: 'Continue',
    adminPanel: 'Open the admin panel',
    signOut: 'Sign out',
    deleteTitle: 'Delete your account',
    deleteLead: 'This deletes your account, its sessions and its codes, and everything you posted in the community. Enter your password to confirm.',
    deleteLeadNoPassword: 'This deletes your account, its sessions and its codes, and everything you posted in the community. You made it in the app, by code, so it has no password to enter.',
    deleteButton: 'Delete my account',
    signInPasskey: 'Sign in with a passkey',
    signInEmailCode: 'Email me a sign-in code instead',
    passkeyFailed: 'That didn’t work. Try again, or sign in another way.',
    emailCodeTitle: 'Sign in with a code',
    emailCodeLead: 'We will email you a six-digit code. It works for 15 minutes. If the address has no account yet, this makes one.',
    emailCodeSend: 'Email me a code',
    emailCodeEnterLead: 'Enter the six-digit code we sent to your email.',
    twoStepTitle: 'Two-step sign-in',
    twoStepLead: 'Enter the six-digit code from your authenticator app, or one of your recovery codes.',
    twoStepField: 'Code',
    continueButton: 'Continue',
    methodsTitle: 'Ways to sign in',
    passwordSet: 'Password: set. A password reset changes it.',
    passwordNone: 'Password: none. A password reset gives the account one.',
    passkeysTitle: 'Passkeys',
    passkeysLead: 'Sign in with your face, your fingerprint or your device’s PIN instead of a password. A passkey stays on your device, or in your password manager, and works only on this site.',
    passkeysNone: 'No passkeys yet.',
    passkeyAdded: 'Passkey added',
    passkeyLastUsed: 'last used',
    passkeyAdd: 'Add a passkey',
    passkeyRemove: 'Remove',
    passkeyUnsupported: 'This browser can’t make passkeys.',
    totpTitle: 'Authenticator app',
    totpLead: 'Ask for a code from an authenticator app, such as Google Authenticator, Microsoft Authenticator, 1Password or Authy, each time you sign in with a password or an emailed code.',
    totpOn: 'On.',
    recoveryLeft: 'Recovery codes left:',
    totpSetUp: 'Set up an authenticator app',
    totpOff: 'Turn it off',
    totpNewCodes: 'Make new recovery codes',
    totpCodeField: 'A code from your authenticator app, or a recovery code',
    totpSetupTitle: 'Set up your authenticator app',
    totpSetupScan: 'Scan this code with your authenticator app, or type the key below into it.',
    totpSetupQr: 'QR code of the key, for an authenticator app',
    totpSetupKey: 'Key',
    totpSetupOpen: 'Open in an authenticator app on this device',
    totpSetupConfirm: 'Then enter the six-digit code the app shows, to turn it on.',
    totpConfirmButton: 'Turn on',
    recoveryTitle: 'Your recovery codes',
    recoveryLead: 'Keep these somewhere safe, such as a password manager, or on paper. Each signs you in once if you lose your authenticator. They won’t be shown again.',
    recoveryDone: 'I’ve saved them',
    notices: {
      'check-email': 'If the address is new, we have sent it a code.',
      'reset-sent': 'If an account exists for this address, we have sent it a link.',
      'signed-out': 'You are signed out.',
      'reset-done': 'Your password is changed. Sign in with the new one.',
      deleted: 'Your account is deleted.',
      unverified: 'Confirm your email first. We have sent a new code.',
      'totp-on': 'The authenticator app is on.',
      'totp-off': 'The authenticator app is off.',
      'passkey-added': 'The passkey is added. You can sign in with it now.',
      'passkey-removed': 'The passkey is removed.',
      'password-added': 'Your password is added. Your other devices are signed out.',
      'password-changed': 'Your password is changed. Your other devices are signed out.',
      'device-signed-out': 'That device is signed out.',
      'devices-signed-out': 'Every other device is signed out.',
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
      second: 'That code is wrong, or was used already. Try again.',
      current: 'The current password is wrong.',
      stale: 'Sign in again first, then add the password within 15 minutes.',
      handoff: 'This link has expired or was already used. Open it again from the app.',
    },
    footer: 'Protected by Cloudflare Turnstile.',
  },
  he: {
    dir: 'rtl',
    site: 'שניים מקרא · חשבון',
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
    roles: {
      owner: 'תפקיד: בעלים של האתר (מנהל־על), עם כל ההרשאות, שממנה את המנהלים.',
      admin: 'תפקיד: מנהל/ת האתר, עם כל ההרשאות.',
      moderator: 'תפקיד: מנחה בקהילה.',
    },
    unverified: 'כתובת הדוא״ל עדיין לא אומתה.',
    streakLabel: 'הרצף שלך',
    streakDays: (n) => `<strong>${n}</strong> ${n === 1 ? 'יום' : 'ימים'} לפי התוכנית`,
    streakWeeks: (n) => `רצף פרשות: ${n === 1 ? 'שבוע אחד' : n === 2 ? 'שבועיים' : `${n} שבועות`}`,
    streakAsOf: (date) => `מהגיבוי של האפליקציה, נכון ל־${date}.`,
    streakStart: 'קריאת המנה של היום באפליקציה מתחילה את הרצף.',
    streakNone: 'כדי לראות כאן את הרצף, יש להפעיל את „גיבוי ההתקדמות” בדף החשבון באפליקציה.',
    passwordTitle: 'סיסמה',
    passwordIsSet: 'לחשבון יש סיסמה.',
    passwordIsNone: 'עדיין אין סיסמה: ההתחברות היא בקוד שנשלח בדוא״ל או במפתח גישה. אפשר להוסיף סיסמה.',
    currentPassword: 'הסיסמה הנוכחית',
    passwordChange: 'שינוי הסיסמה',
    passwordAdd: 'הוספת סיסמה',
    passwordStale: 'לביטחונך, אפשר להוסיף סיסמה רק בתוך 15 דקות מההתחברות. יש להתנתק, להתחבר שוב בקוד שנשלח בדוא״ל, ואז להוסיף אותה.',
    passwordOthers: 'כשהסיסמה משתנה, שאר המכשירים מתנתקים.',
    devicesTitle: 'מכשירים מחוברים',
    devicesSince: 'התחבר',
    devicesLastUsed: 'שימוש אחרון',
    devicesThis: 'המכשיר הזה',
    devicesSignOut: 'ניתוק',
    devicesSignOutOthers: 'ניתוק כל שאר המכשירים',
    handoffTitle: 'המשך מהאפליקציה',
    handoffLead: (email) => `האפליקציה מחוברת בתור <strong>${email}</strong>. אפשר להמשיך ולחבר גם את הדפדפן הזה.`,
    handoffButton: 'המשך',
    adminPanel: 'פתיחת לוח הניהול',
    signOut: 'יציאה',
    deleteTitle: 'מחיקת החשבון',
    deleteLead: 'הפעולה מוחקת את החשבון, החיבורים והקודים שלו, וכל מה שפרסמתם בקהילה. הזינו את הסיסמה לאישור.',
    deleteLeadNoPassword: 'הפעולה מוחקת את החשבון, החיבורים והקודים שלו, וכל מה שפרסמתם בקהילה. החשבון נוצר באפליקציה, בקוד, ולכן אין לו סיסמה להזין.',
    deleteButton: 'מחיקת החשבון שלי',
    signInPasskey: 'התחברות עם מפתח גישה',
    signInEmailCode: 'שליחת קוד התחברות בדוא״ל במקום',
    passkeyFailed: 'זה לא הצליח. נסו שוב, או התחברו בדרך אחרת.',
    emailCodeTitle: 'התחברות עם קוד',
    emailCodeLead: 'נשלח אליכם בדוא״ל קוד בן שש ספרות, תקף 15 דקות. אם לכתובת עוד אין חשבון, ייווצר חשבון.',
    emailCodeSend: 'שליחת קוד בדוא״ל',
    emailCodeEnterLead: 'הזינו את הקוד בן שש הספרות ששלחנו לדוא״ל שלכם.',
    twoStepTitle: 'התחברות בשני שלבים',
    twoStepLead: 'הזינו את הקוד בן שש הספרות מאפליקציית האימות, או אחד מקודי השחזור שלכם.',
    twoStepField: 'קוד',
    continueButton: 'המשך',
    methodsTitle: 'דרכי התחברות',
    passwordSet: 'סיסמה: מוגדרת. איפוס סיסמה משנה אותה.',
    passwordNone: 'סיסמה: אין. איפוס סיסמה נותן לחשבון סיסמה.',
    passkeysTitle: 'מפתחות גישה',
    passkeysLead: 'התחברות בזיהוי פנים, בטביעת אצבע או בקוד המכשיר, במקום סיסמה. מפתח הגישה נשמר במכשיר או במנהל הסיסמאות, ופועל רק באתר הזה.',
    passkeysNone: 'עוד אין מפתחות גישה.',
    passkeyAdded: 'מפתח גישה נוסף',
    passkeyLastUsed: 'שימוש אחרון',
    passkeyAdd: 'הוספת מפתח גישה',
    passkeyRemove: 'הסרה',
    passkeyUnsupported: 'הדפדפן הזה לא יכול ליצור מפתחות גישה.',
    totpTitle: 'אפליקציית אימות',
    totpLead: 'בקשת קוד מאפליקציית אימות, כמו Google Authenticator,‏ Microsoft Authenticator,‏ 1Password או Authy, בכל התחברות בסיסמה או בקוד שנשלח בדוא״ל.',
    totpOn: 'פועלת.',
    recoveryLeft: 'קודי שחזור שנותרו:',
    totpSetUp: 'הגדרת אפליקציית אימות',
    totpOff: 'כיבוי',
    totpNewCodes: 'יצירת קודי שחזור חדשים',
    totpCodeField: 'קוד מאפליקציית האימות, או קוד שחזור',
    totpSetupTitle: 'הגדרת אפליקציית האימות',
    totpSetupScan: 'סרקו את הקוד הזה באפליקציית האימות, או הקלידו בה את המפתח שלמטה.',
    totpSetupQr: 'קוד QR של המפתח, לאפליקציית אימות',
    totpSetupKey: 'מפתח',
    totpSetupOpen: 'פתיחה באפליקציית אימות במכשיר הזה',
    totpSetupConfirm: 'אחר כך הזינו את הקוד בן שש הספרות שהאפליקציה מציגה, כדי להפעיל.',
    totpConfirmButton: 'הפעלה',
    recoveryTitle: 'קודי השחזור שלכם',
    recoveryLead: 'שמרו אותם במקום בטוח, כמו מנהל סיסמאות, או על נייר. כל אחד מהם מחבר אתכם פעם אחת אם תאבדו את אפליקציית האימות. הם לא יוצגו שוב.',
    recoveryDone: 'שמרתי אותם',
    notices: {
      'check-email': 'אם הכתובת חדשה, שלחנו אליה קוד.',
      'reset-sent': 'אם יש חשבון לכתובת הזאת, שלחנו אליה קישור.',
      'signed-out': 'יצאתם מהחשבון.',
      'reset-done': 'הסיסמה שונתה. התחברו עם הסיסמה החדשה.',
      deleted: 'החשבון נמחק.',
      unverified: 'יש לאמת את הדוא״ל לפני ההתחברות. שלחנו קוד חדש.',
      'totp-on': 'אפליקציית האימות פועלת.',
      'totp-off': 'אפליקציית האימות כובתה.',
      'passkey-added': 'מפתח הגישה נוסף. אפשר להתחבר איתו עכשיו.',
      'passkey-removed': 'מפתח הגישה הוסר.',
      'password-added': 'הסיסמה נוספה. שאר המכשירים נותקו.',
      'password-changed': 'הסיסמה שונתה. שאר המכשירים נותקו.',
      'device-signed-out': 'המכשיר נותק.',
      'devices-signed-out': 'כל שאר המכשירים נותקו.',
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
      second: 'הקוד שגוי, או שכבר נעשה בו שימוש. נסו שוב.',
      current: 'הסיסמה הנוכחית שגויה.',
      stale: 'יש להתחבר שוב קודם, ולהוסיף את הסיסמה בתוך 15 דקות.',
      handoff: 'תוקף הקישור פג או שכבר נעשה בו שימוש. יש לפתוח אותו שוב מהאפליקציה.',
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
// With [script], the page loads the passkey script (account_methods.js).
export function render(lang, { title, body, notice, error, status = 200, script = false }) {
  const t = STRINGS[lang];
  const known = notice && Object.hasOwn(t.notices, notice);
  const message = error && Object.hasOwn(t.errors, error) ? `<p class="error" role="alert">${t.errors[error]}</p>`
    : known ? `<p class="notice" role="status">${t.notices[notice]}</p>` : '';
  const html = `<!doctype html>
<html lang="${lang}" dir="${t.dir}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${escapeHtml(title)} · ${t.site}</title>
${script ? '<script src="/account/passkey.js" defer></script>' : ''}
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
  h2 { font-size: 1.15rem; margin: 2rem 0 .5rem; }
  h3 { font-size: 1rem; margin: 1.25rem 0 .25rem; }
  .secondary { background: transparent; color: var(--accent); border: 1px solid currentColor; }
  .qr { display: block; width: 12rem; max-width: 100%; margin: 1rem 0; }
  .key { font-family: ui-monospace, monospace; font-size: 1.05rem; letter-spacing: .05em; direction: ltr; unicode-bidi: isolate; }
  .codes { font-family: ui-monospace, monospace; font-size: 1.1rem; direction: ltr; display: grid; grid-template-columns: repeat(2, max-content); gap: .4rem 2rem; padding: 0; list-style: none; }
  ul.keys { padding: 0; list-style: none; }
  ul.keys li { display: flex; gap: 1rem; align-items: center; justify-content: space-between; }
  ul.keys form { margin: .25rem 0; }
  .streak { display: flex; gap: .9rem; align-items: center; padding: .9rem 1rem; margin: 0 0 1.25rem; border-radius: .6rem; background: color-mix(in srgb, #e8590c 12%, transparent); }
  .streak .flame { font-size: 2.6rem; line-height: 1; }
  .streak p { margin: .1rem 0; }
  .streak .big { font-size: 1.15rem; }
  .streak .big strong { font-size: 1.6rem; }
  ul.devices { padding: 0; list-style: none; }
  ul.devices li { display: flex; gap: 1rem; align-items: center; justify-content: space-between; border-bottom: 1px solid color-mix(in srgb, currentColor 15%, transparent); padding: .35rem 0; }
  ul.devices form { margin: .25rem 0; }
  ul.devices button, ul.keys button { white-space: nowrap; }
  .date { white-space: nowrap; }
  [hidden] { display: none !important; }
</style>
</head>
<body>
<main>
<h1>${escapeHtml(title)}</h1>
${message}
${body ?? ''}
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
<p data-passkey hidden><button type="button" id="passkey-signin" class="secondary" data-failed="${escapeHtml(t.passkeyFailed)}" data-next="${link('/account', lang)}">${t.signInPasskey}</button></p>
<p id="passkey-status" role="status"></p>
<p><a href="${link('/account/sign-in/email', lang)}">${t.signInEmailCode}</a></p>
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

// A date as the account page shows it: the day, in UTC, kept whole and
// apart from the words around it, which in Hebrew run the other way.
function day(ms) {
  return dateText(new Date(ms).toISOString().slice(0, 10));
}

function dateText(iso) {
  return `<bdi class="date">${escapeHtml(iso)}</bdi>`;
}

// The signed-in account's page: the streak the app backed up, then its ways
// of signing in ([security]: the password, the passkeys, the authenticator
// and its recovery codes left), the devices signed in, and deleting. An
// account made in the app has no password (pw_alg 'none'), so deleting it
// asks for none, and a password is added to it soon after signing in
// ([security].fresh).
export function accountBody(lang, { email, email_verified_at: verified, role, pw_alg: alg }, security = {}) {
  const t = STRINGS[lang];
  const hasPassword = alg === 'pbkdf2-sha256';
  const { totp = false, recoveryLeft = 0, passkeys = [], sessions = [], thisSession = null, fresh = false, streak = null } = security;
  const codeField = field('code', t.totpCodeField, 'text', 'autocomplete="one-time-code" required maxlength="12"');
  const keys = passkeys.length
    ? `<ul class="keys">${passkeys.map((k) => `<li><span>${t.passkeyAdded} ${day(k.created_at)}${k.last_used_at ? `, ${t.passkeyLastUsed} ${day(k.last_used_at)}` : ''}</span>
<form method="post" action="${link('/account/passkey/remove', lang)}"><input type="hidden" name="id" value="${escapeHtml(k.id)}"><button type="submit" class="secondary">${t.passkeyRemove}</button></form></li>`).join('\n')}</ul>`
    : `<p class="muted">${t.passkeysNone}</p>`;
  const devices = sessions.map((d) => `<li><span><bdi dir="${t.dir}">${escapeHtml(deviceName(d.device, lang))}</bdi>${d.id === thisSession ? ` (${t.devicesThis})` : ''}<br>
<span class="muted">${t.devicesSince} ${day(d.created_at)} · ${t.devicesLastUsed} ${day(d.last_seen_at)}</span></span>
<form method="post" action="${link('/account/devices/sign-out', lang)}"><input type="hidden" name="id" value="${d.id}"><button type="submit" class="secondary">${t.devicesSignOut}</button></form></li>`).join('\n');
  const password = hasPassword
    ? `<p>${t.passwordIsSet}</p>
<form method="post" action="${link('/account/password', lang)}">
<input type="hidden" name="username" autocomplete="username" value="${escapeHtml(email)}">
${field('password', t.currentPassword, 'password', 'autocomplete="current-password" required maxlength="128"')}
${field('new_password', t.newPassword, 'password', 'autocomplete="new-password" required minlength="10" maxlength="128"')}
<button type="submit" class="secondary">${t.passwordChange}</button>
</form>
<p class="muted">${t.passwordOthers} <a href="${link('/account/reset', lang)}">${t.forgot}</a></p>`
    : `<p>${t.passwordIsNone}</p>
${fresh ? `<form method="post" action="${link('/account/password', lang)}">
<input type="hidden" name="username" autocomplete="username" value="${escapeHtml(email)}">
${field('new_password', t.newPassword, 'password', 'autocomplete="new-password" required minlength="10" maxlength="128"')}
<button type="submit" class="secondary">${t.passwordAdd}</button>
</form>` : `<p class="muted">${t.passwordStale}</p>`}`;
  return `${streakCard(t, streak)}
<p>${t.signedInAs} <strong>${escapeHtml(email)}</strong></p>
${role && Object.hasOwn(t.roles, role) ? `<p>${t.roles[role]}</p>` : ''}
${role === 'admin' || role === 'owner' ? `<p><a href="/account/admin">${t.adminPanel}</a></p>` : ''}
${verified ? '' : `<p>${t.unverified}</p>`}
<form method="post" action="${link('/account/sign-out', lang)}">
<button type="submit">${t.signOut}</button>
</form>
<h2>${t.methodsTitle}</h2>
<h3>${t.passwordTitle}</h3>
${password}
<h3>${t.passkeysTitle}</h3>
<p class="muted">${t.passkeysLead}</p>
${keys}
<p data-passkey hidden><button type="button" id="passkey-add" data-done="${link('/account', lang)}${lang === 'he' ? '&amp;' : '?'}notice=passkey-added" data-failed="${escapeHtml(t.passkeyFailed)}">${t.passkeyAdd}</button></p>
<p id="passkey-status" role="status"></p>
<h3>${t.totpTitle}</h3>
<p class="muted">${t.totpLead}</p>
${totp ? `<p>${t.totpOn} ${t.recoveryLeft} ${recoveryLeft}</p>
<form method="post" action="${link('/account/recovery/new', lang)}">${codeField}<button type="submit" class="secondary">${t.totpNewCodes}</button></form>
<form method="post" action="${link('/account/totp/disable', lang)}">${codeField}<button type="submit" class="secondary">${t.totpOff}</button></form>`
    : `<form method="post" action="${link('/account/totp/start', lang)}"><button type="submit">${t.totpSetUp}</button></form>`}
<h2>${t.devicesTitle}</h2>
<ul class="devices">${devices}</ul>
${sessions.length > 1 ? `<form method="post" action="${link('/account/devices/sign-out', lang)}"><input type="hidden" name="others" value="yes"><button type="submit" class="secondary">${t.devicesSignOutOthers}</button></form>` : ''}
<h2>${t.deleteTitle}</h2>
<p class="muted">${hasPassword ? t.deleteLead : t.deleteLeadNoPassword}</p>
<form method="post" action="${link('/account/delete', lang)}">
${hasPassword ? field('password', t.password, 'password', 'autocomplete="current-password" required maxlength="128"') : ''}
<button type="submit">${t.deleteButton}</button>
</form>`;
}

// The streak, at the top of the page, with the fire: the days on track and
// the parsha streak, as the app last counted them; or how to see them here.
function streakCard(t, streak) {
  const lines = streak
    ? `<p class="big">${t.streakDays(streak.days)}</p>
<p>${t.streakWeeks(streak.weeks)}</p>
${streak.days === 0 && streak.weeks === 0 ? `<p class="muted">${t.streakStart}</p>` : ''}
${streak.asOf ? `<p class="muted">${t.streakAsOf(dateText(streak.asOf))}</p>` : ''}`
    : `<p>${t.streakNone}</p>`;
  return `<section class="streak" aria-label="${escapeHtml(t.streakLabel)}"><span class="flame" aria-hidden="true">🔥</span><div>${lines}</div></section>`;
}

// The page a link from the app opens: who the app is signed in as, and a
// button to sign this browser in too.
export function handoffBody(lang, email, token) {
  const t = STRINGS[lang];
  return `<p>${t.handoffLead(escapeHtml(email))}</p>
<form method="post" action="${link('/account/handoff', lang)}">
<input type="hidden" name="token" value="${escapeHtml(token)}">
<button type="submit">${t.handoffButton}</button>
</form>`;
}

export function strings(lang) {
  return STRINGS[lang];
}

export function emailCodeBody(lang, siteKey) {
  const t = STRINGS[lang];
  return `<p>${t.emailCodeLead}</p>
<form method="post" action="${link('/account/sign-in/email', lang)}">
${field('email', t.email, 'email', 'autocomplete="email" required maxlength="254"')}
${turnstile(siteKey)}
<button type="submit">${t.emailCodeSend}</button>
</form>
<p><a href="${link('/account/sign-in', lang)}">${t.signInTitle}</a></p>`;
}

export function emailCodeEnterBody(lang, email) {
  const t = STRINGS[lang];
  return `<p>${t.emailCodeEnterLead}</p>
<form method="post" action="${link('/account/sign-in/code', lang)}">
${field('email', t.email, 'email', `autocomplete="email" required maxlength="254" value="${escapeHtml(email)}"`)}
${field('code', t.code, 'text', 'inputmode="numeric" autocomplete="one-time-code" required pattern="[0-9]{6}" maxlength="6"')}
<button type="submit">${t.signInButton}</button>
</form>
<p><a href="${link('/account/sign-in/email', lang)}">${t.resendButton}</a></p>`;
}

export function twoStepBody(lang) {
  const t = STRINGS[lang];
  return `<p>${t.twoStepLead}</p>
<form method="post" action="${link('/account/two-step', lang)}">
${field('code', t.twoStepField, 'text', 'autocomplete="one-time-code" required maxlength="12" autofocus')}
<button type="submit">${t.continueButton}</button>
</form>`;
}

// The authenticator's set-up: the key as a QR code ([qr], an SVG made here),
// as text in groups of four, and as a link for an app on the same device.
export function totpSetupBody(lang, { qr, key, uri }) {
  const t = STRINGS[lang];
  return `<p>${t.totpSetupScan}</p>
<div class="qr" role="img" aria-label="${escapeHtml(t.totpSetupQr)}">${qr}</div>
<p>${t.totpSetupKey}: <span class="key">${escapeHtml(key)}</span></p>
<p><a href="${escapeHtml(uri)}">${t.totpSetupOpen}</a></p>
<p>${t.totpSetupConfirm}</p>
<form method="post" action="${link('/account/totp/confirm', lang)}">
${field('code', t.code, 'text', 'inputmode="numeric" autocomplete="one-time-code" required pattern="[0-9 ]{6,7}" maxlength="7"')}
<button type="submit">${t.totpConfirmButton}</button>
</form>`;
}

export function recoveryBody(lang, codes) {
  const t = STRINGS[lang];
  return `<p>${t.recoveryLead}</p>
<ul class="codes">${codes.map((c) => `<li>${escapeHtml(c)}</li>`).join('')}</ul>
<p><a href="${link('/account', lang)}">${t.recoveryDone}</a></p>`;
}
