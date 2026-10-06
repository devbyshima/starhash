# Contributing to StarHash

Thanks for helping. This page covers where changes go and what a pull request needs. To build and run the app, start with [Development](docs/development.md). How versions reach TestFlight and the App Store is in [RELEASING.md](RELEASING.md).

StarHash is source-available under the [PolyForm Noncommercial License 1.0.0](LICENSE).

## Branches

| Branch | What it is | What goes in |
| --- | --- | --- |
| `main` | The trunk, built as the dev channel | Features, refactors, docs, and fixes for anything not yet released |
| `release/X.Y` | A version being stabilised or on the App Store (beta and production channels) | Fixes only, by pull request |
| `feature/<name>`, `fix/<name>`, `docs/<name>`, `chore/<name>` | Your work, short-lived | One change, then a pull request |

The rules:

1. **Branch from where the change will land.** A feature branches from `main`. A fix for a released version branches from the oldest `release/X.Y` that has the bug.
2. **No new features on a release branch.** Fixes, safety changes (such as turning a feature flag off) and release bookkeeping only. A feature that misses a cut waits for the next version.
3. **Nobody pushes to `main` or `release/*` directly.** Every change arrives by pull request, with CI passing.
4. **Fixes move forward, never back.** After a change merges into a release branch, the maintainer merges that branch into the next newer one and into `main` ([Merge forward](RELEASING.md#5-merge-forward)). Don't copy a fix by hand into several pull requests.
5. **Unfinished work ships dark.** Merge it on `main` behind a [feature flag](#feature-flags) with rollout `.dev` rather than keeping a long-lived branch.
6. **Tags are for releases.** Only the maintainer makes `v*` tags, on release branches, as RELEASING.md describes.

Keep branch names short and lowercase with hyphens: `feature/split-bill`, `fix/airtel-fee-rounding`.

## Commits

Commits follow [Conventional Commits](https://www.conventionalcommits.org): `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `ci:`, `chore:`. The summary says what the app now does, in plain words:

```text
fix: a payment confirmed by SMS no longer stays pending in Activity
```

## Pull requests

- **Target** `main`, or the release branch a fix is for. The template asks which.
- **CI** must pass: StarHashKit's tests, the app's build in the channel the target ships, and the version checks.
- **Tests**: logic that can run without the UI belongs in `Packages/StarHashKit`, with Swift Testing tests beside it. `./scripts/test.sh` runs them.
- **Changelog**: anything someone using StarHash would notice gets a line in [CHANGELOG.md](CHANGELOG.md), under `Added`, `Changed`, `Fixed` or `Removed`. On `main` it goes under `## [Unreleased]`, and on a release branch under that version's section. Internal changes need none.
- **Screenshots**: a change to how a screen looks includes it in light and dark mode. `./scripts/screenshot.sh` takes them (see [Development](docs/development.md#screenshots)).
- **Version and What's New**: leave `MARKETING_VERSION`, the build number and `ReleaseHistory` to the release steps.

## Feature flags

A flag lets unfinished work merge on `main` without reaching testers or the App Store:

1. Declare it in `FeatureFlag.all` (`StarHash/App/FeatureFlags.swift`) with `rollout: .dev`, a stable `key`, and a title and line for the Feature Flags page.
2. Read it with `@FeatureFlagged(.yourFlag) private var isOn` in a view, or `FeatureFlags.isOn(.yourFlag)` elsewhere, and keep the new path behind it.
3. Try it on a device from **Settings > About StarHash > Feature Flags** (dev and beta builds), or in a Debug run with `-featureFlag.yourKey YES`.
4. Move it to `.beta` when testers should see it. When it ships, delete the flag and every check of it in one pull request.

The rollouts and how release branches treat them are in [RELEASING.md](RELEASING.md#feature-flags).

## Code

- Swift 6 language mode with strict concurrency, and no warnings in StarHash's own sources.
- Colours only from `StarHash/Design/Theme.swift`, and every text colour passes WCAG AA on its background.
- Text in Space Grotesk through `.starhash(_:)` or `.starhashFont(_:weight:)`, never `Font.system`, so it follows Dynamic Type. Icon-only buttons get an accessibility label.
- Build screens from the shared pieces in `StarHash/Design` rather than new one-off styles.
- Comments explain why. No em dashes in comments, UI strings or docs.

## Reporting a problem or an idea

Use the [issue forms](https://github.com/devbyshima/starhash/issues/new/choose). Leave out phone numbers, merchant codes and amounts: issues are public.
