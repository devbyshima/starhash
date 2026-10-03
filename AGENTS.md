# StarHash

iOS SwiftUI companion for MTN MoMo and Airtel Money in Rwanda (the owner
picks one as their wallet): type an amount, pick a recipient, and StarHash
dials the USSD code; it also keeps the transactions, confirmed
from MTN's SMS through a Shortcuts automation. No account, no paywall, no
server. Three tabs: Pay, Activity and Settings. Light and dark, monochrome
but for the wallet's colour on primary buttons, Space Grotesk, Liquid Glass
on iOS 26+. The visual reference is Keaser (`~/Dev/apps/keaser`, read
only): port its patterns, never import its code. The primary button and the
glass sheets follow Beam (`~/Dev/apps/beam/Apps/iOS`, read only), and so
does onboarding: its reel, wallet step and permission screen are ports of
Beam's `LoopOnBoarding`, "find your Mac" step and `PermissionOnBoarding`.

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
  the only other hues are `starhashIncoming` (money in),
  `starhashDestructive` (money out arrows, destructive actions) and the
  wallet colours `starhashMTN` and `starhashAirtel`, which fill
  `.starhashPrimary` buttons and tint onboarding (`OnboardingPalette.tint`)
  only. Settings switches keep the system green,
  as Keaser's do.
- Glass only through `starhashGlass`, `starhashGlassButtonStyle`,
  `StarHashGlassContainer` (iOS 18 falls back to materials).
- Build screens from the existing pieces: `StarHashCircleButton`,
  `StarHashCard`, `StarHashRowSeparator`, `.starhashPrimary`,
  `.starhashCapsule`, `SymbolTile`, `EmptyStateView`, `starhashBottomBar`.
  Cards have radius 26.
- Bottom sheets follow Beam's sheet language exactly, built only from
  `StarHash/Design/SheetKit.swift`: `sheetGlass(detents:)`, `SheetHeader`
  (centred 32pt bold title, at most a glass button on the right, no close
  button), cards via `sheetCard()` (radius 22) with `SheetInfoRow`s split
  by `SheetDivider` (dotted), `SheetSectionLabel`, `.sheetPrimary` /
  `.sheetFilled` (50pt) and `SheetTextButton`, and the `Font.sheet...`
  type scale (Beam's sizes and weights). Sized-to-content sheets use
  `sheetHeight` and `.height(height + 8)`.
- Text is Space Grotesk (`StarHash/Resources/Fonts`, a variable font):
  `.font(.starhash(.body))` for a text style, `.starhashFont(size, weight:)`
  for an exact size, so it follows Dynamic Type. Never `Font.system` for
  text (SF Symbols keep it). Icon-only buttons get an accessibility label.
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
| `-tab pay\|buy\|activity\|settings\|help` | starting page |
| `-menu` | side menu open |
| `-note`, `-noteTLDR` | the developer note (full, or on its TL;DR) |
| `-wallet mtn\|airtel\|none` | the main wallet (UserDefaults; none clears it; `-skipOnboarding` sets mtn when none) |
| `-onboardingPage 0...2` | onboarding screen (with `-resetOnboarding`): 0 the reel, 1 the wallet, 2 Contacts |
| `-helpPage howItWorks\|privacy` | a Help page (with `-tab help`) |
| `-payAmount <n>` | amount on the keypad |
| `-payChosen <input>` | a recipient already chosen (Pay Again with no amount) |
| `-payPicker` | open the recipient picker |
| `-payQuery <text>` | open the picker with this text in its search field |
| `-payBrowse` | with `-payPicker`: the picker with its search closed (title header) |
| `-payScroll <points>` | with `-payPicker`: the picker's list scrolled down, a section label pinned |
| `-payDetails <name>` | with `-payPicker`: the details sheet of the first contact whose name contains it |
| `-payToggleSearch` | with `-payPicker`: closes the picker's search after 2s and opens it 1.5s later, to record the header transitions |
| `-payInk` | presses 8, 5, 3 and 7 on a schedule from 1.5s, to record the keypad's ink without a finger (simulator taps arrive late, in bursts) |
| `-payPick <seconds>` | with `-payPicker`: chooses the first recent recipient after this long, to record the wave |
| `-activityPeriod today\|week\|month\|year\|all` | Activity period |
| `-openFirstTransaction` | open the newest transaction's details |
| `-confirmDelete` | with `-openFirstTransaction`: the delete question |
| `-activitySearch <text>` | Activity search with this text |
| `-activityChartSelection last\|<index>` | chart callout on a bar |
| `-settingsPage wallets\|guide\|guide2\|autoVerifyOff` | a Settings page (with `-tab settings`); guide is Auto-verify at step 1 or 2; autoVerifyOff asks to turn it off |

Example:

    APPEARANCE=dark ./scripts/screenshot.sh pay-saved -inMemory -skipOnboarding -tab pay -payAmount 5000 -payQuery 020205
