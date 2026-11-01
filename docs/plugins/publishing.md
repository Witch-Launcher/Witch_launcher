# Publishing

## 1. Create a key

```sh
python3 scripts/plugins/pack_plugin.py \
  --generate-key ./keys/example-private.pem \
  --key-id dev-example
```

Keep the private key offline. The command prints the base64 public key and derived key ID.

## 2. Prepare the package

The source directory must contain `witch-plugin.json` at its root. Every referenced entrypoint, icon, banner, and theme file must exist.

```sh
python3 scripts/plugins/pack_plugin.py \
  --source examples/plugins/hello \
  --private-key ./keys/example-private.pem \
  --key-id dev-example \
  --out ./hello-1.0.0.plgw
```

The packer writes deterministic checksums, signs `checksums.json`, and prints:

- `artifact_sha256`: SHA-256 of the final `.plgw` file.
- `checksums_sha256`: SHA-256 of the signed `checksums.json`.
- `public_key` and `key_id` for registry submission.

## 2b. Official launcher key

For builds signed by the Witch project itself, generate a separate offline P-256 key and set:

```c
#define WITCH_PLUGIN_OFFICIAL_KEY_ID @"witch-official-2026"
#define WITCH_PLUGIN_OFFICIAL_PUBLIC_KEY @"BGRZ..."
```

The public key must be the same base64 65-byte point printed by the packer. Keep the private key in protected CI storage, never in the repository. Self-signed developer packages remain installable; only the official key is trusted without a warning.

## 3. Verify locally

```sh
python3 scripts/plugins/pack_plugin.py --verify ./hello-1.0.0.plgw
```

## 4. Submit to the registry

```sh
curl -X POST https://witch-worker.vvvuduyanh2012.workers.dev/v1/plugins/submit \
  -H 'Content-Type: application/json' \
  -d '{
    "pluginId": "com.witch.example.hello",
    "version": "1.0.0",
    "name": "Hello Witch",
    "summary": "Example plugin",
    "author": "Witch Examples",
    "license": "MIT",
    "sourceUrl": "https://github.com/example/witch-hello-plugin",
    "artifactSha256": "b536...",
    "checksumsSha256": "efda...",
    "publicKey": "BGRZ...",
    "publisherKeyId": "dev-example",
    "permissions": [],
    "manifest": {}
  }'
```

Submissions stay `pending` until an administrator verifies or rejects them. A verified version cannot be overwritten by a later public submission; publish a new version instead.

## 5. Admin review

Admin routes require `X-Admin-Key`. The key is `PLUGIN_ADMIN_KEY`, falling back to `ADMIN_PAGE_KEY` when unset. If neither key is configured, plugin admin routes return `503`.

```sh
curl -H 'X-Admin-Key: ...' \
  'https://witch-worker.vvvuduyanh2012.workers.dev/admin/plugins?status=pending'
```

```sh
curl -X POST \
  -H 'X-Admin-Key: ...' \
  -H 'Content-Type: application/json' \
  'https://witch-worker.vvvuduyanh2012.workers.dev/admin/plugins/com.witch.example.hello/verify' \
  -d '{"version":"1.0.0","notes":"Source and license reviewed"}'
```

Use `/reject` and `/revoke` with the same body shape. Revoked builds are disabled by the launcher on the next verification pass.

## 6. Registry checks

Before verification, confirm:

- The source URL is public and matches the submitted build.
- The license is allowlisted.
- The version is new and not a replacement of a verified build.
- `artifactSha256`, `checksumsSha256`, `publicKey`, and `publisherKeyId` match the package.
- No native plugin permissions or behavior are undocumented.

## Deployment

Apply `worker/supabase/migrations/007_plugin_registry.sql` to the Supabase project. Set `PLUGIN_ADMIN_KEY` with `wrangler secret put` or the hosting dashboard. Deploy both entry points if both are used:

- Cloudflare Worker: `worker/src/worker.js`
- Express server: `worker/src/index.js` with `worker/src/routes/plugins.js`

Public registry routes are exempt from bearer and HMAC authentication, but remain subject to global rate limiting.
