# Reference plugins

Sample `.plgw` plugins for the launcher. Each folder holds the source of a package the
launcher can build, sign and install.

| Sample | What it shows |
| --- | --- |
| `hello/` | The smallest possible plugin: declarative settings and a theme file |
| `aurora-ui/` | A native plugin (ABI 2) that renders its own view |
| `pe-controls/` | A native plugin that hooks the in-game touch controls |
| `theme-studio/` | A theme-only plugin with a palette picker |
| `catalog/` | The template of a plugin catalog (`witch-plugins.json`) |
| `pe-buttons/` | A complete published plugin, tracked as a git submodule |

## Building a sample

```sh
python3 scripts/plugins/pack_plugin.py \
  --source examples/plugins/hello \
  --private-key ./keys/private.pem --key-id dev-example \
  --out ./hello-1.0.0.plgw
python3 scripts/plugins/pack_plugin.py --verify ./hello-1.0.0.plgw
```

The packer prints the `artifact_sha256` of the package. A build is only installable after the
Witch registry verified it — see [Publishing](../docs/plugins/publishing.md).

## pe-buttons (submodule)

`pe-buttons` is a real, published plugin: Minecraft PE style touch controller buttons. It is
a git submodule pointing at <https://github.com/Ynnyny/witch-pe-buttons>, so it shows the
full layout of a plugin that other people can install:

- a `witch-plugins.json` catalog, so the launcher offers it under **Available Plugins**
- a signed package published as a GitHub release, pinned by SHA-256 in the catalog
- a stable publisher signing key, which the launcher requires for updates
- the source of the native plugin, its build script and its CI workflow

It is a native plugin, so the launcher grades it **Dangerous** and asks whether the native
code may run inside the launcher process. See the plugin README for the details.

```sh
git submodule update --init examples/plugins/pe-buttons
```
