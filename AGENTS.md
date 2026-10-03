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
  `USSD`, `USSDShortcut` and `USSDShortcutList` (Buy's codes, kept in
  UserDefaults), `AmountInput`, `CarrierSMS` (the SMS parser), `ActivitySummary`
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
  `starhashAccentText`. Light-mode secondary and tertiary text are the near
  black at 80% and 60%, which pass on the blue and on white cards alike.
  Red text on the page is `starhashDestructiveOnPage` (no brighter red
  reads on the blue). Glass gets the deep-blue `starhashGlassTint` by
  default, or it turns cyan on the blue. The only other hues are
  `starhashIncoming` (money in), `starhashDestructive` (money out
  arrows, destructive actions) and `starhashUrgent` (the orange of a
  pending payment); the carriers' colours live only in their
  logos and the pulse rings round the chosen one on onboarding. Switches
  are `starhashSwitchOn`.
- Light-mode sheets are solid white (`sheetGlassTint`) with brand blue
  cards (`sheetSurface`), deeper blue small fills (`sheetChip`) and the
  app's usual dark text; destructive text buttons are bold in the deep
  red.
- Every separator is dashed, GO Club's 3pt on and 3pt off: `SheetDivider`,
  or `StarHashRowSeparator` (which draws it with insets). Settings lists
  hide the system's solid lines and `settingsCardRow` draws the dashed one
  right across the card. Never a solid line.
- Settings follows GO Club's: cards 10pt from the screen's edges,
  everything 20pt inside them, a section's grey title inside its card as
  its first row (`SettingsSectionTitle`, then `.firstUnderTitle` or
  `.onlyUnderTitle`), and Delete All Data on its own as a blood red
  capsule.
- Glass only through `starhashGlass`, `starhashGlassButtonStyle`,
  `StarHashGlassContainer` (iOS 18 falls back to materials).
- The tab bar (`StarHash/App/StarHashTabBar.swift`) is measured from GO
  Club's screen recordings; keep its numbers (`TabBarMetrics`,
  `TabBarLayout`) and its spring (response 0.4, damping 0.61) as they
  are. The bar is centred inside a frame of its widest width, so its
  width change rides the spring; never let the page re-centre it, or the
  symbols jump on the first frame of a switch. Page changes play
  `NavigationHaptics` (two layers on the switch, a thump and a rumble; none for the lens's
  bounce), never a plain `sensoryFeedback`. It is the only glass with no tint: clear
  Liquid Glass, as the reference's. Activity's period control
  (`GlassSegmentedControl`) moves as it does, on the same `LensGlass` and
  `LensMotion`, but in the page's tinted glass with a light lens, as the
  search button beside it, and plays the system's selection tick.
- Every button is felt as it goes down: the shared button styles play an
  impact (`starhashPressHaptic`; medium for Pay, Balance, Continue and a
  sheet's button, light for round glass buttons and rows), and a plain
  button uses `.hapticPlain`, never `.plain`. Don't add a second haptic
  for the same tap. Root pages leave room for it with
  `starhashTabBarClearance()`, scroll views shrink it with
  `starhashTabBarFollowsScroll()`, and a page hides it with
  `router.setHidesTabBar(_:on:)` while a screen is pushed or a search is
  open.
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
- Type follows GO Club's weights, measured from its screens: text is
  medium (the default of `starhash(_:)`, `starhashFont` and `sheet`),
  buttons semibold, headings and numbers bold, and large headings tighten
  (`StarHashTracking`; numbers pass `tracking: 0`). Units after an amount
  are about half its size, on its baseline.
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
| `-emptyStore` | with `-inMemory`, no transactions (Activity's empty state) |
| `-buyNew`, `-buyEdit` | with `-tab buy`: the code editor, new or on the first code; `-buySymbols` opens its symbol grid |
| `-splash` | the launch splash (any other debug argument skips it, so screenshots see their screen) |
| `-skipOnboarding`, `-resetOnboarding` | start on the tabs, or on onboarding |
| `-tab pay\|buy\|activity\|settings` | starting page |
| `-note`, `-reviewNote` | Shima's welcome note over Pay, as onboarding ends, or the two-week note that asks for a rating |
| `-wallet mtn\|airtel\|none` | the main wallet (UserDefaults; none clears it; `-skipOnboarding` sets mtn when none) |
| `-onboardingPage 0...4` | onboarding screen (with `-resetOnboarding`): 0 the reel, 1 the wallet, 2 Contacts, 3 Nearby, 4 auto-verify (MTN only) |
| `-payAmount <n>` | amount on the keypad |
| `-payChosen <input>` | a recipient already chosen (Pay Again with no amount) |
| `-payPicker` | open the recipient picker |
| `-payQuery <text>` | open the picker with this text in its search field |
| `-payBrowse` | with `-payPicker`: the picker with its search closed (title header) |
| `-payScroll <points>` | with `-payPicker`: the picker's list scrolled down, a section label pinned |
| `-payDetails <name>` | with `-payPicker`: the details sheet of the first contact whose name contains it |
| `-payToggleSearch` | with `-payPicker`: closes the picker's search after 2s and opens it 1.5s later, to record the header transitions |
| `-payInk` | presses 8, 5, 3 and 7 on a schedule from 1.5s, to record the keypad's ink without a finger (simulator taps arrive late, in bursts) |
| `-nearbyHere` | turns Nearby on and places the phone at Kigali Heights, where `SampleData.places()` has visits, for the picker's Nearby section |
| `-payPick <seconds>` | with `-payPicker`: chooses the first recent recipient after this long, to record the wave |
| `-activityPeriod today\|week\|month\|year` | Activity period (the D W M Y control) |
| `-openFirstTransaction` | open the newest transaction's details |
| `-confirmDelete` | with `-openFirstTransaction`: the delete question |
| `-activitySearch <text>` | Activity search with this text |
| `-activityChartSelection last\|<index>` | chart callout on a bar |
| `-settingsPage whatsNew\|release\|howItWorks\|privacy\|about\|guide\|guide2\|guideFailed\|guideVerified\|autoVerifyOff` | a Settings page (with `-tab settings`); guide is Auto-verify at step 1 or 2, guideFailed/guideVerified step 2 after its check; autoVerifyOff asks to turn it off |

Example:

    APPEARANCE=dark ./scripts/screenshot.sh pay-saved -inMemory -skipOnboarding -tab pay -payAmount 5000 -payQuery 020205
