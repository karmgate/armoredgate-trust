# armoredgate-trust

**Out-of-band trust source for verifying ArmoredGate signed artifacts.**

This repository is the canonical, infrastructure-independent location where
ArmoredGate publishes the public keys and fingerprints used to sign released
software (Volt CLI binaries, FIPS-attested container images, partner
deliverables).

It lives on GitHub specifically because GitHub's infrastructure is
**independent of ArmoredGate's own hosting** (`armoredgate.com`,
`get.armoredgate.com`, `*.3kb.io`). An attacker who compromises ArmoredGate's
servers cannot also alter the contents of this repo without independently
compromising GitHub.

## Quick start — verify an artifact

For a complete recipe, see [`verify.sh`](./verify.sh).

Given a signed artifact published at `https://get.armoredgate.com/releases/`:

```bash
ARTIFACT=volt-linux-amd64

# 1. Fetch the four published files
BASE=https://get.armoredgate.com/releases
curl -fsSL ${BASE}/${ARTIFACT}                  -o ${ARTIFACT}
curl -fsSL ${BASE}/${ARTIFACT}.sig              -o ${ARTIFACT}.sig.b64
curl -fsSL ${BASE}/${ARTIFACT}.pubkey.pem       -o ${ARTIFACT}.pub.pem
curl -fsSL ${BASE}/${ARTIFACT}.sigspec.txt      -o ${ARTIFACT}.sigspec.txt

# 2. Identify the signing key from sigspec.txt
KEY_ID=$(grep '^signing_key:' ${ARTIFACT}.sigspec.txt | awk '{print $2}' | sed 's|/.*||')

# 3. Fetch the canonical fingerprint from THIS REPO (different infra)
CANONICAL_FP=$(curl -fsSL "https://raw.githubusercontent.com/karmgate/armoredgate-trust/main/pubkeys/${KEY_ID}.json" | jq -r .fingerprint_sha256_der)

# 4. Confirm the pubkey you fetched matches the canonical fingerprint
ACTUAL_FP=$(openssl pkey -in ${ARTIFACT}.pub.pem -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')

if [ "$CANONICAL_FP" != "$ACTUAL_FP" ]; then
  echo "FAIL: pubkey fingerprint does not match canonical source"
  echo "  canonical: $CANONICAL_FP"
  echo "  actual:    $ACTUAL_FP"
  exit 1
fi

# 5. Verify the signature
base64 -d ${ARTIFACT}.sig.b64 > ${ARTIFACT}.sig.bin
openssl dgst -sha384 -verify ${ARTIFACT}.pub.pem -signature ${ARTIFACT}.sig.bin ${ARTIFACT}
# Expected: Verified OK
```

If the canonical fingerprint check passes AND `openssl dgst` reports
`Verified OK`, the artifact is genuinely signed by ArmoredGate.

## Why this matters (the bootstrap problem)

If both the binary AND the public key that verifies it come from the same
server, an attacker who compromises that server can simply replace BOTH
together and verification still passes. You'd be verifying that *the
attacker's binary matches the attacker's key*, which is useless.

The fix is to publish the **fingerprint** of the legitimate public key on a
**different** server. To forge a signed binary that passes the full check,
an attacker now needs to compromise both ArmoredGate's hosting AND GitHub at
the same time — significantly higher bar.

For maximum assurance, fingerprints in this repo are cross-published to
additional independent sources:

1. **This GitHub repo** (`raw.githubusercontent.com/karmgate/armoredgate-trust/main/`)
2. **DNS TXT records** under `_trust.armoredgate.com`
3. **PGP-signed `TRUST.txt`** clearsigned manifest, anchored to ArmoredGate's
   GPG key on public keyservers

See [`TRUST.md`](./TRUST.md) for the trust model details.

## Repository contents

| Path | Purpose |
|---|---|
| `pubkeys/<key-id>.json` | Structured metadata for each active signing key |
| `pubkeys/<key-id>.pem` | PEM-encoded public key |
| `keys/*.asc` | Ascii-armored PGP public keys of trust roots (Karl Clinger etc.) |
| `signatures/TRUST-<date>.txt[.asc]` | Plain + clearsigned trust manifests |
| `TRUST.md` | Trust model documentation |
| `verify.sh` | Reference verification script |

## Active signing keys (as of 2026-05-14)

| Key ID | Algorithm | Use | Fingerprint (SHA-256 of DER pubkey) | Status |
|---|---|---|---|---|
| `image-signing-root-2026-q2/v2` | EC_SIGN_P384_SHA384 (HSM) | Customer-facing artifact signing (binaries, OCI images) | `175951859b9aa7d0e0fd987db20d4c5d9a438a75f82fa4ac4655bbd62b3c26d9` | ACTIVE |
| `license-issuer-2026-q2/v1` | EC_SIGN_P384_SHA384 (HSM) | License JWT signing (license.armored.app issuance) | `e8782f00b335880fe2c4a50f73dc33b4c6cde93b6ef16391d1038713d00bf0c9` | ACTIVE |

Both keys live in GCP KMS (project `ag-fed-signing-root-prod`, keyring
`signing-root-prod-ring`, region `us-central1`), HSM-protected and
FIPS-140-3 validated.

## Reporting trust issues

If you encounter a signature verification failure or suspect any of the
above keys has been compromised, contact `security@armoredgate.com`
immediately and **do not run the affected artifact**.

GPG-encrypted communication preferred — Karl Clinger's PGP key is in
[`keys/karl-clinger.asc`](./keys/karl-clinger.asc) once published; you may
also fetch from `keys.openpgp.org` (cross-reference fingerprint).
