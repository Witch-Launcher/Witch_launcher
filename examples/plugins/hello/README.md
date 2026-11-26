# Hello Witch

Minimal example plugin. It logs a greeting, applies an accent color, and ships a theme.

Build and sign it from the repository root:

```sh
python3 scripts/plugins/pack_plugin.py \
  --generate-key ./keys/hello-private.pem \
  --key-id dev-hello

python3 scripts/plugins/pack_plugin.py \
  --source examples/plugins/hello \
  --private-key ./keys/hello-private.pem \
  --key-id dev-hello \
  --out ./hello-1.0.0.plgw

python3 scripts/plugins/pack_plugin.py --verify ./hello-1.0.0.plgw
```

Transfer the `.plgw` file to the device, open the launcher's Plugins screen, and tap `+`.
