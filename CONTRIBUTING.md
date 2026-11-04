# Contributing to Rewind

Rewind is an experimental native media app, originally developed for a single ARMv7 iPad. Small, evidence-backed changes are easier to review than broad rewrites.

## Before changing code

Read the [architecture](docs/architecture.md), [setup guide](docs/getting-started.md) and [known limitations](docs/status.md). Run `python3 tools/check_public_repo.py` and `python3 tools/run_portable_checks.py`. The historical full suite has additional local inputs; do not substitute the portable subset for device acceptance.

Keep iOS 9 API availability and ARMv7 constraints explicit. New native experiments must use new version/output paths. Do not mutate old frozen checkpoints. Describe the problem, the resulting behavior, exact tests and what remains unverified in your pull request.

## Resource and device discipline

Inspect existing project processes and ports before starting a server, watcher, browser or test worker. Reuse a healthy instance, keep one development stack, and clean up only the processes you own. Do not leave proof servers running after a test.

Device work needs the device owner's authorization. Explain writes before running them, preserve profiles and viewing progress, and keep build and installation separate. Never erase, restore, jailbreak or change SSH/network settings as part of an unrelated fix. Do not run the historical iPad control setup against another person's device.

## Bug reports

Include app version, device model, OS, expected behavior, exact steps and observed result. Distinguish source lookup, connecting, buffering and decoder startup. Mention whether media was cached. Use an authored or freely distributable sample where practical.

Remove account details, IP addresses, private tracker URLs/passkeys, viewing history and device identifiers from logs and screenshots. Never attach passwords, provisioning profiles, private keys, full device exports or copyrighted media. Report security concerns privately via [GitHub security advisories](https://github.com/codeverbojan/rewind/security/advisories/new).

## Licensing

Contributions to original project code are accepted under the [MIT license](LICENSE). Preserve third-party notices and provenance. Do not commit SDKs, downloaded catalogs, standalone commercial posters, personal device state or signed packages.
