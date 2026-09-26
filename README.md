<div align="center">

# unfckd-lite

**Free resource scanner for FiveM & RedM.**
Finds missing dependencies, broken manifests, load-order problems and resource conflicts.
Works with every framework.

[![License: GPL v3](https://img.shields.io/badge/license-GPL--3.0-FF3B5C)](LICENSE)
[![Discord](https://img.shields.io/badge/discord-join-7C5CFF?logo=discord&logoColor=white)](https://discord.gg/FWhmYd29DP)
[![Latest release](https://img.shields.io/github/v/release/unfckd/unfckd-lite?color=3DDC97)](../../releases)

[Website](https://unfckd.dev) · [Discord](https://discord.gg/FWhmYd29DP) · [Report a bug](../../issues)

</div>

![unfckd-lite scan output]([screenshot path])

## Why

"Why won't my server start?" usually comes down to the same few problems: a missing dependency, a broken `fxmanifest.lua`, resources started in the wrong order, or two scripts fighting over the same job. unfckd-lite finds them for you in seconds, so you can stop digging through console spam.

## What it looks like

```powershell
[unfckd-lite] Scanning 184 resources...

  ✖ MISSING DEPENDENCY
    qb-garages → requires 'qb-vehiclekeys' (not installed)

  ✖ LOAD ORDER
    ox_inventory is started before ox_lib
    → move 'ensure ox_lib' above 'ensure ox_inventory' in server.cfg

  ⚠ CONFLICT
    ox_target and qb-target are both running

  ⚠ MANIFEST
    old-hud uses the deprecated __resource.lua

  ✔ 180 resources OK

[unfckd-lite] 2 errors · 2 warnings · scanned in 0.4s
[unfckd-lite] unfckd-lite by Unfckd - unfckd.dev
```

## Features

- **Missing dependencies:** resources that depend on something that isn't installed or started
- **Broken manifests:** invalid, outdated or incomplete `fxmanifest.lua` files
- **Load-order problems:** resources started before the things they depend on
- **Conflicts:** duplicate resources and overlapping systems, like two inventories or two target scripts
- **Clean report:** color-coded console output, with optional export to a file

Works with ESX, QBCore, Qbox, ox_core, ND, vRP, RedM frameworks and standalone servers.

## Privacy

unfckd-lite runs entirely on your server. It makes **no network requests**, needs **no account** and sends **no data** anywhere. Don't take our word for it: the full source is right here.

## Installation

1. Download the latest release from [Releases](../../releases)
2. Extract it into your `resources` folder, keeping the folder name `unfckd-lite`
3. Add this to your `server.cfg`, ideally near the top:

   ```cfg
   ensure unfckd-lite
   ```

4. Start your server and check the console for the report

## Usage

The scan runs automatically when the server starts. To run it again at any time, type this in the server console or txAdmin:

```powershell
unfckd scan
```

[Add other commands here, e.g. `unfckd export` to save the report to the `reports/` folder.]

## Configuration

[Describe the config file and options once they're final.]

## Lite vs. Unfckd

unfckd-lite tells you **what's broken right now**. The full Unfckd dashboard tells you **what broke, when, why, and how to fix it**, across all your servers.

|                                                        | unfckd-lite |             Unfckd              |
| ------------------------------------------------------ | :---------: | :-----------------------------: |
| Dependency, manifest, load-order and conflict scanning |     ✅      |               ✅                |
| Console report                                         |     ✅      |               ✅                |
| Web dashboard                                          |             |               ✅                |
| Automatic Error Catcher                                |             |               ✅                |
| Scan history over time                                 |             |               ✅                |
| Auto-fix suggestions                                   |             |               ✅                |
| Performance profiling                                  |             |               ✅                |
| Alerts when an update breaks something                 |             |               ✅                |
| Multi-server support                                   |             |               ✅                |
| Priority support                                       |             |               ✅                |
| Price                                                  |    Free     | [See plans](https://unfckd.dev) |

> [!TIP]
> Already using unfckd-lite? Your setup carries over. Link your server on [unfckd.dev](https://unfckd.dev) and pick up where the console report leaves off.

## Need help?

Open a post in `#help` on our [Discord](https://discord.gg/FWhmYd29DP). Include your framework, server artifact version and the full scan output.

## License

unfckd-lite is licensed under the [GNU GPL v3.0](LICENSE) with additional terms, see [NOTICE](NOTICE). In short: use it, modify it and share it freely, but keep the credits, mark modified versions, and don't use the Unfckd name for forks.
