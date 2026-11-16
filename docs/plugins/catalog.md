# Plugin catalog

The launcher can install and update plugins straight from a GitHub repository. A valid repository is the only thing that has to exist: the launcher reads a catalog file from it, resolves the packages and pins every download by hash.

## Repository requirements {#repository}

The configured repository is validated before a single byte of a package is downloaded.

| Requirement | Why |
| --- | --- |
| The repository exists | A wrong repository name must fail loudly, not silently install nothing |
| The repository is public | A private repository cannot be audited by the user |
| The repository is not archived or disabled | An archived repository is frozen and can no longer be trusted to publish updates |
| `full_name` matches the configured `owner/repo` | A redirect or a renamed repository must not silently serve different content |
| The default branch contains the catalog file | The catalog is the only entry point into the repository |

The repository is configured in **Settings → Network → Plugin catalog repository** (`witch.plugins.repo`, `owner/repo`). The default is `Witch-Launcher/Witch_plugin_catalog`. The catalog file name can be changed with `witch.plugins.catalog_file` (default `witch-plugins.json`).

A plugin repository can serve as its own catalog. [`examples/plugins/pe-buttons`](https://github.com/Ynnyny/witch-pe-buttons) does exactly that: pointing the setting at `Ynnyny/witch-pe-buttons` makes PE Buttons appear under **Available Plugins**.

## Catalog file {#format}

```json
{
  "version": 1,
  "plugins": [
    {
      "id": "com.witch.aurora-ui",
      "name": "Aurora UI",
      "version": "1.2.0",
      "description": "Extra theme presets for the launcher",
      "author": "Witch Examples",
      "license": "MIT",
      "source": "https://github.com/owner/repo",
      "package": "packages/aurora-ui-1.2.0.plgw",
      "sha256": "b5361f0f9a9b0e4f2f2a1c0d9e8b7a6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b",
      "channel": "stable",
      "notes": "Adds two more presets"
    }
  ]
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | Yes | Must match the `id` inside `witch-plugin.json`. Entries without an id are skipped |
| `version` | Yes | Compared against the installed version to decide whether an update exists |
| `package` | Yes | Path of the `.plgw` file inside the repository, or an absolute `https` URL |
| `sha256` | Yes | SHA-256 of the published `.plgw` file. The launcher refuses a package whose hash does not match |
| `name` | No | Shown in the catalog list. Falls back to the id |
| `description`, `author`, `license`, `source`, `notes` | No | Shown in the catalog and in the install sheet |
| `channel` | No | Free-form channel label for the publisher |

Entries that miss an id, a version, a package path or a valid hash are ignored instead of failing the whole catalog.

## Update flow {#flow}

1. **Validate the repository.** GitHub confirms that it exists, is public and is not archived.
2. **Read the catalog.** `witch-plugins.json` is fetched from the default branch.
3. **Compare versions.** An entry whose version is newer than the installed one is offered as an update.
4. **Download the package.** Only `https` is accepted and the download is capped at 32 MB.
5. **Pin the download.** The SHA-256 of the downloaded file must equal the `sha256` from the catalog. A swapped file is rejected before anything is unpacked.
6. **Verify the package locally.** The ES256 signature, the checksum manifest, the file set and the size limits are checked exactly as for a local file.
7. **Analyse the risk.** The launcher works out what the plugin is going to execute — see [Risk analysis and sandbox](risk.md).
8. **Ask the registry.** Only a build the registry verified for this exact hash is installable.
9. **Install.** A plugin without findings is installed right away. A plugin that needs attention or is dangerous is shown first, with everything it is going to do, and the user decides.

## Updating an installed plugin {#update}

An update replaces the plugin directory but keeps the user facing configuration: the settings, the feature flags and the enabled state of the previous build are carried over. The previous install is moved aside while the new one is put in place and is restored if anything fails, so a broken update never leaves a half installed plugin behind.

The risk analysis runs again for the new build. A plugin that becomes dangerous with the update is sandboxed by default even if the old version was not.

## A published example {#example}

[`examples/plugins/pe-buttons`](https://github.com/Ynnyny/witch-pe-buttons) is a complete
catalog repository: it publishes a native plugin as a GitHub release, pins the download by
SHA-256 in `witch-plugins.json` and keeps a stable publisher key so updates are accepted.
It is tracked as a git submodule of the launcher repository, so it doubles as a reference
layout.

## Publishing a catalog {#publishing}

1. Build and sign the package as described in [Publishing](publishing.md).
2. Copy the `.plgw` file into the repository, for example under `packages/`.
3. Add an entry to `witch-plugins.json` with the id, the version and the SHA-256 that the packer printed.
4. Commit and push. The launcher picks the catalog up on the next refresh.

The catalog is a convenience and a distribution channel, never a trust anchor on its own. A catalog entry can only publish a package that already passes the signature, checksum and registry checks.

> [!NOTE] The ECDSA signature is randomized, so every packed `.plgw` differs byte for byte. Publish the exact file you attach to the release and put the SHA-256 of that very file into the catalog.
