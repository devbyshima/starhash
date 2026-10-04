# StarHash

iOS SwiftUI companion for MTN MoMo and Airtel Money in Rwanda (the owner
picks one as their wallet): type an amount, pick a recipient, and StarHash
dials the USSD code; it also keeps the transactions, confirmed
from the wallet's SMS (MTN MoMo's or Airtel Money's) through a Shortcuts
automation. No account, no paywall, no
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
  UserDefaults), `AmountInput`, `CarrierSMS` (the SMS parser, MTN MoMo's
  and Airtel Money's messages), `ActivitySummary` and `StarHashStore` (one
  JSON file, `@Observable @MainActor`). Foundation only, `public` API,
  Swift Testing tests in `Tests/StarHashKitTests`. Anything testable
  belongs here.
- `StarHash/App` - `StarHashApp`, `AppEnvironment` (the shared store and
  `AppRouter`), preference keys, `DebugLaunch`, `SampleData`.
- `StarHash/Design` - Theme tokens, glass helpers, the shared components.
- `StarHash/Features/{Pay,Activity,Settings,Onboarding}` and
  `StarHash/Intents` (App Intents).

The Xcode project is generated from `project.yml` (gitignored). The build
script runs `xcodegen generate`, so new files are picked up.

## Auto-verify shortcut

`python3 scripts/make_shortcut.py` generates and signs
`StarHash/Resources/StarHash SMS.shortcut` (needs the Mac signed in to
iCloud). Run it again after renaming `ProcessCarrierSMSIntent`, the bundle
id or the team, share the result from Shortcuts, and set
`StarHashShortcut.iCloudLink` to its iCloud link. The app installs from that
link only: the file is not committed at present, and the share-sheet
fallback in `StarHashShortcut` runs only when the link is nil and the file
is bundled.

## App Store id

Set `DeveloperNoteLinks.appStoreID` once StarHash's App Store Connect
record exists: Rate on the App Store then opens the Write a Review page,
instead of asking iOS for a rating prompt it may not show.

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
- A screen shown before a system permission prompt (Contacts, location)
  has one button, Continue, that opens the prompt: no Maybe Later, Not
  Now, close or Allow (Apple's pre-alert rule, App Review 5.1.1(iv)).
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
- Light-mode sheets are solid white (`sheetGlassTint`) with near-white
  blue cards (`sheetSurface`) and a step deeper small fills (`sheetChip`),
  the app's usual dark text inside them. Text and marks straight on a
  sheet, with nothing behind them (titles, hero names, labels, text
  buttons), are the brand blue (`sheetBrandText`: the blue itself in dark
  mode, deepened just enough to read on white in light), except Shima's
  notes, which keep the black and white of a letter; destructive text
  buttons stay bold in the deep red.
- Every delete button StarHash draws is `DeleteButton`: the blood red
  capsule with a bin and white words, full width in sheets and pages, the
  width of its words for Delete All Data. Menus, swipes and confirmation
  alerts stay the system's own, but a destructive menu item's icon is red
  with its words (`DestructiveMenuLabel`), never a black bin beside a red
  "Delete".
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
- Every container (card, panel, field box) goes through
  `starhashContainer(_:in:)`: white glass in light mode (Liquid Glass over
  its solid fill) and **black glass** in dark (the
  near black as Liquid Glass). A card of rows is one container behind all
  of them, never a slice per row: Settings pages are a `SettingsScroll` of
  `SettingsCard`s (rows keep their 20pt with `settingsRowInset()`,
  `SettingsLinkRow` for a row that opens a page). Activity's
  transactions are each a card of their own (`ActivityTransactionRows`,
  radius 22, 10pt apart), exactly as Buy's codes are: the same press,
  the same swipe (the whole card slides aside, the trash beside it) and
  the same exit (shrink and fade); keep the two alike.
- **Soft Edge** is the one edge treatment: what scrolls under a bar softly
  fades and blurs into it, the system's soft scroll edge (Settings' look).
  Every scroll view and list gets `starhashSoftEdge()`, and a page's own
  header goes in `starhashSoftEdgeHeader { }` so the edge runs under it as
  under a navigation bar. Never a hand-drawn gradient fade.
- The tab bar (`StarHash/App/StarHashTabBar.swift`) is measured from GO
  Club's screen recordings; keep its numbers (`TabBarMetrics`,
  `TabBarLayout`) and its spring (response 0.4, damping 0.61) as they
  are. The bar is centred inside a frame of its widest width, so its
  width change rides the spring; never let the page re-centre it, or the
  symbols jump on the first frame of a switch. Page changes play
  `NavigationHaptics` (two layers on the switch, a thump and a rumble; none for the lens's
  bounce), never a plain `sensoryFeedback`. It is clear Liquid Glass, with
  no tint, as the reference's, and so are the controls along the top of
  every page: the round header buttons (`starhashCircleButton()`, so
  `SwapGlassButton`, the wallet switcher and the back button), the search
  fields beside them, and Activity's period control
  (`GlassSegmentedControl`), which moves as the bar does, on the same
  `LensGlass` and `LensMotion`, with a light lens, and plays the system's
  selection tick. Balance, Buy's codes and pinned tiles are the **Total
  card** (`starhashTotalCard(in:)`, the recipient screen's Total: solid
  white in light mode, the sheets' near-black glass in dark), and Buy's
  call buttons black in light mode (`callSolidFill` under
  `callGlassTint`, a brand blue phone) and blue glass in dark.
- Activity's symbol is the clock (`clock.fill`, `clock` for its empty
  state), as Cash App's: in the tab bar, onboarding and What's New. Keep
  the clock for Activity alone.
- Every button is felt as it goes down: the shared button styles play an
  impact (`starhashPressHaptic`; medium for Pay, Balance, Continue and a
  sheet's button, light for round glass buttons and rows), and a plain
  button uses `.hapticPlain`, never `.plain`. Don't add a second haptic
  for the same tap: a button that also opens a menu on a long press gets a
  silent style (`pressHaptic: false`) and plays `TapHaptic` in its action,
  or the press and the menu would both buzz. Root pages leave room for it with
  `starhashTabBarClearance()`, scroll views shrink it with
  `starhashTabBarFollowsScroll()`, and a page hides it with
  `router.setHidesTabBar(_:on:)` while a screen is pushed or a search is
  open.
- Every empty state is `EmptyStateView`: a doodle (`EmptyDoodle`), a bold
  title and a line, all 20pt, centred in the space the page has with
  `starhashCentredOverTabBar()` (under its header, over the tab bar's top
  edge) and nothing else on the page but its header. The doodles are drawn
  by `python3 scripts/make_doodles.py` into the asset catalog, a light and
  a dark SVG each, in the palette's colours, hand-drawn after the owner's
  reference (rounded lines 7 wide, flat fills, a hand in a dark cuff, a
  few "look here" strokes, wavy lines only on the subject). Add a new one
  there, in the same style, and trim its canvas (`VIEWBOX`).
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
  except Nearby and the Face ID lock).
- The Face ID lock (`AppLock`, `StarHash/App/AppLock.swift`) is a window
  of its own over the app's, so it covers sheets; it asks on launch and
  after more than a minute away (a payment's trip to the call screen
  stays under that), covers the app in the app switcher, and its switch
  in Settings asks for Face ID before it turns on or off.
- Only dial a `Recipient` whose `isPayable` is true: SMS senders can be
  masked or have no number.
- Comments explain why, in Keaser's tone. Never use an em dash in comments,
  UI strings or docs.

## Named pieces

Names the owner uses for parts of the design; find them by these names.

| Name | What | Where |
| --- | --- | --- |
| **Soft Edge** | the one edge treatment: content fades and blurs under a bar | `starhashSoftEdge()`, `starhashSoftEdgeHeader { }` in `StarHash/Design/Glass.swift` |
| **Tab bar** (the custom nav) | GO Club's glass tab bar: Activity, Pay, Settings | `StarHash/App/StarHashTabBar.swift`, `NavigationHaptics` |
| **Total card** | the recipient screen's Total, Balance, Buy's codes and tiles: white in light, black glass in dark (Balance stays white in dark too) | `starhashTotalCard(in:)` in `Glass.swift` |
| **White glass, black glass** | every container | `starhashContainer(_:in:)` in `Glass.swift` |
| **Send Ripple** | shelved, not used: the wave up the screen that Pay once played as a recipient was chosen, a Metal shader over snapshots | `StarHash/Design/SendRipple.swift` (how to bring it back is at its top), `StarHash/Design/Shaders/SendRipple.metal` |

## Debug launch arguments (DEBUG builds)

| Argument | Effect |
| --- | --- |
| `-inMemory` | fresh in-memory store seeded with `SampleData` |
| `-emptyStore` | with `-inMemory`, no transactions (Activity's empty state) |
| `-buyEmpty` | with `-inMemory`: no codes, Buy's empty state |
| `-buyArrange` | with `-tab buy` and two or more pinned: arranging the pinned codes |
| `-buyPinned [n]` | with `-inMemory`: Buy's first n codes pinned (2 by default, sample codes added past the four defaults) |
| `-buyNew`, `-buyEdit`, `-buyDetails` | with `-tab buy`: the code editor, new or on the first code (`-buySymbols` opens its symbol grid), or the first code's details |
| `-splash` | the launch splash (any other debug argument skips it, so screenshots see their screen) |
| `-locked` | the Face ID lock's screen, without asking (any other debug argument keeps the lock away, so screenshots see their screen) |
| `-skipOnboarding`, `-resetOnboarding` | start on the tabs, or on onboarding |
| `-tab pay\|buy\|activity\|settings` | starting page |
| `-note`, `-reviewNote` | Shima's welcome note over Pay, as onboarding ends, or the two-week note that asks for a rating |
| `-appAppearance system\|dark\|light` | Settings' Appearance, saved at launch (not `-appearance`: a launch argument named after a key overrides its saved value for the whole run) |
| `-wallet mtn\|airtel\|none` | the main wallet (UserDefaults; none clears it; `-skipOnboarding` sets mtn when none) |
| `-onboardingPage 0...4` | onboarding screen (with `-resetOnboarding`): 0 the reel, 1 the wallet, 2 Contacts, 3 Nearby, 4 auto-verify |
| `-payAmount <n>` | amount on the keypad |
| `-payChosen <input>` | a recipient already chosen (Pay Again with no amount) |
| `-payPicker` | open the recipient picker |
| `-payChooser` | with `-payPicker`: the number chooser for the first contact with several numbers |
| `-payQuery <text>` | open the picker with this text in its search field |
| `-payBrowse` | with `-payPicker`: the picker with its search closed (title header) |
| `-payScroll <points>` | with `-payPicker`: the picker's list scrolled down, a section label pinned |
| `-payDetails <name>` | with `-payPicker`: the details sheet of the first contact whose name contains it |
| `-payToggleSearch` | with `-payPicker`: closes the picker's search after 2s and opens it 1.5s later, to record the header transitions |
| `-payShake` | taps Pay with nothing typed three times from 1.5s, about 0.77s apart, to record the amount's shake |
| `-payInk` | presses 8, 5, 3 and 7 on a schedule from 1.5s, to record the keypad's ink without a finger (simulator taps arrive late, in bursts) |
| `-nearbyHere` | turns Nearby on and places the phone at Kigali Heights, where the sample Pili-Pili and gym payments were made, for the picker's Nearby section |
| `-payPick <seconds>` | with `-payPicker`: chooses the first recent recipient after this long, to record the way back to the keypad |
| `-activityPeriod today\|week\|month\|year\|all` | Activity period (the D W M Y control; `all` or `allTime` for All Time) |
| `-openFirstTransaction` | open the newest transaction's details |
| `-confirmDelete` | with `-openFirstTransaction`: the delete question |
| `-openPendingTransaction` | open the newest pending transaction's details (Mark as Confirmed and Mark as Failed) |
| `-transactionScrolled` | with either of those: the details page scrolled to its foot, where the actions are |
| `-activitySearch <text>` | Activity search with this text |
| `-activityChartSelection last\|<index>` | chart callout on a bar |
| `-settingsScrolled` | with `-tab settings`: Settings scrolled to the bottom, to check the top edge |
| `-settingsPage whatsNew\|release\|terms\|privacy\|about\|guide\|guide2\|guideFailed\|guideVerified\|autoVerifyOff` | a Settings page (with `-tab settings`); guide is Auto-verify at step 1 or 2, guideFailed/guideVerified step 2 after its check; autoVerifyOff asks to turn it off |

Example:

    APPEARANCE=dark ./scripts/screenshot.sh pay-saved -inMemory -skipOnboarding -tab pay -payAmount 5000 -payQuery 020205
