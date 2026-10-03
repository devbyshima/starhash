# StarHash

iOS SwiftUI companion for MTN MoMo and Airtel Money in Rwanda (the owner
picks one as their wallet): type an amount, pick a recipient, and StarHash
dials the USSD code; it also keeps the transactions, confirmed
from MTN's SMS through a Shortcuts automation. No account, no paywall, no
server. Three tabs: Pay, Activity and Settings. Light and dark in a
four-colour palette (blue #05A9F4, pale grey #F4F4F4, near black #171717,
grey #616161): light mode is the blue throughout, as Cash App is its
green, and dark mode is the near black throughout. Space Grotesk, Liquid
Glass on iOS 26+. The visual reference is Keaser (`~/Dev/apps/keaser`, read
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
- Colours only from `StarHash/Design/Theme.swift`, built from the four
  palette colours (`brandBlue`, `brandPaper`, `brandNight`, `brandGrey`).
  Never change their values; a variation (an opacity, a lifted card grey,
  a deeper blue for text) is fine where contrast needs it, and every text
  colour must pass WCAG AA on its background (4.5:1, 3:1 for large text and
  placeholders). Every light page is the blue, so the accent
  (`starhashInk`, with `starhashOnInk` text) is near black there and the
  blue in dark mode; text and marks straight on the page use
  `starhashAccentText`. Text colours resolve by surface
  (`StarHash/Design/Surface.swift`): on the blue page light-mode text is
  WHITE (the founder's choice, 2026-10-03; white on #05A9F4 is 2.6:1,
  under AA, accepted for the look), and inside anything marked
  `.starhashSurface(.card)` (cards, `sheetCard`, every sheet, settings
  rows) it is near black. Mark any new card or sheet, or its text turns
  white on white.
  Red text on the page is `starhashDestructiveOnPage` (no brighter red
  reads on the blue). Glass gets the deep-blue `starhashGlassTint` by
  default, or it turns cyan on the blue. The only other hues are
  `starhashIncoming` (money in) and `starhashDestructive` (money out
  arrows, destructive actions); the carriers' colours live only in their
  logos and the pulse rings round the chosen one on onboarding. Switches
  are `starhashSwitchOn`.
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
| `-settingsPage whatsNew\|release\|guide\|guide2\|autoVerifyOff` | a Settings page (with `-tab settings`); guide is Auto-verify at step 1 or 2; autoVerifyOff asks to turn it off |

Example:

    APPEARANCE=dark ./scripts/screenshot.sh pay-saved -inMemory -skipOnboarding -tab pay -payAmount 5000 -payQuery 020205
