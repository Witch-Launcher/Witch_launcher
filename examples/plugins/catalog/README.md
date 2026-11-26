# Plugin catalog template

`witch-plugins.json` is the catalog a GitHub repository publishes. Copy it to the root of your repository, put the `.plgw` files next to it and fill in the real values.

The launcher reads the catalog from the default branch of the repository. Each entry publishes one plugin:

| Field | Meaning |
| --- | --- |
| `id` | Must match the `id` inside `witch-plugin.json`. The launcher refuses a package that does not contain the expected plugin |
| `version` | Compared against the installed version to decide whether an update is offered |
| `package` | Path of the `.plgw` file inside the repository, or an absolute `https` URL |
| `sha256` | SHA-256 of the published `.plgw`. The packer prints it as `artifact_sha256` |
| `name`, `description`, `author`, `license`, `source`, `notes` | Shown in the catalog and in the install sheet |
| `channel` | Free-form label for the publisher |

```sh
# Build and sign the package, then copy it into the repository.
python3 scripts/plugins/pack_plugin.py \
  --source examples/plugins/hello \
  --private-key ./keys/example-private.pem \
  --key-id dev-example \
  --out ./hello-1.0.0.plgw
```

The catalog is a distribution channel, not a trust anchor. A published package still has to pass the signature, checksum and registry checks before the launcher installs it.

See [Plugin catalog](../../docs/plugins/catalog.md).
