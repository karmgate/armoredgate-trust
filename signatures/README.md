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

As of 2026-05-14:

- `TRUST-2026-05-14.txt` — plain manifest (committed)
- `TRUST-2026-05-14.txt.asc` — clearsigned manifest (**NOT YET — pending Karl Clinger's GPG setup**)

The clearsigned file will be added once the maintainer's PGP key is configured.
Until then, the trust chain relies on:

1. GitHub repo immutability (commit history)
2. DNS TXT records at `_trust.armoredgate.com`
3. Plain-text manifest (this file) reviewable in `git log`

These two-of-three sources are sufficient for general assurance; the PGP
layer adds the third leg of defense-in-depth and is recommended for
high-assurance audits (DoD-adjacent, FIPS compliance reviews).
