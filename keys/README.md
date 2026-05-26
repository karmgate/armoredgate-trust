# PGP public keys of trust roots

This directory holds ASCII-armored PGP public keys of ArmoredGate personnel
who sign trust manifests (`signatures/TRUST-*.txt.asc`).

Verifiers SHOULD fetch these keys from an independent keyserver (e.g.,
`keys.openpgp.org`) and cross-check the fingerprint against the copy in this
directory. Trusting the copy here without cross-reference is bootstrap-circular
the same way trusting only `get.armoredgate.com` is.

## Published keys

- **`karl-clinger.asc`** — Karl Clinger (primary signer)
  - **Fingerprint:** `7B1FE3B74A4724FF4AC2F475392A960C6822747F`
  - **Algorithm:** Ed25519 (primary, signing/certify), cv25519 (encryption subkey)
  - **Hardware backing:** YubiKey 5 NFC OpenPGP applet, serial `26849524`
  - **Touch policy:** UIF Sign=on (every signature requires physical touch of the YubiKey)
  - **Created:** 2026-05-15
  - **Expires:** 2028-05-14 (2-year cadence; will extend or rotate before then)
  - **Cross-published on:**
    - This repo (file: [`keys/karl-clinger.asc`](./karl-clinger.asc))
    - `keys.openpgp.org` (searchable by email)
    - The clearsigned trust manifest `signatures/TRUST-2026-05-14.txt.asc`
  - **Revocation cert:** generated 2026-05-15, printed + sealed offline in physical safe.
    Not stored online anywhere by design (publishing it would immediately revoke this key).

## Adding a new key

```bash
# Export the public key (NOT the private key)
gpg --armor --export <FPR> > keys/<name>.asc

# Verify the fingerprint matches what you intend to publish
gpg --show-keys keys/<name>.asc

# Commit and push
git add keys/<name>.asc
git commit -m "keys: add <name> PGP public key (fingerprint <short-fpr>)"
git push
```
