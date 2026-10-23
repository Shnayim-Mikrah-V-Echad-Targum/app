// The accounts' secrets, as Web Crypto computes them. A password is stretched
// with PBKDF2-SHA256 and stored with its algorithm, count and salt, so the count
// can be raised later. A session token, a reset token and a code are kept only
// as hashes: a leaked table holds no working one of them.

// The most PBKDF2 iterations Workers' Web Crypto accepts.
export const PBKDF2_ITERATIONS = 100000;
export const PW_ALG = 'pbkdf2-sha256';

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

// A random token of the given size, as URL-safe text.
export function randomToken(bytes = 32) {
  return b64u(crypto.getRandomValues(new Uint8Array(bytes)));
}

// A six-digit code, drawn without the bias a plain remainder would add.
export function randomCode() {
  const limit = 4294967296 - (4294967296 % 1000000);
  for (;;) {
    const [n] = crypto.getRandomValues(new Uint32Array(1));
    if (n < limit) return String(n % 1000000).padStart(6, '0');
  }
}

// Equal lengths and equal characters, with no early exit on a mismatch.
export function constantTimeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function pbkdf2(password, salt, iterations) {
  const key = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations }, key, 256);
  return new Uint8Array(bits);
}

// The stored form of a password: its algorithm, count, salt and hash.
export async function hashPassword(password, iterations = PBKDF2_ITERATIONS) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await pbkdf2(password, salt, iterations);
  return { pw_alg: PW_ALG, pw_iter: iterations, pw_salt: b64u(salt), pw_hash: b64u(hash) };
}

// Whether the password matches a stored row, with the row's own count.
export async function verifyPassword(password, row) {
  if (row.pw_alg !== PW_ALG) return false;
  const hash = await pbkdf2(password, fromB64u(row.pw_salt), row.pw_iter);
  return constantTimeEqual(b64u(hash), row.pw_hash);
}

let dummy = null;

// A row to check a password against when the address has no account, so that
// a missing address takes as long to answer as a present one.
export function dummyPasswordRow() {
  dummy ??= hashPassword('not-the-password-of-any-account');
  return dummy;
}

// A token's stored form: its SHA-256.
export async function tokenHash(token) {
  return b64u(new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode(token))));
}

// A keyed hash of a text, such as a code or an address: HMAC-SHA256 with a secret.
export async function keyedHash(key, text) {
  const hmacKey = await crypto.subtle.importKey('raw', enc.encode(key), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return b64u(new Uint8Array(await crypto.subtle.sign('HMAC', hmacKey, enc.encode(text))));
}
