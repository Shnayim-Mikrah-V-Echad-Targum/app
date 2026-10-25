// The second step of signing in: a code from an authenticator app (TOTP,
// RFC 6238: HMAC-SHA1, six digits, a new one every 30 seconds), and the
// recovery codes that stand in for it, once each. The shared secret is kept
// encrypted (AES-GCM, with a key drawn from ACCOUNTS_KEY), so the table alone
// gives no codes; a recovery code is kept only as a keyed hash.

const STEP_SECONDS = 30;
const DIGITS = 6;
const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
// Recovery codes: no 0/o, 1/l/i, which read alike.
const RECOVERY_ALPHABET = 'abcdefghjkmnpqrstuvwxyz23456789';
export const RECOVERY_COUNT = 10;

const enc = new TextEncoder();

function b64u(bytes) {
  let text = '';
  for (const byte of bytes) text += String.fromCharCode(byte);
  return btoa(text).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fromB64u(text) {
  const binary = atob(text.replace(/-/g, '+').replace(/_/g, '/'));
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

// Base32 (RFC 4648, no padding), as authenticator apps read a secret.
export function base32(bytes) {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += ALPHABET[(value << (5 - bits)) & 31];
  return out;
}

export function fromBase32(text) {
  const clean = text.toUpperCase().replace(/[^A-Z2-7]/g, '');
  let bits = 0;
  let value = 0;
  const out = [];
  for (const char of clean) {
    value = (value << 5) | ALPHABET.indexOf(char);
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Uint8Array.from(out);
}

// A new shared secret: 20 random bytes, as RFC 4226 recommends.
export function newSecret() {
  return crypto.getRandomValues(new Uint8Array(20));
}

// The code for time step [counter] (RFC 4226's HOTP).
export async function hotp(secret, counter) {
  const key = await crypto.subtle.importKey('raw', secret, { name: 'HMAC', hash: 'SHA-1' }, false, ['sign']);
  const message = new Uint8Array(8);
  new DataView(message.buffer).setBigUint64(0, BigInt(counter));
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', key, message));
  const offset = mac[mac.length - 1] & 15;
  const number = ((mac[offset] & 127) << 24) | (mac[offset + 1] << 16) | (mac[offset + 2] << 8) | mac[offset + 3];
  return String(number % 10 ** DIGITS).padStart(DIGITS, '0');
}

export function stepAt(nowMs) {
  return Math.floor(nowMs / 1000 / STEP_SECONDS);
}

// The time step [code] is right for, within one step either side of now for
// a clock a little off, and only after [lastStep], so that no code works
// twice; or null.
export async function totpStep(secret, code, nowMs, lastStep = 0) {
  if (!/^\d{6}$/.test(code)) return null;
  const now = stepAt(nowMs);
  for (const step of [now, now - 1, now + 1]) {
    if (step > lastStep && (await hotp(secret, step)) === code) return step;
  }
  return null;
}

async function aesKey(env) {
  const raw = await crypto.subtle.digest('SHA-256', enc.encode(`totp-secret|${env.ACCOUNTS_KEY}`));
  return crypto.subtle.importKey('raw', raw, 'AES-GCM', false, ['encrypt', 'decrypt']);
}

// The secret as stored: a random IV and the ciphertext, base64url.
export async function sealSecret(env, secret) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const sealed = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, await aesKey(env), secret));
  const out = new Uint8Array(iv.length + sealed.length);
  out.set(iv);
  out.set(sealed, iv.length);
  return b64u(out);
}

export async function openSecret(env, stored) {
  const bytes = fromB64u(stored);
  const plain = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: bytes.slice(0, 12) }, await aesKey(env), bytes.slice(12));
  return new Uint8Array(plain);
}

// The link an authenticator app takes the secret from, as a QR code or a tap.
export function otpauthUri(secret, email) {
  const label = encodeURIComponent(`Shnayim Mikrah:${email}`);
  return `otpauth://totp/${label}?secret=${base32(secret)}&issuer=Shnayim%20Mikrah&algorithm=SHA1&digits=6&period=30`;
}

// Ten new recovery codes, such as "kq7m-3xzp".
export function newRecoveryCodes(count = RECOVERY_COUNT) {
  const codes = [];
  for (let i = 0; i < count; i++) {
    const limit = 256 - (256 % RECOVERY_ALPHABET.length);
    let code = '';
    while (code.length < 8) {
      const [byte] = crypto.getRandomValues(new Uint8Array(1));
      if (byte < limit) code += RECOVERY_ALPHABET[byte % RECOVERY_ALPHABET.length];
    }
    codes.push(`${code.slice(0, 4)}-${code.slice(4)}`);
  }
  return codes;
}

// A recovery code as typed, as it is compared: lower case, without spaces or
// the dash.
export function recoveryForm(text) {
  return String(text ?? '').toLowerCase().replace(/[\s-]/g, '');
}
