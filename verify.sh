#!/usr/bin/env bash
# verify.sh — full end-to-end verification of an ArmoredGate signed artifact.
#
# Cross-checks the public key fingerprint against THIS REPO (different
# infrastructure from get.armoredgate.com) before verifying the signature.
#
# Usage: ./verify.sh <artifact-name>
#   e.g. ./verify.sh volt-linux-amd64
#
# Requires: bash, curl, openssl 1.1+, jq, sha256sum, base64.
set -euo pipefail

ARTIFACT="${1:-}"
if [ -z "$ARTIFACT" ]; then
    echo "Usage: $0 <artifact-name>" >&2
    echo "  e.g. $0 volt-linux-amd64" >&2
    exit 2
fi

BASE="${ARMOREDGATE_RELEASES_BASE:-https://get.armoredgate.com/releases}"
TRUST_BASE="${ARMOREDGATE_TRUST_BASE:-https://raw.githubusercontent.com/karmgate/armoredgate-trust/main}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

say() { printf '  %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf '✓ %s\n' "$*"; }

echo "=== fetching signed artifact + sidecars from $BASE ==="
for ext in "" .sig .pubkey.pem .sigspec.txt; do
    target="${ARTIFACT}${ext}"
    url="${BASE}/${target}"
    curl -fsSL "$url" -o "$target" || fail "could not fetch $url"
    say "got $target ($(wc -c < "$target") bytes)"
done

echo ""
echo "=== identifying signing key from sigspec.txt ==="
KEY_ID=$(grep '^signing_key:' "${ARTIFACT}.sigspec.txt" | awk '{print $2}' | sed 's|/.*||')
[ -n "$KEY_ID" ] || fail "could not parse signing key from sigspec.txt"
say "signing key: $KEY_ID"

EXPECTED_FP=$(grep '^pubkey_fingerprint_sha256:' "${ARTIFACT}.sigspec.txt" | awk '{print $2}')
[ -n "$EXPECTED_FP" ] || fail "could not parse expected fingerprint from sigspec.txt"
say "sigspec fingerprint:  $EXPECTED_FP"

echo ""
echo "=== fetching CANONICAL fingerprint from $TRUST_BASE ==="
TRUST_URL="${TRUST_BASE}/pubkeys/${KEY_ID}.json"
curl -fsSL "$TRUST_URL" -o trust.json || fail "could not fetch canonical trust JSON at $TRUST_URL"
CANONICAL_FP=$(jq -r '.fingerprint_sha256_der' trust.json)
[ -n "$CANONICAL_FP" ] && [ "$CANONICAL_FP" != "null" ] || fail "could not parse fingerprint from canonical trust JSON"
say "canonical fingerprint: $CANONICAL_FP"

if [ "$EXPECTED_FP" != "$CANONICAL_FP" ]; then
    fail "sigspec fingerprint does NOT match canonical (someone tampered with one of the sources!)"
fi
ok "sigspec fingerprint matches canonical"

echo ""
echo "=== confirming the .pubkey.pem matches that fingerprint ==="
ACTUAL_FP=$(openssl pkey -in "${ARTIFACT}.pubkey.pem" -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
say "downloaded pubkey fingerprint: $ACTUAL_FP"
if [ "$ACTUAL_FP" != "$CANONICAL_FP" ]; then
    fail ".pubkey.pem fingerprint does NOT match canonical"
fi
ok "downloaded pubkey matches canonical fingerprint"

echo ""
echo "=== verifying signature ==="
base64 -d "${ARTIFACT}.sig" > "${ARTIFACT}.sig.bin"
if openssl dgst -sha384 -verify "${ARTIFACT}.pubkey.pem" \
       -signature "${ARTIFACT}.sig.bin" \
       "${ARTIFACT}" >/dev/null 2>&1; then
    ok "signature verifies"
else
    fail "openssl dgst -sha384 -verify returned a non-zero status (signature invalid)"
fi

echo ""
echo "=== artifact SHA-256 cross-check ==="
ACTUAL_SHA=$(sha256sum "$ARTIFACT" | awk '{print $1}')
EXPECTED_SHA=$(grep '^binary_sha256:' "${ARTIFACT}.sigspec.txt" | awk '{print $2}')
say "computed:  $ACTUAL_SHA"
say "expected:  $EXPECTED_SHA"
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
    fail "binary sha256 does not match sigspec (artifact may be corrupted in transit)"
fi
ok "binary sha256 matches sigspec"

echo ""
echo "✓✓✓ all checks passed — '$ARTIFACT' is genuinely signed by ArmoredGate ✓✓✓"
