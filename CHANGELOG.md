# Changelog

All notable changes to unfckd-lite are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Startup scan with a color-coded console report
- Missing dependency detection
- Broken and outdated `fxmanifest.lua` detection, including deprecated `__resource.lua`
- Load-order checks against `server.cfg`
- Duplicate resource and conflicting system detection
- `unfckd scan` console command to re-run the scan at any time
- Optional export of the report to the `reports/` folder

[Unreleased]: https://github.com/unfckd/unfckd-lite/commits/main
