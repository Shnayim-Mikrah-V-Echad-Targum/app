// Passkeys (WebAuthn Level 2): registering one on the account page, and
// signing in with one. The browser and the device do the cryptography; here
// the server checks what they send against the challenge it gave, its own
// origin and relying party (the site's host), and, at sign-in, the signature
// against the public key kept at registration. No attestation is asked for
// ("none"), so no maker's certificate is checked or kept: a passkey is the
// key pair alone, and the account it was made for.
//
// Only ES256 (ECDSA P-256, which every platform's passkeys use) and RS256
// (Windows Hello's older keys) are taken.

const enc = new TextEncoder();
const ES256 = -7;
const RS256 = -257;

const FLAG_USER_PRESENT = 0x01;
const FLAG_ATTESTED_DATA = 0x40;

export function b64u(bytes) {
  let text = '';
  for (const byte of bytes) text += String.fromCharCode(byte);
  return btoa(text).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function fromB64u(text) {
  if (typeof text !== 'string' || !/^[A-Za-z0-9_-]*$/.test(text)) throw new PasskeyError('malformed');
  const binary = atob(text.replace(/-/g, '+').replace(/_/g, '/'));
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

export class PasskeyError extends Error {}

// --- CBOR (RFC 8949), as much as WebAuthn uses: definite lengths only ----------

export function cborDecode(bytes, start = 0) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let at = start;
  const need = (n) => {
    if (at + n > bytes.length) throw new PasskeyError('malformed');
  };
  const length = (info) => {
    if (info < 24) return info;
    if (info === 24) { need(1); return bytes[at++]; }
    if (info === 25) { need(2); const n = view.getUint16(at); at += 2; return n; }
    if (info === 26) { need(4); const n = view.getUint32(at); at += 4; return n; }
    if (info === 27) { need(8); const n = Number(view.getBigUint64(at)); at += 8; return n; }
    throw new PasskeyError('malformed');
  };
  const item = (depth) => {
    if (depth > 16) throw new PasskeyError('malformed');
    need(1);
    const head = bytes[at++];
    const major = head >> 5;
    const info = head & 31;
    switch (major) {
      case 0: return length(info);
      case 1: return -1 - length(info);
      case 2: { const n = length(info); need(n); const out = bytes.slice(at, at + n); at += n; return out; }
      case 3: { const n = length(info); need(n); const out = new TextDecoder().decode(bytes.subarray(at, at + n)); at += n; return out; }
      case 4: { const n = length(info); const out = []; for (let i = 0; i < n; i++) out.push(item(depth + 1)); return out; }
      case 5: {
        const n = length(info);
        const out = new Map();
        for (let i = 0; i < n; i++) {
          const key = item(depth + 1);
          out.set(key, item(depth + 1));
        }
        return out;
      }
      case 7:
        if (info === 20) return false;
        if (info === 21) return true;
        if (info === 22) return null;
        throw new PasskeyError('malformed');
      default:
        throw new PasskeyError('malformed');
    }
  };
  const value = item(0);
  return { value, end: at };
}

// --- Authenticator data -------------------------------------------------------

export function parseAuthData(bytes) {
  if (bytes.length < 37) throw new PasskeyError('malformed');
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const out = {
    rpIdHash: bytes.slice(0, 32),
    flags: bytes[32],
    signCount: view.getUint32(33),
    credentialId: null,
    publicKey: null,
  };
  if (out.flags & FLAG_ATTESTED_DATA) {
    if (bytes.length < 55) throw new PasskeyError('malformed');
    const idLength = view.getUint16(53);
    if (bytes.length < 55 + idLength) throw new PasskeyError('malformed');
    out.credentialId = bytes.slice(55, 55 + idLength);
    out.publicKey = cborDecode(bytes, 55 + idLength).value;
  }
  return out;
}

// A COSE public key as a JWK Web Crypto imports, with its algorithm.
export function coseToJwk(cose) {
  if (!(cose instanceof Map)) throw new PasskeyError('malformed');
  const alg = cose.get(3);
  if (alg === ES256 && cose.get(1) === 2 && cose.get(-1) === 1) {
    const x = cose.get(-2);
    const y = cose.get(-3);
    if (!(x instanceof Uint8Array) || !(y instanceof Uint8Array) || x.length !== 32 || y.length !== 32) throw new PasskeyError('malformed');
    return { alg, jwk: { kty: 'EC', crv: 'P-256', x: b64u(x), y: b64u(y) } };
  }
  if (alg === RS256 && cose.get(1) === 3) {
    const n = cose.get(-1);
    const e = cose.get(-2);
    if (!(n instanceof Uint8Array) || !(e instanceof Uint8Array)) throw new PasskeyError('malformed');
    return { alg, jwk: { kty: 'RSA', n: b64u(n), e: b64u(e) } };
  }
  throw new PasskeyError('unsupported_algorithm');
}

async function sha256(bytes) {
  return new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
}

function equal(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

// The client data, checked: the ceremony's type, the challenge given, and
// the site's own origin. Returns the challenge, as sent.
function checkClientData(clientDataJSON, type, origin) {
  let data;
  try {
    data = JSON.parse(new TextDecoder().decode(clientDataJSON));
  } catch {
    throw new PasskeyError('malformed');
  }
  if (data.type !== type) throw new PasskeyError('wrong_type');
  if (data.origin !== origin) throw new PasskeyError('wrong_origin');
  if (typeof data.challenge !== 'string') throw new PasskeyError('malformed');
  return data.challenge;
}

// A registration's response, checked: the challenge it answers is returned
// for the caller to match with one it gave, and the passkey to keep.
export async function verifyRegistration({ clientDataJSON, attestationObject }, { origin, rpId }) {
  const challenge = checkClientData(fromB64u(clientDataJSON), 'webauthn.create', origin);
  const attestation = cborDecode(fromB64u(attestationObject)).value;
  if (!(attestation instanceof Map) || !(attestation.get('authData') instanceof Uint8Array)) throw new PasskeyError('malformed');
  const auth = parseAuthData(attestation.get('authData'));
  if (!equal(auth.rpIdHash, await sha256(enc.encode(rpId)))) throw new PasskeyError('wrong_rp');
  if (!(auth.flags & FLAG_USER_PRESENT)) throw new PasskeyError('not_present');
  if (!auth.credentialId || !auth.publicKey) throw new PasskeyError('malformed');
  const { alg, jwk } = coseToJwk(auth.publicKey);
  return { challenge, credentialId: b64u(auth.credentialId), alg, jwk, signCount: auth.signCount };
}

// The challenge a sign-in's response answers, before its passkey is looked up.
export function assertionChallenge(clientDataJSON, origin) {
  return checkClientData(fromB64u(clientDataJSON), 'webauthn.get', origin);
}

// A DER ECDSA signature as Web Crypto takes it: r and s, 32 bytes each.
export function derToRaw(der) {
  if (der[0] !== 0x30) throw new PasskeyError('malformed');
  let at = 2;
  const part = () => {
    if (der[at] !== 0x02) throw new PasskeyError('malformed');
    const n = der[at + 1];
    let bytes = der.slice(at + 2, at + 2 + n);
    at += 2 + n;
    while (bytes.length > 32 && bytes[0] === 0) bytes = bytes.slice(1);
    if (bytes.length > 32) throw new PasskeyError('malformed');
    const out = new Uint8Array(32);
    out.set(bytes, 32 - bytes.length);
    return out;
  };
  const r = part();
  const s = part();
  const raw = new Uint8Array(64);
  raw.set(r);
  raw.set(s, 32);
  return raw;
}

// A sign-in's response, checked against the passkey kept: the relying
// party, the user's presence, the signature over the authenticator data and
// the client data's hash, and a signature count that only goes up (where
// the passkey counts at all). Returns the new count.
export async function verifyAssertion({ clientDataJSON, authenticatorData, signature }, { rpId, jwk, alg, signCount }) {
  const clientData = fromB64u(clientDataJSON);
  const authBytes = fromB64u(authenticatorData);
  const auth = parseAuthData(authBytes);
  if (!equal(auth.rpIdHash, await sha256(enc.encode(rpId)))) throw new PasskeyError('wrong_rp');
  if (!(auth.flags & FLAG_USER_PRESENT)) throw new PasskeyError('not_present');
  const signed = new Uint8Array(authBytes.length + 32);
  signed.set(authBytes);
  signed.set(await sha256(clientData), authBytes.length);
  let ok;
  if (alg === ES256) {
    const key = await crypto.subtle.importKey('jwk', jwk, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
    ok = await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, derToRaw(fromB64u(signature)), signed);
  } else if (alg === RS256) {
    const key = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
    ok = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, fromB64u(signature), signed);
  } else {
    throw new PasskeyError('unsupported_algorithm');
  }
  if (!ok) throw new PasskeyError('bad_signature');
  if (signCount > 0 && auth.signCount > 0 && auth.signCount <= signCount) throw new PasskeyError('cloned');
  return auth.signCount;
}
