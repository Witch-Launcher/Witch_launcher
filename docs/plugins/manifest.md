# Manifest

`witch-plugin.json` is required at the package root.

```json
{
  "id": "com.example.hello",
  "name": "Hello Witch",
  "version": "1.0.0",
  "author": "Example Author",
  "description": "A short description.",
  "details": "Optional longer text.",
  "license": "MIT",
  "source": "https://github.com/example/hello",
  "api": 1,
  "entrypoints": {
    "js": "main.js"
  },
  "ui": {
    "theme": "theme.json"
  },
  "permissions": [],
  "settings": []
}
```

## Required fields

| Field | Rules |
| --- | --- |
| `id` | Lowercase letters, numbers, dot, underscore, or dash. Must match `^[a-z0-9][a-z0-9._-]{1,63}$`. |
| `name` | Non-empty display name. |
| `version` | Numeric components, for example `1.0.0` or `2.1.0-beta.1`. |
| `license` | OSI/SPDX open-source identifier from the allowlist. |
| `source` | Public `http` or `https` source-code URL. |
| `api` | Plugin API version. This build supports `1`. |

## Optional fields

| Field | Purpose |
| --- | --- |
| `author` | Displayed in the install sheet and detail screen. |
| `description` | Short summary shown in the plugin list and detail screen. |
| `details` | Longer description reserved for detail views. |
| `icon` | Safe relative path to a PNG or JPEG image. |
| `banner` | Safe relative path to a banner image. |
| `permissions` | Declared permissions, currently informational. |
| `settings` | Declarative settings schema. |
| `entrypoints` | Runtime entrypoints. |
| `ui` | Theme path or a `{ "theme": "theme.json" }` object. |

All paths must be relative, must stay inside the package, and must not contain `..`, backslashes, or absolute prefixes. Symbolic links are rejected.

## License allowlist

`MIT`, `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `ISC`, `MPL-2.0`, `GPL-2.0-only`, `GPL-2.0-or-later`, `GPL-3.0-only`, `GPL-3.0-or-later`, `LGPL-2.1-only`, `LGPL-2.1-or-later`, `LGPL-3.0-only`, `LGPL-3.0-or-later`, `AGPL-3.0-only`, `AGPL-3.0-or-later`, `EPL-2.0`, `CC0-1.0`, `Unlicense`, `Zlib`.

## Settings schema

`settings` is an array. Supported types are `switch`, `text`, `slider`, and `picker`. Values are stored per plugin in `state.json`.

```json
{
  "key": "accent",
  "type": "picker",
  "label": "Accent color",
  "description": "Applied on the next launch.",
  "default": "#7c5cff",
  "options": [
    { "key": "#7c5cff", "name": "Amethyst" },
    { "key": "#ff5c8a", "name": "Rose" }
  ]
}
```

| Type | Extra fields |
| --- | --- |
| `switch` | `default` boolean. |
| `text` | `default`, optional `placeholder`. |
| `slider` | `default`, `min`, `max`. |
| `picker` | `default`, `options` array. Values may be strings or `{ "key", "name" }` objects. |

`title` is accepted as an alias for `label`.

## Entrypoints

```json
{
  "entrypoints": {
    "js": "main.js",
    "native": "libexample.dylib",
    "java": "example.PluginMain",
    "ui": "ui.json"
  }
}
```

`js` and `native` are executed at launch. Native entrypoints using ABI 2 can register a custom `WitchRootHost` root view controller. `java` is logged but not executed in this build. `ui` is reserved and does not inject layouts.

## Theme files

`ui` may point to a JSON file directly, or use an object form:

```json
{
  "ui": { "theme": "theme.json" }
}
```

```json
{
  "colors": {
    "amethyst_accent_color": "#7c5cff",
    "amethyst_bg_color": "#0b0b12",
    "amethyst_text_color": "#ffffff",
    "amethyst_secondary_text_color": "#b7b7c9"
  }
}
```

A color value may also be an object with `light` and `dark` values.
