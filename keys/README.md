# PGP public keys of trust roots

This directory holds ASCII-armored PGP public keys of ArmoredGate personnel
who sign trust manifests (`signatures/TRUST-*.txt.asc`).

Verifiers SHOULD fetch these keys from an independent keyserver (e.g.,
`keys.openpgp.org`) and cross-check the fingerprint against the copy in this
directory. Trusting the copy here without cross-reference is bootstrap-circular
the same way trusting only `get.armoredgate.com` is.

## Expected keys

- `karl-clinger.asc` — Karl Clinger (CEO / primary signer)
  - **NOT YET PUBLISHED** — pending GPG key setup.
  - When added, the fingerprint will be cross-published in:
    - This file (this README)
    - `keys.openpgp.org`
    - The `TRUST-YYYY-MM-DD.txt` manifest itself
    - Karl's personal website (TBD)

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
