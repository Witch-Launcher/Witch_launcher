# Security model

## Signatures

Every package is signed with ECDSA P-256 and SHA-256 (`ES256`). The signature is stored in `witch-plugin.sig` and covers the exact bytes of `checksums.json`.

```json
{
  "algorithm": "ES256",
  "keyId": "dev-example",
  "publicKey": "BGRZ...",
  "signature": "MEUCIQ..."
}
```

`publicKey` is base64 of the 65-byte uncompressed P-256 point `04 || X || Y`. `signature` is base64 DER. The private key never ships in the package.

Verification uses the public key embedded in the package. That proves the checksum list was signed by the matching private key. It does not prove who owns the key. Ownership is established by pinning a publisher key or by registry verification.

## Checksums

`checksums.json` maps every payload file to its SHA-256 hash.

- `witch-plugin.json` must be included.
- Every payload file must be listed.
- Extra files are rejected at install, except `checksums.json` and `witch-plugin.sig`. The launcher creates `state.json` after installation; it is not payload.
- `checksums.json` is not listed in itself.
- Symbolic links and non-regular files are rejected.

## Resource limits

The launcher rejects packages larger than 32 MB, packages with more than 2,048 entries, and packages that would expand beyond 128 MB. These limits reduce zip-bomb and disk-exhaustion risk. Per-plugin `state.json` is capped at 1 MB.

## Trust and registry verification

Two decisions are separate:

1. The package is cryptographically valid.
2. The publisher and build are trusted.

A valid package with an unknown key is installable with an `Unverified` warning and a `developerSigned` state. Tapping `Trust this developer key` pins the key ID and public key in local preferences. Pinned keys are accepted without a warning. Registry verification is checked independently and is tied to the package hash and checksum hash.

A registry `verified` result for a different package hash or checksum hash is treated as `Invalid`. Installed plugins are re-checked shortly after launch; an unreachable registry keeps the last known state, while a revoked or rejected result disables the plugin.

Before loading an installed plugin, the launcher re-verifies its signature, signing key pin, checksums, file set, and size limits. A modified plugin is marked `Invalid` and disabled. Enabling a plugin and applying a registry result also run the same integrity check, so a stale verified badge cannot bypass local tampering.

## Open-source policy

The registry only verifies packages that declare an allowlisted open-source license and a public HTTP(S) source-code URL. This is an auditability requirement, not a cryptographic guarantee.

## Safe mode and crash recovery

- Manual safe mode: `SAFE_MODE` in the launcher's hidden data directory. The legacy `POJAV_HOME/SAFE_MODE` path is also checked.
- Runtime marker: `.amethyst/plugins/runtime/<plugin-id>.loading`.
- A failed load removes the marker and increments `crashCount`.
- Two failures enable safe mode automatically.
- Safe mode prevents all plugin entrypoints from loading.

Native plugins run in the launcher process. A native crash can terminate the launcher before recovery code runs. Safe mode reduces repeated startup crashes but is not a sandbox. Loaded dylibs stay resident for the rest of the launcher process; they are never unloaded after plugin initialization.

## Remote installs

`witch://install-plugin?url=...` accepts HTTPS, plus HTTP only for localhost testing. The downloaded package still has to pass the same signature and checksum validation as a local file.

## Recommendations

- Build from source and compare the package hash.
- Pin publisher keys only after reviewing the source.
- Prefer JavaScript and theme plugins over native plugins.
- Revoke or uninstall plugins that fail registry verification.
