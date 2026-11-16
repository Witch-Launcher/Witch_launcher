# Risk analysis and sandbox

A valid signature proves that a package is intact, not that it is harmless. The launcher therefore reads every plugin before it runs it, works out **what the plugin is going to execute**, and grades that behaviour.

The analysis is local, deterministic and offline. It never sends the package anywhere.

## Risk levels {#levels}

| Level | Badge | Meaning |
| --- | --- | --- |
| Safe | Green | Nothing was found beyond declarative settings and theme data |
| Warning | Yellow | The plugin asks for more than it needs, or uses patterns that hide what it runs |
| Dangerous | Red | The plugin loads native code into the launcher process, or asks for a permission the sandbox cannot protect |

The badge is shown in the plugin list and on the plugin screen. The analysis itself is listed in the **Analysis** section of the plugin screen: the risk level, the list of things the launcher would run, and every finding.

## What is analysed {#analysis}

### Entrypoints

| Entrypoint | Finding |
| --- | --- |
| `native` | **Dangerous** — the file is loaded into the launcher process with `dlopen` and cannot be isolated |
| `js` | The script is scanned for the patterns below |
| `java` | **Warning** — a Java agent is declared; it is registered but not executed in this build |
| `ui` | **Warning** — a custom root view is declared |

### Permissions

| Permission | Finding |
| --- | --- |
| `settings`, `theme`, `storage`, `logs` | No finding |
| `network`, `http`, `socket`, `download`, `clipboard`, `notification`, `webview` | **Warning** |
| `filesystem`, `shell`, `exec`, `process`, `keychain`, `camera`, `microphone`, `location`, `install`, `native`, `root` | **Dangerous** |
| Anything else | **Warning** — the launcher does not know what it allows |

### Payload

| Payload | Finding |
| --- | --- |
| A compiled binary (`.dylib`, `.so`, `.bundle`, `.exe`, …) | **Dangerous** — a binary the launcher cannot inspect |
| An executable script (`.sh`, `.py`, `.jar`, …) | **Warning** — an extra payload the launcher never runs |
| More than 512 files, or more than 16 MB unpacked | **Warning** |
| More than 1,024 files | **Dangerous** |

### JavaScript patterns

| Pattern | Finding |
| --- | --- |
| `ObjC`, `WebKit`, `PHP`, `importScripts`, `import(` | **Dangerous** — the script reaches for host bridge objects that are not part of the plugin API |
| `eval(`, `new Function(` | **Warning** — the real behaviour is not visible in the file |
| `XMLHttpRequest`, `fetch(`, `WebSocket`, `EventSource`, `sendBeacon` | **Warning** — the script talks to the network on its own |
| `localStorage`, `sessionStorage`, `indexedDB` | **Warning** — web storage APIs have no meaning inside the launcher |

## The sandbox rehearsal {#rehearsal}

The rules above are read from the manifest and from the files. The launcher goes one step further: once the signature and the checksums are verified, the package is **run for a moment inside the sandbox** and the launcher watches what it does.

| What is rehearsed | How |
| --- | --- |
| The JavaScript entrypoint | It runs in its own `JSVirtualMachine` with a recording bridge. The bridge answers every call and writes nothing to the launcher |
| The dangerous globals | `eval`, `Function`, `WebKit`, `ObjC`, `PHP`, the network APIs and the storage APIs are replaced by recorders instead of being removed, so an attempt stays visible |
| A native payload | It cannot be executed safely, not even to find out what it does. Its capabilities are read from the binary instead |

What the rehearsal reports:

| Observation | Grade |
| --- | --- |
| The script reached for `ObjC`, `WebKit` or `PHP` | Dangerous |
| The script tried to use `eval` or `Function` | Warning |
| The script tried to reach the network | Warning |
| The script tried to use web storage | Warning |
| The script never finished, the budget is three seconds | Dangerous |
| The script threw | Warning |
| The script changed the theme at launch | Warning |
| The binary carries the process, keychain, camera or location APIs | Dangerous |
| The binary carries file or network APIs | Warning |

The rehearsal happens during the verification, before the package is installed. Its result is stored with the plugin, so the plugin screen keeps showing what the package did when it was checked: the calls it made, the attempts the sandbox refused and the capabilities its payload carries.

> [!IMPORTANT] The rehearsal runs code from an untrusted package inside the launcher process. The script is isolated in its own virtual machine and only sees a recording bridge, the signature and the checksums are verified before it starts, and it is bounded to three seconds. A script that never returns is abandoned, not waited for.

## Installing a plugin {#install}

| Risk | What the launcher does |
| --- | --- |
| Safe | The package is installed right after it passes the verification. No prompt |
| Warning | The install sheet lists every finding and everything the launcher will run. The user confirms, and the plugin is sandboxed |
| Dangerous | The install sheet is destructive and offers a choice: **Install inside the sandbox** (native code stays blocked) or **Install and allow native code**. A native plugin does nothing without the second choice, so the launcher never picks it on the user's behalf |

In every case the analysis is stored with the plugin, so the badge and the findings stay visible after a restart.

## The sandbox {#sandbox}

A plugin that is not safe runs inside the launcher sandbox. The sandbox is enforced by the runtime, not by a promise in the manifest.

| Rule | Behavior |
| --- | --- |
| Native code is blocked | The `native` entrypoint is never passed to `dlopen`. The plugin stays installed and enabled, but its native part does not run. The plugin screen says so |
| The script is isolated | A sandboxed plugin runs in its own `JSVirtualMachine`, so it cannot reach another plugin's objects |
| Host escape hatches are removed | `eval`, `Function`, `WebKit`, `ObjC`, `PHP` and `importScripts` are deleted from the global object before the script runs |
| Theme changes are refused | `Witch.setThemeColor` and `Witch.reloadTheme` are ignored inside the sandbox |
| The script cannot block the launcher | The script is evaluated on a dedicated queue instead of the main thread, so an endless loop does not freeze the launcher at startup |

The sandbox covers JavaScript and declarative settings. It is not a security boundary for native code — which is exactly why native code is blocked in the first place.

## Turning the sandbox off {#disable}

The plugin screen has a **Sandbox** switch. Turning it off asks for a confirmation, and the confirmation is marked destructive for a plugin that is graded dangerous.

Disabling the sandbox is the only way to let a sandboxed plugin load native code. Do it only for a plugin you built yourself or whose source you have read.

> [!IMPORTANT] The sandbox reduces the blast radius of a plugin. It does not make an unknown plugin safe, and it does not replace the registry verification. A plugin that is graded dangerous is dangerous whether it runs sandboxed or not — the badge says so on purpose.

## Recommendations {#recommendations}

- Read the analysis before you install anything that is not green.
- Keep the sandbox on unless you have a reason to turn it off.
- Prefer JavaScript and theme plugins over native plugins.
- Revoke or uninstall plugins that fail registry verification.
