# Clearsigned trust manifests

This directory contains plain-text trust manifests (`TRUST-YYYY-MM-DD.txt`)
and their PGP-clearsigned counterparts (`.asc`).

## How to add a new clearsigned manifest

When publishing a new trust manifest (e.g., after a key rotation):

1. Create or update `TRUST-YYYY-MM-DD.txt` (plain text).
2. Clearsign with the ArmoredGate maintainer's PGP key:

   ```bash
   gpg --clearsign --output TRUST-YYYY-MM-DD.txt.asc TRUST-YYYY-MM-DD.txt
   ```

3. Verify the signature locally before committing:

   ```bash
   gpg --verify TRUST-YYYY-MM-DD.txt.asc
   ```

4. Commit BOTH `.txt` and `.txt.asc`, push to `main`.

## Status

- **`TRUST-2026-05-14.txt`** — plain manifest (committed)
- **`TRUST-2026-05-14.txt.asc`** — clearsigned manifest, **signed 2026-05-26** by Karl Clinger's YubiKey 5 NFC OpenPGP applet (Ed25519 primary key, fingerprint `7B1FE3B74A4724FF4AC2F475392A960C6822747F`, hardware-backed, touch-required for each signature)

All three trust-source legs are now live:

1. **GitHub repo** — this repo, with PGP-signed commits going forward (verify any commit with `git log --show-signature`)
2. **DNS TXT records** — `dig +short TXT _trust.armoredgate.com`
3. **PGP-clearsigned manifest** — `TRUST-2026-05-14.txt.asc` (verify with `gpg --verify` after fetching Karl's pubkey from this repo or from `keys.openpgp.org`)

Cross-checking the pubkey fingerprint against ≥2 of these three sources before trusting a signed artifact is the recommended verification posture for high-assurance use (DoD-adjacent, FIPS compliance reviews).
