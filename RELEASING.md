# Releasing StarHash

How a change goes from `main` to TestFlight to the App Store, and how a fix reaches every version that needs it. Every step has the exact commands. Branch rules for contributors are in [CONTRIBUTING.md](CONTRIBUTING.md).

## The model

New work lands on `main`. When a version is ready to stabilise, a `release/X.Y` branch is cut from `main`. That branch takes only fixes, goes to TestFlight as betas, then to the App Store, and stays alive for that version's patch releases. A fix is always made on the oldest release branch that has the bug, then merged forward into each newer release branch and `main`, so it can never be lost.

```text
main          o---o---o---o---o---o---o---o---o---o   (1.2.0 work)
                       \             ^           ^
                        \            | merge     | merge
release/1.1              o---o---o---o---o---o---o
                             |       |   |       |
                          beta.1   rc.1 v1.1.0  v1.1.1 (a hotfix)
```

## Channels

| Channel | Built from | Xcode scheme (configuration) | Goes to | Who sees it |
| --- | --- | --- | --- | --- |
| **dev** | `main` | **StarHash** (Debug) | Xcode, the simulator, your own iPhone | You |
| **beta** | the newest `release/X.Y`, tagged `vX.Y.Z-beta.N` | **StarHash Beta** (Beta) | TestFlight | Testers |
| **production** | `release/X.Y`, tagged `vX.Y.Z-rc.N`, then `vX.Y.Z` | **StarHash** (Release) | TestFlight, then the App Store | Everyone |

The configuration stamps the channel into Info.plist (`StarHashChannel`), so the app knows which one it is: Settings shows it after the version in dev and beta builds ("1.1.0 (2) Beta"), and it decides where each [feature flag](#feature-flags) starts.

At most two release branches are looked after at once: the one on the App Store (production) and, while a new version is in beta, the newer one. When a version reaches the App Store, the one before it is retired: no more fixes go to it. Its branch and tags stay.

CI follows the same lines ([`.github/workflows`](.github/workflows)):

| Event | Workflow | What runs |
| --- | --- | --- |
| Pull request to `main` or `release/**` | `ci.yml` | StarHashKit tests, the app built in the target's configuration, the version checks |
| Push to `main` | `deliver.yml` | Tests, then a dev simulator build, kept as an artifact for 14 days |
| Push to `release/**`, or a `-beta.N` tag | `deliver.yml` | Tests, then an unsigned Beta archive, kept 30 days |
| A `-rc.N` or final `vX.Y.Z` tag | `deliver.yml` | Tests, the release checks, then an unsigned Release archive, kept 90 days |

CI builds and tests, and stops there. TestFlight and App Store uploads are made from Xcode, signed with the team's account.

> [!NOTE]
> The workflows run on GitHub's `xcode-27` runner image, which is in preview. Once `macos-latest` has Xcode 27, change `runs-on` to it in both workflows.

## Versions, tags and build numbers

StarHash follows [Semantic Versioning](https://semver.org), read for an app:

- **MAJOR** (`2.0.0`): a release that changes something people rely on, such as dropping an iOS version or storing payments in a way older versions cannot read.
- **MINOR** (`1.1.0`): each version cut from `main`, with its new features.
- **PATCH** (`1.1.1`): fixes only, from a release branch.

`MARKETING_VERSION` in `project.yml` is always plain `MAJOR.MINOR.PATCH`, since the App Store takes nothing after it. `main` always carries the next minor version: cutting `release/1.1` moves `main` to `1.2.0`.

Tags are annotated, made on release branches only, and pushed:

| Tag | Marks | Built with |
| --- | --- | --- |
| `v1.1.0-beta.1`, `-beta.2`, ... | A TestFlight beta | StarHash Beta |
| `v1.1.0-rc.1`, `-rc.2`, ... | The App Store build, on TestFlight for a last look | StarHash |
| `v1.1.0` | The version on the App Store: the last rc's code, with its changelog dated | |

The **build number** (`CURRENT_PROJECT_VERSION`) counts uploads to App Store Connect for one version. It starts at 1 with each new version and goes up by one before every upload after that, since App Store Connect refuses a number it already has for that version. Each tag's message names the build it was uploaded as.

`./scripts/bump_version.sh` makes both changes:

```bash
./scripts/bump_version.sh 1.2.0   # a new version, build 1
./scripts/bump_version.sh build   # the next upload of the same version
```

`./scripts/check_release.sh` prints the channel a ref builds and fails when the ref and the code disagree: a release branch with another version, a tag that isn't `MARKETING_VERSION`, a missing changelog section, a new minor without its What's New, or a final tag without a release date. CI runs it, and so can you before tagging:

```bash
./scripts/check_release.sh refs/tags/v1.1.0-rc.1
```

## Where a change goes

| Change | Branch from | Pull request into | Then |
| --- | --- | --- | --- |
| A feature, or a fix for something not yet released | `main` | `main` | |
| A fix for the version in beta | `release/X.Y` (the beta's) | `release/X.Y` | Merge forward into `main` |
| A fix for the version on the App Store | the oldest supported `release/X.Y` with the bug | that branch | A patch release, then merge forward |
| Unfinished work | `main` | `main`, behind a feature flag | |

A release branch never takes a new feature. If one is wanted in a version that has been cut, it waits for the next one.

## 1. Cut a release branch

When `main` has what the next version should have (here `main` is at `1.1.0`):

1. Make sure nothing unfinished will ship. In `StarHash/App/FeatureFlags.swift`, each flag for unfinished work must be `.off` or `.dev`, so the beta and the App Store build leave it out.
2. Open the version's changelog section, and cut the branch:

   ```bash
   git switch main
   git pull --ff-only
   ./scripts/check_release.sh                      # dev channel, version=1.1.0
   ```

   In `CHANGELOG.md`, rename `## [Unreleased]` to `## [1.1.0] - Unreleased`, put a new empty `## [Unreleased]` above it, and point the links at the bottom at the new branch:

   ```markdown
   [Unreleased]: https://github.com/devbyshima/starhash/compare/release/1.1...main
   [1.1.0]: https://github.com/devbyshima/starhash/tree/release/1.1
   ```

   ```bash
   git commit -am "docs: 1.1.0 in the changelog"
   git switch -c release/1.1
   git push -u origin release/1.1
   ```

3. Move `main` on to the next version:

   ```bash
   git switch main
   ./scripts/bump_version.sh 1.2.0
   git commit -am "chore: start 1.2.0"
   git push origin main
   ```

## 2. Run a beta

Each beta is an upload of the release branch built with the **StarHash Beta** scheme.

1. Raise the build number, except for the version's very first upload (build 1):

   ```bash
   git switch release/1.1
   git pull --ff-only
   ./scripts/bump_version.sh build
   git commit -am "chore: 1.1.0 build 2"
   ```

2. In Xcode, pick the **StarHash Beta** scheme and **Any iOS Device**, then **Product > Archive**. In the Organizer, **Distribute App > App Store Connect > Upload**.
3. Once the upload is accepted, tag what was uploaded and push it:

   ```bash
   git tag -a v1.1.0-beta.1 -m "1.1.0 (2), TestFlight beta"
   git push origin release/1.1 v1.1.0-beta.1
   ```

4. In App Store Connect, add the build to your TestFlight testers.

Fixes from testing go through pull requests into `release/1.1`, each with a line under `## [1.1.0]` in the changelog. After each one, [merge forward](#5-merge-forward). Then repeat this section for `beta.2`, and so on.

## 3. Promote to production

The App Store build uses the **StarHash** scheme (production channel), so it is uploaded once more as a release candidate and checked on TestFlight before it goes for review. The build that passes is the one submitted: nothing is rebuilt.

1. Add the version's What's New at the top of `ReleaseHistory.releases` in StarHashKit, dated the day you will submit it, and raise the build:

   ```bash
   git switch release/1.1
   git pull --ff-only
   ./scripts/bump_version.sh build
   git commit -am "docs: What's New for 1.1.0"
   ./scripts/check_release.sh refs/tags/v1.1.0-rc.1
   ```

2. In Xcode, pick the **StarHash** scheme and **Any iOS Device**, archive and upload as for a beta. Then tag it:

   ```bash
   git tag -a v1.1.0-rc.1 -m "1.1.0 (3), App Store candidate"
   git push origin release/1.1 v1.1.0-rc.1
   ```

3. Try the build on TestFlight. If it needs a fix, fix it on the branch and upload `rc.2` the same way.
4. In App Store Connect, choose that build for version 1.1.0 and submit it for review.
5. When Apple approves it and it is released, date the changelog and tag the version. In `CHANGELOG.md`, change `## [1.1.0] - Unreleased` to today's date and point its link at the tag:

   ```markdown
   ## [1.1.0] - 2026-11-02
   ...
   [1.1.0]: https://github.com/devbyshima/starhash/releases/tag/v1.1.0
   ```

   ```bash
   git commit -am "docs: 1.1.0 is on the App Store"
   git diff --stat v1.1.0-rc.1 HEAD                # only CHANGELOG.md
   ./scripts/check_release.sh refs/tags/v1.1.0
   git tag -a v1.1.0 -m "1.1.0 (3), App Store"
   git push origin release/1.1 v1.1.0
   ```

6. [Merge forward](#5-merge-forward) so `main` has the dated changelog and every fix. The release before this one (here `release/1.0`) is now retired.

To publish the notes on GitHub as well (optional):

```bash
gh release create v1.1.0 --verify-tag --title "StarHash 1.1.0" --notes "See CHANGELOG.md"
```

## 4. Ship a hotfix

A bug in the App Store version is fixed on the oldest supported release branch that has it, released as a patch, then carried forward. Here 1.1.0 is on the App Store and 1.2.0 is in beta on `release/1.2`.

1. Branch from the release branch and make the fix, with a test in StarHashKit where it can have one:

   ```bash
   git switch release/1.1
   git pull --ff-only
   git switch -c fix/pending-reminder-twice
   ./scripts/bump_version.sh 1.1.1                 # the first fix after 1.1.0 only
   ```

   In `CHANGELOG.md`, add a section above `## [1.1.0]` (or add to it, if this patch already has one):

   ```markdown
   ## [1.1.1] - Unreleased

   ### Fixed

   - A pending payment's reminder no longer comes twice.
   ```

   ```bash
   git commit -am "fix: a pending payment's reminder comes once"
   git push -u origin fix/pending-reminder-twice
   ```

2. Open a pull request into `release/1.1`. Once CI passes, merge it.
3. Release it as in [Promote to production](#3-promote-to-production), with 1.1.1 for 1.1.0: upload an rc with the **StarHash** scheme, tag `v1.1.1-rc.1`, submit it for review, then date the changelog and tag `v1.1.1`. A What's New entry is optional for a patch. A beta is optional too: skip it when the fix is small and the rc covers it.
4. [Merge forward](#5-merge-forward) into `release/1.2`, then into `main`.

## 5. Merge forward

After every change to a release branch (a beta fix, a hotfix, a release), merge it into the next newer release branch, if there is one, and then into `main`. Merging, rather than copying commits, lets git keep track: a fix that was merged forward can't be lost.

```bash
git switch release/1.2
git pull --ff-only
git merge --no-ff release/1.1 -m "Merge release/1.1 into release/1.2"
./scripts/test.sh
git push origin release/1.2

git switch main
git pull --ff-only
git merge --no-ff release/1.2 -m "Merge release/1.2 into main"
./scripts/test.sh
git push origin main
```

With no newer release branch, merge `release/1.1` into `main` directly.

The same few conflicts come up each time:

| File | Keep |
| --- | --- |
| `project.yml` | The newer branch's `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, and every other change from both sides |
| `ReleaseHistory.swift` | Both releases, newest version first |
| `CHANGELOG.md` | Both sections, newest version first, under `[Unreleased]` |

If the fix doesn't apply to the newer code because it has changed, still merge, so git records the fix as carried forward, and write the equivalent fix as the conflict resolution.

Nothing has been left behind when these print nothing:

```bash
git log --oneline release/1.2..release/1.1
git log --oneline main..release/1.2
```

## Feature flags

Unfinished work can be merged on `main` behind a flag, so `main` stays ready to cut at any time. A flag is set per channel by its rollout, and a dev or beta build can switch it on that device:

| Rollout | dev | beta | production |
| --- | --- | --- | --- |
| `.off` | off | off | off |
| `.dev` | on | off | off |
| `.beta` | on | on | off |
| `.everywhere` | on | on | on |

Declare a flag in `FeatureFlag.all` (`StarHash/App/FeatureFlags.swift`) and read it with `@FeatureFlagged(.splitBill) private var splitsBills` in a view or `FeatureFlags.isOn(.splitBill)` elsewhere. In dev and beta builds, **Settings > About StarHash > Feature Flags** switches each one on that iPhone, and a Debug run can take one as a launch argument: `-featureFlag.splitBill YES`. The App Store build ignores both.

A flag's life: `.dev` while it is built, `.beta` once testers should try it (on `main` before cutting the branch, or on the release branch as a fix if it was cut with `.dev`), and when it ships, delete the flag and its checks. A release branch can turn a flag off, but never on for work that isn't finished.

## GitHub settings

These are set on GitHub, not in the repository. Recommended:

- A branch ruleset for `main` and `release/**`: require a pull request and the **StarHashKit tests** and **App build** checks, and block force pushes and deletion.
- A tag ruleset for `v*`: only maintainers create tags, and nobody moves or deletes one.
