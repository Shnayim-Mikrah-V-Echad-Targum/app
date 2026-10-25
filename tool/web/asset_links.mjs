#!/usr/bin/env node
// Writes the site's Digital Asset Links, .well-known/assetlinks.json, for the
// Android web app: the SHA-256 fingerprint of the certificate that signed each
// APK given, so every published APK, whatever its key, may open the site full
// screen. CI's site job (ci.yml, site-web) runs it on the published releases'
// APKs:
//
//   node tool/web/asset_links.mjs build/web a.apk b.apk
//
// The certificate is read from the APK's v2 or v3 signature block: the APKs
// (tool/android_twa) have no v1 JAR signature, which keytool -printcert reads.

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const PACKAGE = 'org.shnayimmikrah.web';

const SIGNATURE_SCHEMES = [0x7109871a, 0xf05368c0]; // v2, v3

/// The SHA-256 fingerprints (AB:CD:…) of the certificates that signed [apk],
/// a Buffer.
export function certificateFingerprints(apk) {
  const eocd = apk.lastIndexOf(Buffer.from('PK\x05\x06', 'latin1'));
  if (eocd < 0) throw new Error('not an APK: no end of central directory');
  const centralDirectory = apk.readUInt32LE(eocd + 16);
  if (apk.toString('latin1', centralDirectory - 16, centralDirectory) !== 'APK Sig Block 42') {
    throw new Error('the APK has no v2 or v3 signature block');
  }
  const size = Number(apk.readBigUInt64LE(centralDirectory - 24));
  const pairs = apk.subarray(centralDirectory - size, centralDirectory - 24);
  // A sequence of values, each prefixed with its length as a uint32.
  const sequence = (buffer) => {
    const items = [];
    for (let i = 0; i < buffer.length; ) {
      const length = buffer.readUInt32LE(i);
      items.push(buffer.subarray(i + 4, i + 4 + length));
      i += 4 + length;
    }
    return items;
  };
  const fingerprints = new Set();
  for (let i = 0; i < pairs.length; ) {
    const length = Number(pairs.readBigUInt64LE(i));
    const id = pairs.readUInt32LE(i + 8);
    if (SIGNATURE_SCHEMES.includes(id)) {
      const [signers] = sequence(pairs.subarray(i + 12, i + 8 + length));
      for (const signer of sequence(signers)) {
        // A signer's signed data: its digests, then its certificates.
        const [signedData] = sequence(signer);
        const [, certificates] = sequence(signedData);
        const [certificate] = sequence(certificates);
        const hex = createHash('sha256').update(certificate).digest('hex').toUpperCase();
        fingerprints.add(hex.match(/../g).join(':'));
      }
    }
    i += 8 + length;
  }
  if (fingerprints.size === 0) throw new Error('the APK has no v2 or v3 signer');
  return [...fingerprints];
}

export function assetLinks(fingerprints) {
  return [
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: { namespace: 'android_app', package_name: PACKAGE, sha256_cert_fingerprints: fingerprints },
    },
  ];
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [outDir, ...apks] = process.argv.slice(2);
  if (!outDir) {
    console.error('asset_links: usage: asset_links.mjs <web build> <apk>…');
    process.exit(1);
  }
  if (apks.length === 0) {
    console.log('asset_links: no APKs given, so no assetlinks.json');
    process.exit(0);
  }
  try {
    const fingerprints = [...new Set(apks.flatMap((apk) => certificateFingerprints(readFileSync(apk))))];
    const dir = join(resolve(outDir), '.well-known');
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, 'assetlinks.json'), `${JSON.stringify(assetLinks(fingerprints), null, 2)}\n`);
    console.log(`Wrote .well-known/assetlinks.json with ${fingerprints.length} fingerprint(s):\n${fingerprints.join('\n')}`);
  } catch (e) {
    console.error(`asset_links: ${e.message}`);
    process.exit(1);
  }
}
