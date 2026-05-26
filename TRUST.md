# Trust Model

How a verifier (customer, auditor, partner) can establish confidence that an
ArmoredGate signed artifact is genuine.

## The chain

```
Customer downloads:
    artifact + signature + public-key + sigspec
        from https://get.armoredgate.com/releases/
                            │
                            │ Both files come from the same server.
                            │ If the server is compromised, both are
                            │ replaceable. So we cross-check the public
                            │ key against a different infrastructure.
                            ▼
Customer fetches canonical fingerprint:
    https://raw.githubusercontent.com/karmgate/armoredgate-trust/main/pubkeys/<key-id>.json
                            │
                            │ Hosted on GitHub. Independent of
                            │ armoredgate.com/Bunny CDN/our GCP.
                            │ For an attacker to swap the fingerprint
                            │ here, they would also need to compromise
                            │ GitHub.
                            ▼
                  Confirms public-key fingerprint matches.
                  Now we know the verification key is genuine.
                            │
                            ▼
Customer verifies the signature:
    openssl dgst -sha384 -verify <pem> -signature <sig> <artifact>
                            │
                            │ Verifies a HSM-backed ECDSA P-384
                            │ signature. FIPS-140-3 validated module.
                            ▼
                  "Verified OK" → artifact is genuine.
```

For extra assurance, the customer can cross-check the fingerprint against
two more independent sources (see below).

## Sources of fingerprint truth (in order of strength)

### 1. This GitHub repository (primary)

**URL:** `https://raw.githubusercontent.com/karmgate/armoredgate-trust/main/pubkeys/<key-id>.json`

**Infrastructure:** GitHub (Microsoft-owned, independent of ArmoredGate
hosting).

**Tamper resistance:** Git commit history is immutable once pushed.
Substantive changes to fingerprints require pushing new commits, which appear
in the public Git log. Anyone watching can detect retroactive edits.

**Active:** Commits to this repo are signed with the
ArmoredGate maintainer's PGP key (`7B1FE3B74A4724FF4AC2F475392A960C6822747F`,
Ed25519, hardware-backed via YubiKey 5 NFC). Verifiers should fetch the
maintainer's GPG public key from a public keyserver (`keys.openpgp.org`) and
configure `git` to verify signatures locally:

```bash
gpg --keyserver keys.openpgp.org --recv-keys 7B1FE3B74A4724FF4AC2F475392A960C6822747F
git clone https://github.com/karmgate/armoredgate-trust
cd armoredgate-trust
git log --show-signature
# Expect: "Good signature from Karl Clinger <karl.clinger@armoredgate.com>"
```

### 2. DNS TXT records (secondary)

**Location:** `_trust.armoredgate.com` (TXT records, one per active key)

**Query:**

```bash
dig +short TXT _trust.armoredgate.com
```

**Format:** Each record encodes one active key:

```
v=ag-trust-1; key=image-signing-root-2026-q2; ver=2; algo=ec-p384-sha384; fpr=175951859b9aa7d0e0fd987db20d4c5d9a438a75f82fa4ac4655bbd62b3c26d9; src=https://raw.githubusercontent.com/karmgate/armoredgate-trust/main/pubkeys/image-signing-root-2026-q2.json
```

**Infrastructure:** Bunny DNS (same provider as `armoredgate.com`).
Independent of ArmoredGate's webservers but NOT independent of Bunny.

**Tamper resistance:** DNS is generally world-readable; tampering requires
control of Bunny's DNS servers or the authoritative nameservers for
`armoredgate.com`. Resistant to compromise of `get.armoredgate.com` itself.

**Strengthening (TODO):** Enable DNSSEC on `armoredgate.com` if available
through Bunny. Cross-publish to a second DNS zone on a different provider
(e.g., Cloudflare-hosted `armored.app`).

### 3. PGP-signed `TRUST.txt` (tertiary)

**Location:** [`signatures/TRUST-YYYY-MM-DD.txt.asc`](./signatures/)
(clearsigned plain-text manifest)

**Signing key:** Karl Clinger's hardware-backed PGP key
(`7B1FE3B74A4724FF4AC2F475392A960C6822747F`, Ed25519, YubiKey 5 NFC OpenPGP
applet with UIF Sign=on so every signature requires physical touch). Public
key published in [`keys/karl-clinger.asc`](./keys/karl-clinger.asc) and on
`keys.openpgp.org`.

**Verification:**

```bash
# Fetch Karl's GPG public key from keyservers (independent of this repo)
gpg --keyserver keys.openpgp.org --recv-keys 7B1FE3B74A4724FF4AC2F475392A960C6822747F

# Verify the clearsigned trust manifest
gpg --verify signatures/TRUST-2026-05-14.txt.asc
# Expect: "Good signature from Karl Clinger <karl.clinger@armoredgate.com>"
```

**Tamper resistance:** Even if both `armoredgate-trust` GitHub repo AND
Bunny DNS are compromised, the PGP-signed manifest can only be replaced by
an attacker who also has Karl's private PGP key (which is offline, on a
hardware token, etc.). Strongest chain.

**Strengthening (TODO):** Sign with multiple ArmoredGate team members'
keys (Gary Higman, Kevin Greenhalgh — the Genesis ceremony witnesses) for
multi-party attestation.

## What verifiers SHOULD do

For most use cases, source #1 (GitHub) is sufficient. The bar to compromise
both ArmoredGate hosting and GitHub simultaneously is high enough for
general-purpose distribution.

For high-assurance scenarios (DoD-adjacent partners, security audits,
production deployment of FIPS-attested images):

1. Fetch the canonical fingerprint from **at least two** of the three sources
   above and confirm they match.
2. Verify the GPG signature on the latest `TRUST-YYYY-MM-DD.txt.asc` against
   Karl's GPG key from `keys.openpgp.org`.
3. Watch this repo's commit history for unexpected key rotations or
   additions.

## Key rotation procedure

When a signing key is rotated (next planned: `*-2026-q3` issuance ~3 months
from `*-2026-q2`):

1. New key version is generated in GCP KMS (HSM-backed).
2. New entry is added to `pubkeys/` directory with status `active`.
3. Old entry is updated to status `superseded` with `superseded_at`
   timestamp. **The old fingerprint stays in the repo** so verifiers can
   confirm legacy artifacts still verify against their original key.
4. DNS TXT records updated to include the new key.
5. A new `signatures/TRUST-<date>.txt.asc` is published.
6. Customers are notified via the security mailing list and via this repo's
   Releases page.

## Reporting compromise

If you suspect any of these trust roots is compromised, contact
`security@armoredgate.com` (PGP-encrypted preferred). Do not act on
suspected-compromised keys.

## Open hardening items

- [x] **Enable PGP signing on all commits to this repo** — done 2026-05-26.
      Maintainer key `7B1FE3B74A4724FF4AC2F475392A960C6822747F` configured
      with `commit.gpgsign = true` on the maintenance laptop.
- [ ] Cross-publish DNS TXT records to a second DNS provider
- [ ] Enable DNSSEC on `armoredgate.com`
- [ ] Get a second ArmoredGate team member's GPG key to co-sign trust
      manifests (multi-party attestation)
- [ ] Publish key fingerprints to a Certificate Transparency log or
      sigstore Rekor (voluntary public attestation, separate from key
      publication)
- [ ] Custom org policy constraint on `ag-fed-signing-root-prod` to scope
      `allUsers` IAM bindings to resources tagged `public-api=true`
      (replaces the project-level `allValues: ALLOW` override from the
      Phase 2 licensing work)
