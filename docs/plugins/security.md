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

## Remote installs

`witch://install-plugin?url=...` accepts HTTPS, plus HTTP only for localhost testing. The downloaded package still has to pass the same signature and checksum validation as a local file.

## GitHub catalog installs

A plugin can also be installed or updated from a GitHub repository that publishes a catalog. The repository is validated first — it must exist, be public, not be archived and match the configured `owner/repo`. The catalog entry pins the package by SHA-256, and the download is rejected when the hash does not match. After that the package goes through the same signature, checksum and registry checks as a local file.

The catalog is a distribution channel, never a trust anchor: it can publish a package, but it cannot make an unverified package installable.

## Behaviour risk

Signature and checksum answer *is the package intact*. The risk analysis answers *what does the package do*. The launcher reads the manifest and the payload of every package before it is installed and grades it:

| Level | Examples |
| --- | --- |
| Safe | Declarative settings and a theme file only |
| Warning | A `java` entrypoint, a network API in the script, `eval(`, an unknown permission, a large payload |
| Dangerous | A `native` entrypoint, a compiled binary in the package, a permission such as `filesystem`, `shell` or `keychain`, a script that reaches for `ObjC` or `WebKit` |

A plugin that is not Safe is installed only after the user reviewed the findings, and a dangerous plugin needs a **Force Install** confirmation. The full rule set is in [Risk analysis and sandbox](risk.md).

### The sandbox rehearsal

The grade is not only read, it is measured. After the signature and the checksums are verified, the package is run for a moment inside the sandbox and the launcher watches it:

- The JavaScript entrypoint runs in a private `JSVirtualMachine` with a recording bridge. The bridge answers every call and writes nothing to the launcher.
- `eval`, `Function`, `WebKit`, `ObjC`, `PHP`, the network APIs and the storage APIs are replaced by recorders, so an attempt is reported instead of silently failing.
- The script is bounded to three seconds. A script that never returns is abandoned.
- A native payload is never executed. Its capabilities are read from the binary instead, which is how the process, keychain, camera and location APIs are found.

The observations are merged into the grade, so a package that behaves badly while it is verified ends up in the same red badge as a package that merely looks bad. The result is stored with the plugin and shown on the plugin screen.

> [!IMPORTANT] The rehearsal executes code from an untrusted package inside the launcher process. It is bounded, isolated and only reachable through a recording bridge, but it is still untrusted code — the signature and the checksums are verified before it starts.

## Sandbox

A plugin that is graded Warning or Dangerous runs inside the launcher sandbox:

- Native code is never loaded — the `native` entrypoint is not passed to `dlopen`.
- The script runs in its own `JSVirtualMachine`, isolated from every other plugin.
- `eval`, `Function`, `WebKit`, `ObjC`, `PHP` and `importScripts` are removed from the global object before the script runs.
- `Witch.setThemeColor` and `Witch.reloadTheme` are refused.
- The script is evaluated on a dedicated queue, so an endless loop cannot freeze the launcher at startup.

The sandbox is enforced by the runtime. It can be lifted from the plugin screen, and for a dangerous plugin the confirmation is destructive.

> [!IMPORTANT] The sandbox limits the damage a plugin can do; it does not make an unknown plugin trustworthy. Native code is the part the sandbox cannot contain, which is why it is blocked rather than isolated.

## Safe mode and crash recovery

- Manual safe mode: `SAFE_MODE` in the launcher's hidden data directory. The legacy `POJAV_HOME/SAFE_MODE` path is also checked.
- Runtime marker: `.amethyst/plugins/runtime/<plugin-id>.loading`.
- A failed load removes the marker and increments `crashCount`.
- Two failures enable safe mode automatically.
- Safe mode prevents all plugin entrypoints from loading.

Native plugins run in the launcher process. A native crash can terminate the launcher before recovery code runs. Safe mode reduces repeated startup crashes but is not a sandbox. Loaded dylibs stay resident for the rest of the launcher process; they are never unloaded after plugin initialization.

## Recommendations

- Build from source and compare the package hash.
- Pin publisher keys only after reviewing the source.
- Prefer JavaScript and theme plugins over native plugins.
- Read the risk analysis before installing anything that is not green.
- Keep the sandbox on unless you have a reason to turn it off.
- Revoke or uninstall plugins that fail registry verification.
