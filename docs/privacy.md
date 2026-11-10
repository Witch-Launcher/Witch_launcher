# Witch Launcher — Privacy Policy

Witch Launcher is a community, open-source (GPL-3.0) launcher for Minecraft: Java Edition on iPhone and iPad.

## Data we collect

**None.** Witch Launcher does not collect, store, or transmit any personal data about you. There is no analytics, no advertising ID, no fingerprinting, and no user profiling.

## Local-only access

Everything the launcher touches stays on your device:

- Game versions, mods, worlds, shaders and plugin packages (`.plgw`)
- Settings (`plugins.json`, `state.json`) and launch logs
- Java runtimes and LWJGL downloads

Downloads from Modrinth, CurseForge, GitHub and the Witch registry happen only when you trigger them. Authentication with Microsoft, Ely.by or demo accounts uses the service's own web flow — your password is never seen or stored by Witch Launcher.

## Logs

The launch log is written to the launcher's app directory on your device and is never uploaded. If you file a bug report, attaching the log is optional — remove session tokens before sharing.

## Plugins

Signed `.plgw` plugins can run JavaScript or native code. JavaScript runs in a restricted context with only the `Witch` bridge object. Native plugins run unsandboxed in the launcher process — install only code you trust and can rebuild from its published source.

Plugin verification state (unverified / verified / revoked / invalid) is checked against the Witch registry. The registry stores only publisher-supplied hashes and keys — not your personal data.

## Children

No account is required for local play, so no child's data is collected by the launcher.

## Your rights

Because we do not collect data, there is nothing to access, export or delete on our side. All your data lives on your device under your control.

## Contact

Open an issue on the [Witch Launcher GitHub repository](https://github.com/Witch-Launcher/Witch_launcher).

---

*Not affiliated with Mojang Studios or Microsoft. Does not ship game files or certificates.*
