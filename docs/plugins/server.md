# Registry API

Base URL: `https://witch-worker.vvvuduyanh2012.workers.dev`

The launcher reads this base from **Settings → Witch base URL** (`witch.proxy_base_url`). Registry verification is skipped when that setting is empty.

## Public routes

### Verify a build

```http
GET /v1/plugins/verify?id=com.example.hello&version=1.0.0&checksumsSha256=<hex>&artifactSha256=<hex>&keyId=dev-example
```

All parameters except `id` are optional. If `version` is omitted, the most recently updated submission is checked. If a checksum or package hash is supplied and does not match the verified row, the result is `invalid`.

```json
{
  "ok": true,
  "verified": true,
  "status": "verified",
  "verifiedAt": "2026-10-31T00:00:00.000Z",
  "plugin": {
    "id": "com.example.hello",
    "name": "Hello Witch",
    "version": "1.0.0",
    "license": "MIT",
    "sourceUrl": "https://github.com/example/hello",
    "artifactSha256": "...",
    "checksumsSha256": "...",
    "publisherKeyId": "dev-example",
    "publicKey": "...",
    "status": "verified"
  }
}
```

Possible statuses: `verified`, `unverified`, `pending`, `rejected`, `revoked`, `invalid`, `unavailable`.

### List verified plugins

```http
GET /v1/plugins/list?limit=50
```

Only `verified`, non-revoked rows are returned.

### Submit a build

```http
POST /v1/plugins/submit
Content-Type: application/json
```

Required fields: `pluginId`, `version`, `name`, `license`, `sourceUrl`, `artifactSha256`, `checksumsSha256`, `publicKey`, `publisherKeyId`.

Optional fields: `summary`, `author`, `permissions`, `manifest`.

The license must be allowlisted and `sourceUrl` must be HTTP(S). The server computes no hashes; it stores the publisher-supplied values for review.

## Admin routes

All plugin admin routes require `X-Admin-Key`. The key is `PLUGIN_ADMIN_KEY`, falling back to `ADMIN_PAGE_KEY`. If neither is configured, the routes return `503` instead of running unauthenticated.

| Method | Path | Body |
| --- | --- | --- |
| `GET` | `/admin/plugins?status=pending&limit=100` | None |
| `POST` | `/admin/plugins/:id/verify` | `{ "version", "notes"? }` plus optional metadata |
| `POST` | `/admin/plugins/:id/reject` | `{ "version", "notes"? }` |
| `POST` | `/admin/plugins/:id/revoke` | `{ "version", "notes"? }` |

`verify` performs the full open-source and package metadata validation before setting `status = verified`. `revoke` sets `revoked_at`; the verifier reports `revoked` and the launcher disables the plugin.

## Database

`007_plugin_registry.sql` creates:

- `plugin_submissions`: one row per `(plugin_id, version)`, with artifact and checksum hashes, publisher key, manifest, review status, and timestamps.
- `plugin_audit_log`: append-only actions for submitted, verified, rejected, and revoked events.

Both tables enable row-level security and are accessed with the service role from the worker.

## Environment

| Variable | Purpose |
| --- | --- |
| `SUPABASE_URL` | Supabase project URL. |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-side database access. |
| `PLUGIN_ADMIN_KEY` | Plugin admin key. |
| `ADMIN_PAGE_KEY` | Existing admin key and plugin admin fallback. |

If Supabase is not configured, `/v1/plugins/verify` returns `status: unavailable`, `/v1/plugins/list` returns an empty list, and submission/admin routes return an error.
