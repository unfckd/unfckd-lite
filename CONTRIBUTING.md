# Contributing to unfckd-lite

Thanks for wanting to help make broken servers a little less broken! This guide covers how to report problems, suggest ideas and send code.

## Ways to contribute

- **Report a bug:** open a [bug report](../../issues/new/choose) with your full scan output
- **Suggest a check or feature:** open a [feature request](../../issues/new/choose), or post it in `#feature-requests` on our [Discord](https://discord.gg/FWhmYd29DP)
- **Improve detection:** found a conflict or broken setup that unfckd-lite misses? Real-world examples are the most valuable contribution there is
- **Send code:** fix a bug or add a check through a pull request

For security issues, don't open a public issue. Follow [SECURITY.md](SECURITY.md) instead.

## Before you start coding

- **Small fixes** (typos, clear bugs, small detection tweaks): just open a pull request.
- **Bigger changes** (new checks, new commands, changes to the report or config): open an issue first so we can agree on the approach. That saves you from building something that won't get merged.

## Development setup

1. Fork the repo and clone your fork
2. Place it in the `resources` folder of a local FiveM or RedM test server, keeping the folder name `unfckd-lite`
3. Add `ensure unfckd-lite` to your `server.cfg`
4. Restart the resource after changes with `restart unfckd-lite`, or re-run the scan with `unfckd scan`

To test a check, set up the broken situation on purpose, like a missing dependency or a wrong load order, and make sure the report catches it. Also make sure a clean server still reports no problems.

## Ground rules

These are non-negotiable, because they're what makes unfckd-lite trustworthy:

- **No network requests.** unfckd-lite never sends or fetches anything, no matter the reason.
- **Never execute scanned files.** Read and parse manifests and configs as text. Don't pass their contents to `load`, `loadstring`, `dofile` or anything similar.
- **No dependencies.** unfckd-lite must run on any server without other resources, so no ox_lib, framework imports or anything else.
- **Framework-agnostic.** Framework-specific checks are welcome, but they must never break or spam servers that don't use that framework.
- **Read-only.** unfckd-lite reports problems. It doesn't change resources, `server.cfg` or any other files, except writing exports to the `reports/` folder.

## Code style

- Lua 5.4 with 4-space indentation
- Use `local` for everything, with no new globals
- Clear names over short ones: `missingDependencies`, not `md`
- Keep each check in its own function or file, so checks can be added, tested and toggled on their own
- Every new `.lua` file starts with the license header used in the existing files
- Report messages should say **what's wrong and how to fix it**, not just that something failed

Every pull request runs [Luacheck](https://github.com/lunarmodules/luacheck), [StyLua](https://github.com/JohnnyMorganz/StyLua) and [Prettier](https://prettier.io), plus a check for the ground rules above. To run the same checks locally:

```shell
luacheck .
stylua --check .
npx prettier --check .
```

## Pull requests

1. Create a branch from `main` with a clear name, like `fix/manifest-parsing` or `feat/duplicate-exports`
2. Keep each pull request focused on one change
3. Add your change to the `Unreleased` section of [CHANGELOG.md](CHANGELOG.md)
4. Describe what you changed, why, and how you tested it
5. Make sure the scan still runs cleanly on a server without problems

Pull requests from new contributors need approval before automated checks run. That's normal, so don't worry if yours waits a bit.

## Releasing

For maintainers:

1. Set the new `version` in [fxmanifest.lua](fxmanifest.lua)
2. In [CHANGELOG.md](CHANGELOG.md), rename `Unreleased` to the new version with today's date, add a fresh empty `Unreleased` section above it, and update the links at the bottom
3. Commit, then tag and push:

    ```shell
    git tag v1.2.3
    git push origin v1.2.3
    ```

The release workflow runs every check, makes sure the tag matches `fxmanifest.lua` and the changelog, builds `unfckd-lite-v1.2.3.zip` with a checksum, and publishes the GitHub release with the changelog section as its notes. Tags with a suffix, like `v1.3.0-beta.1`, are published as pre-releases.

## Licensing

By contributing, you agree that your contributions are licensed under the [GNU GPL v3.0](LICENSE) with the additional terms in [NOTICE](NOTICE), the same as the rest of the project. You keep the copyright on your own contributions.

## Questions?

Ask in `#help` on our [Discord](https://discord.gg/FWhmYd29DP). Thanks for helping out!
