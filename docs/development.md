# Development

Everything you need to build, test and change StarHash.

## Requirements

- macOS with [Xcode 27](https://developer.apple.com/xcode/) (the iOS 27 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Python 3, only for the scripts that draw doodles and sign the shortcut

StarHash is an iPhone app (portrait only, iOS 18 and later), written in Swift 6 with strict concurrency, with no third-party packages.

## Set up

The Xcode project is generated from `project.yml` and is not committed.

1. Set your own `DEVELOPMENT_TEAM` and the StarHash target's `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`. Automatic signing with a free personal team is enough: there are no entitlements or App Groups.
2. Generate the project and open it:
   ```bash
   xcodegen generate
   open StarHash.xcodeproj
   ```

Run `xcodegen generate` again after adding or renaming files. The build script does it for you.

> [!NOTE]
> The scripts also name the bundle id: `scripts/screenshot.sh` launches it, and `scripts/make_shortcut.py` signs the shortcut for it. Change them too if yours differs.

## Scripts

```bash
./scripts/build.sh                      # generate the project and build for the simulator
DERIVED=.build/mine ./scripts/build.sh  # use a build folder of your own
./scripts/test.sh                       # run StarHashKit's tests on the Mac
```

`build.sh` prints only errors, warnings from StarHash's own sources and the result. Set `DEST` to build for another destination, for example `DEST="generic/platform=iOS"` for a device.

Builds and screenshots each take a lock in `.build/`, so runs started side by side wait their turn.

## Tests

The logic lives in `Packages/StarHashKit` (Foundation only) and is covered by Swift Testing: the SMS parser, the store and its message matching, Activity's totals and search, Nearby, recipients, the keypad, Buy's codes and the fee tables. `./scripts/test.sh` runs them on the Mac, with no simulator.

## Screenshots

```bash
./scripts/screenshot.sh pay -inMemory -skipOnboarding -tab pay -payAmount 5000
APPEARANCE=light ./scripts/screenshot.sh pay-light -inMemory -skipOnboarding -tab pay
NOBUILD=1 WAIT=10 ./scripts/screenshot.sh activity -inMemory -skipOnboarding -tab activity
```

The script builds, creates a simulator named "StarHash" (iPhone 17 Pro) if it is missing, sets the appearance (dark unless `APPEARANCE` says otherwise), launches with your arguments and saves `screenshots/<appearance>/<name>.png`. `NOBUILD=1` reuses the last build; raise `WAIT` if the launch screen shows up instead of your page.

## Debug launch arguments

Debug builds read these, in Xcode's scheme or after the screenshot script's name:

| Argument | Effect |
| --- | --- |
| `-inMemory` | A fresh store with sample payments (made-up numbers and amounts) |
| `-emptyStore` | With `-inMemory`: no payments, for the empty states |
| `-skipOnboarding`, `-resetOnboarding` | Start on the tabs, or on onboarding |
| `-onboardingPage 0...4` | With `-resetOnboarding`: the onboarding screen to open on |
| `-tab pay\|buy\|activity\|settings` | The page to start on |
| `-wallet mtn\|airtel\|none` | The main wallet |
| `-appAppearance system\|dark\|light` | The Appearance setting |
| `-payAmount <n>` | An amount on the keypad |
| `-payPicker`, `-payQuery <text>` | Open the recipient screen, optionally with a search |
| `-nearbyHere` | Turn Nearby on and place the phone where two sample payments were made |
| `-activityPeriod today\|week\|month\|year\|all` | Activity's period |
| `-activitySearch <text>` | Activity's search |
| `-openFirstTransaction`, `-openPendingTransaction` | Open a payment's details |
| `-buyPinned [n]`, `-buyEmpty`, `-buyNew` | Buy with pinned codes or with none (both with `-inMemory`), or with the new-code sheet open |
| `-settingsPage <page>` | Open a Settings page: `whatsNew`, `terms`, `privacy`, `about`, `guide` and more |
| `-locked`, `-splash`, `-note`, `-reviewNote` | The lock screen, the launch splash, the developer's note or the rating note |

Each screen reads its own arguments where it uses them, so to find one not listed here (such as `-buyArrange`, `-payChooser` or `-confirmDelete`), search the sources for its name. The shared ones are in `StarHash/App/DebugLaunch.swift` and the keypad's in `StarHash/Features/Pay/PayDebug.swift`.

## Run on an iPhone

Dialling needs a real iPhone: on the simulator Pay shows the code in an alert. From Xcode, pick your iPhone and run. From the command line:

```bash
DEST="generic/platform=iOS" DERIVED="$PWD/.build/device" ./scripts/build.sh
xcrun devicectl list devices
xcrun devicectl device install app --device <device-id> .build/device/Build/Products/Debug-iphoneos/StarHash.app
```

To test Auto-verify on your own build, see [Auto-verify with your own build](auto-verify.md#with-your-own-build).

## Project layout

```text
project.yml               XcodeGen spec: targets, settings, Info.plist keys
Packages/StarHashKit/     models, store, USSD codes, SMS parser, totals, fees (Foundation only)
StarHash/App/             app entry, tab bar, routing, lock, debug launch, sample data
StarHash/Design/          palette, fonts, Liquid Glass helpers, sheets, shared components, shaders
StarHash/Features/        Pay, Buy, Activity, Settings and Onboarding
StarHash/Intents/         App Intents for Shortcuts and Siri
StarHash/Resources/       asset catalog, app icon, Space Grotesk
scripts/                  build, test, screenshot, doodles and shortcut scripts
docs/                     this documentation
```

Anything that can be tested without the UI belongs in StarHashKit.

## Releases

- **Version**: `MARKETING_VERSION` in `project.yml`.
- **Build number**: `CURRENT_PROJECT_VERSION` counts App Store uploads, not builds: 1 for the first upload, and one more before archiving each one after it. App Store Connect refuses a number it already has for the same version. Settings shows it after the version, as in `1.0.0 (1)`.
- **What's New**: add a release at the top of `ReleaseHistory.releases` in StarHashKit.
- **App Store id**: once the App Store record exists, set `DeveloperNoteLinks.appStoreID` so Rate on the App Store opens the review page.

## Doodles

The empty-state drawings are generated, a light and a dark SVG each, into the asset catalog:

```bash
python3 scripts/make_doodles.py
```
