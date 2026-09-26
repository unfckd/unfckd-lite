# Security Policy

## Supported versions

Only the latest release of unfckd-lite receives security fixes. If you're on an older version, please update before reporting.

| Version        | Supported |
| -------------- | :-------: |
| Latest release |    ✅     |
| Older releases |    ❌     |

## Reporting a vulnerability

**Please don't report security issues in public GitHub issues, pull requests or on Discord.**

Report them privately using one of these:

- **GitHub:** use [Report a vulnerability](../../security/advisories/new) in this repo's Security tab
- **Email:** [support@unfckd.dev](mailto:support@unfckd.dev), with `[SECURITY]` in the subject

Please include:

- A description of the issue and its impact
- Steps to reproduce, or a proof of concept
- Your unfckd-lite version and server artifact version
- Any suggested fix, if you have one

## What to expect

- **Within 72 hours:** we confirm we received your report
- **Within 7 days:** we share our assessment and a rough timeline for a fix
- **When it's fixed:** we release a patched version and publish a security advisory. If you'd like, we'll credit you in it.

Please give us a reasonable amount of time to fix the issue before sharing it publicly.

## Scope

**In scope:**

- The unfckd-lite source code in this repository
- Anything that lets unfckd-lite be used to run code, read files or change server behavior in ways it shouldn't, for example through a crafted `fxmanifest.lua` or `server.cfg`
- Anything that causes unfckd-lite to send data off the server, since it's designed to make no network requests at all

**Out of scope:**

- Problems in the resources that unfckd-lite scans. Report those to their own authors.
- Vulnerabilities in FiveM, RedM or txAdmin themselves. Report those to Cfx.re.
- Issues that require someone to already have full access to the server

For the Unfckd dashboard at [unfckd.dev](https://unfckd.dev), email [support@unfckd.dev](mailto:support@unfckd.dev) with `[SECURITY]` in the subject as well.

## Safe harbor

We won't take action against anyone who reports a vulnerability in good faith, follows this policy, and avoids harming other users or their data while testing. There's no bug bounty at this time, but we genuinely appreciate every report.
