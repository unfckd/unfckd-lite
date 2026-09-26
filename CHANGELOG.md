# Changelog

All notable changes to unfckd-lite are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-27

### Added

- Startup scan with a color-coded console report, grouped per check with a fix and file location for every problem
- Report header with game, game build and its official update name, artifact build, OneSync state, detected framework and resource count
- Summary with a verdict that tells you what to fix first
- Missing dependency detection, including resources that need a newer artifact, game build (`/gameBuild:`) or OneSync
- Broken and outdated `fxmanifest.lua` detection, including deprecated `__resource.lua`
- Manifest syntax checks for missing or extra commas and stray brackets, with the exact line to fix
- Resources FiveM couldn't load at all, duplicate folders and folders without a manifest, read from FiveM's own startup messages
- One finding for a broken or missing resource instead of one per resource that depends on it
- Detection of misspelled manifest keys, and of values FiveM silently ignores, like `client_scripts 'main.lua'` or `client_script 'a.lua' 'b.lua'`
- Detection of FiveM-only resources on RedM and the other way around, following FXServer's own game rules
- Default Cfx.re resources skip the manifest checks, but are still checked for the right game
- Load-order checks based on the order resources actually started in, so nothing reads `server.cfg`
- Detection of resources that provide the same name, and of conflicting systems
- Works with the filesystem sandbox on current artifacts: only files inside registered resource folders are read
- `unfckd scan` console command to re-run the scan at any time
- `unfckd export` to save the last scan and `unfckd help` to list the commands
- Optional export of the report to the `reports/` folder, as text or JSON

[1.0.0]: https://github.com/unfckd/unfckd-lite/releases/tag/v1.0.0
