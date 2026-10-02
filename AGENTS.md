# StarHash

iOS SwiftUI companion for MTN MoMo Rwanda: type an amount, pick a recipient,
and StarHash dials the USSD code; it also keeps the transactions, confirmed
from MTN's SMS through a Shortcuts automation. No account, no paywall, no
server. Three tabs: Pay, Activity and Settings. Light and dark, monochrome,
Liquid Glass on iOS 26+. The visual reference is Keaser
(`~/Dev/apps/keaser`, read only): port its patterns, never import its code.

- `Packages/StarHashKit/` - models (`Recipient`, `Transaction`, `Money`),
  `USSD`, `AmountInput`, `CarrierSMS` (the SMS parser), `ActivitySummary`
  and `StarHashStore` (one JSON file, `@Observable @MainActor`). Foundation
  only, `public` API, Swift Testing tests in `Tests/StarHashKitTests`.
  Anything testable belongs here.
- `StarHash/App` - `StarHashApp`, `AppEnvironment` (the shared store and
  `AppRouter`), preference keys, `DebugLaunch`, `SampleData`.
- `StarHash/Design` - Theme tokens, glass helpers, the shared components.
- `StarHash/Features/{Pay,Activity,Settings,Onboarding}` and
  `StarHash/Intents` (App Intents).

The Xcode project is generated from `project.yml` (gitignored). The build
script runs `xcodegen generate`, so new files are picked up.

## Auto-verify shortcut

`StarHash/Resources/StarHash SMS.shortcut` is generated and signed by
`python3 scripts/make_shortcut.py` (needs the Mac signed in to iCloud). Run
it again after renaming `ProcessCarrierSMSIntent`, the bundle id or the
team. Set `StarHashShortcut.iCloudLink` to an iCloud link of the same
shortcut for a one-tap install.

## Commands

    ./scripts/build.sh                      # xcodegen + simulator build
    DERIVED=.build/mine ./scripts/build.sh  # your own build folder
    ./scripts/test.sh                       # StarHashKit tests on the Mac
    APPEARANCE=light ./scripts/screenshot.sh <name> [launch args]
    NOBUILD=1 WAIT=10 ./scripts/screenshot.sh ...   # reuse the build, settle longer

Builds and screenshots each take a lock in `.build/`, so parallel agents
queue. On a loaded machine a 3 second settle can catch the launch screen;
raise `WAIT`. Look at every screenshot you change, in dark and light.

## Rules

- Swift 6 language mode, strict concurrency, no warnings in our sources.
- SwiftUI has its own `Transaction`: write `StarHashKit.Transaction` in any
  file that imports SwiftUI.
- Colours only from `StarHash/Design/Theme.swift`. Ink is the one accent;
  the only other hues are `starhashIncoming` (money in) and
  `starhashDestructive` (money out arrows, destructive actions). Settings
  switches keep the system green, as Keaser's do.
- Glass only through `starhashGlass`, `starhashGlassButtonStyle`,
  `StarHashGlassContainer` (iOS 18 falls back to materials).
- Build screens from the existing pieces: `StarHashSheetHeader`,
  `StarHashCircleButton`, `StarHashCard`, `StarHashRowSeparator`,
  `StarHashActionCard`, `.starhashPrimary`, `.starhashCapsule`,
  `SymbolTile`, `EmptyStateView`, `starhashSheetChrome()`,
  `starhashSheetScrollEdge()`, `starhashBottomBar`. Cards have radius 26.
- Text through text styles or `.starhashFont(size, weight:)` so it follows
  Dynamic Type; icon-only buttons get an accessibility label.
- Preferences: read through `@AppStorage(PreferenceKey...)` in views or
  `StarHashPreferences` elsewhere, with the same defaults (everything on
  except Nearby).
- Only dial a `Recipient` whose `isPayable` is true: SMS senders can be
  masked or have no number.
- Comments explain why, in Keaser's tone. Never use an em dash in comments,
  UI strings or docs.

## Debug launch arguments (DEBUG builds)

| Argument | Effect |
| --- | --- |
| `-inMemory` | fresh in-memory store seeded with `SampleData` |
| `-skipOnboarding`, `-resetOnboarding` | start on the tabs, or on onboarding |
| `-onboardingPage 0...4` | onboarding page (with `-resetOnboarding`) |
| `-tab pay\|buy\|activity\|settings\|help` | starting page |
| `-menu` | side menu open |
| `-ownerName <name> -ownerNumber <number>` | the owner shown in the menu (UserDefaults; `-skipOnboarding` sets 0781234567 when none) |
| `-onboardingPage 0...5` | onboarding page (with `-resetOnboarding`; 1 is the MoMo number) |
| `-helpPage howItWorks\|privacy` | a Help page (with `-tab help`) |
| `-payAmount <n>` | amount on the keypad |
| `-payChosen <input>` | a recipient already chosen (Pay Again with no amount) |
| `-payPicker` | open the recipient picker |
| `-payQuery <text>` | open the picker with this text in its search field |
| `-activityPeriod today\|week\|month\|year\|all` | Activity period |
| `-openFirstTransaction` | open the newest transaction's details |
| `-activitySearch <text>` | Activity search with this text |
| `-activityChartSelection last\|<index>` | chart callout on a bar |
| `-settingsPage wallets\|guide\|guide2\|autoVerifyOff` | a Settings page (with `-tab settings`); guide is Auto-verify at step 1 or 2; autoVerifyOff asks to turn it off |

Example:

    APPEARANCE=dark ./scripts/screenshot.sh pay-saved -inMemory -skipOnboarding -tab pay -payAmount 5000 -payQuery 020205
