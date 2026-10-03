# StarHash

**MTN MoMo and Airtel Money (Rwanda) without the USSD menus.**

Native iOS · SwiftUI · iOS 18 and later · no third-party packages

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

Type an amount, pick who gets it, and StarHash dials your wallet's code for
you. MTN's or Airtel's own prompt asks for your PIN, as always; StarHash never sees it and
never moves money itself. Every payment is kept in Activity, and with a
Shortcuts automation MTN's confirmation SMS fills in the fee, the reference
and your new balance. No account, no login, no server: everything stays on
your iPhone.

Free and open source.

## Features

- **What's New and Replay Onboarding**: Settings lists every release with
  what it brought (`ReleaseHistory` in StarHashKit; add a release at the top
  when shipping), and can show the welcome screens again.

- **Tab bar**: a glass capsule floating at the foot of every page, with
  Activity on the left, Pay in the middle and Settings on the right. A lens
  slides to the page showing, with one heavy haptic as the page switches;
  a finger dragged along the bar carries it.
  The bar shrinks while a page scrolls down and steps aside for pushed
  screens and search. The button at the top left of Pay switches to Buy
  (coming soon) and back, and the bar's middle returns to whichever showed
  last. Your main wallet (MTN MoMo or Airtel Money) is picked once in
  onboarding and changed from the wallet button on Pay.
- **Pay**: a big amount on a keypad, Balance and Pay underneath. The
  button at the top right shows the main wallet's logo and switches wallet
  from a menu. Pay slides
  in the recipient screen with the keyboard already up on its numbers (one
  keyboard for codes, numbers and names), since most payments go to a
  merchant code typed on the spot. A number or code you
  have saved (a contact, or someone paid before) comes up at the top by
  name; anything else shows as typed. Recent recipients and contacts
  follow. A contact with several numbers asks which one. The total sits
  in a bar above the keyboard; matched letters show in blue. Picking someone dials at once: the iPhone's
  call prompt, showing the whole code, is the approval.
- **Fees**: shown only in Activity, once a payment is confirmed: from MTN's
  SMS, or worked out from the carriers' published prices when it is marked
  as confirmed by hand (`Tariff` in StarHashKit, sources inside). Pay shows no fees. The keypad takes up to
  10,000,000. Numbers starting 072 or 073 are Airtel, 078 and 079 MTN; a
  number on the other network from your wallet dials
  `*182*1*2*NUMBER*AMOUNT#`.
- **Activity**: payments grouped by day with a red arrow out and a green
  arrow in, a bar chart for Today, This Week, This Month, This Year or All
  Time with the total spent and MTN fees, and search across everything.
  Swipe a payment left for a red trash, or all the way across to delete it
  at once, as in Beam.
- **Nearby** (off until turned on, precise location only): each number or
  merchant code paid that is not in Contacts is remembered with where it
  was paid, and suggested at the top of the recipient list when you are
  back there. Places stay on the iPhone (out of backups), and turning
  Nearby off forgets them and every payment's location.
- **Transaction details**, a page of its own: who, how much, a category, the fee, date, time,
  carrier code, a map of where you paid (when Nearby is on), what you sent
  them this year, Pay Again, Mark as Confirmed and Delete.
- **Settings**: your profile and this year's totals, switches for saving
  transactions, contacts, Nearby and recent recipients, Ask before deleting
  from a menu or a transaction's page (also turned off from the delete
  question's Don't Ask Again), the auto
  verification guide, How StarHash Works and Privacy, and at the bottom
  Delete All Data, which erases everything StarHash keeps on the iPhone
  (transactions, recents, wallet, settings) and starts again from
  onboarding, like deleting an account.
- **Shortcuts and Siri**: Process Carrier SMS, Check MoMo Balance and Pay
  with StarHash actions.
- Light and dark appearance in a four-colour palette: every page blue in
  light mode (as Cash App is green) with near-black buttons, the near black
  #171717 in dark mode with blue buttons, and Space Grotesk. Sheets are clear Liquid Glass with bold titles
  on iOS 26 and later.

## USSD codes

MTN MoMo and Airtel Money share the `*182#` menu, so the codes are the same
from either wallet. Only which network counts as "other" changes.

| What | Code |
| --- | --- |
| Send to a number on your wallet's network | `*182*1*1*NUMBER*AMOUNT#` |
| Send to a number on the other network | `*182*1*2*NUMBER*AMOUNT#` |
| Pay a merchant code | `*182*8*1*CODE*AMOUNT#` |
| Check your balance, MTN MoMo | `*182*6*1#` |
| Check your balance, Airtel Money | `*182#` (the menu: no balance shortcut confirmed) |

The Airtel codes follow Airtel Rwanda's Airtel Money customer service
charter (`*182#`, `*182*8*1#` for merchants) and its note that `*182*1*2#`
sends between Airtel Money and MTN MoMo; they still need a check on a real
Airtel SIM. Auto verification reads MTN's SMS only.

Ten digits or more is a phone number (`+250 788 123 456` becomes
`0788123456`); fewer is a MoMo Pay merchant code. In the `tel:` link the `#`
is sent as `%23`.

## Auto verification

A payment dialled from StarHash is Pending until MTN's SMS confirms it
(Airtel Money payments stay Pending until marked as confirmed).
iOS does not let apps read messages, so a Shortcuts automation hands them
over. Settings, Auto-verify transactions sets it up in two steps, each
shown with a real screenshot of Shortcuts:

1. **Add Shortcut** opens the shared **StarHash SMS** shortcut
   (`StarHashShortcut.iCloudLink`) on Shortcuts' Add screen. It is the
   Process Carrier SMS action fed the shortcut's input, with its automation
   built in (iOS 27): when a message containing **RWF** arrives (every
   M-Money message does), run without asking. Nothing to build. iOS
   announces each run until **Notify When Run** is turned off on the
   automation, a setting a shortcut file cannot carry, so the step list
   says so.
2. **Verify Shortcut** runs it with a sample message (never saved) and
   comes back through x-callback-url. Auto-verify only turns on once this
   works.

The same shortcut ships in the app (`StarHash/Resources/StarHash SMS.shortcut`,
from `scripts/make_shortcut.py`) as a fallback. Share the shortcut again and
update the link after changing it: a link is a copy of the shortcut as it
was when shared.

Each MoMo message then confirms the matching pending payment (same amount
and number, within six hours) or is logged as a new transaction. A message
applied twice is only logged once.

## Build

Requires Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

    brew install xcodegen
    xcodegen generate
    open StarHash.xcodeproj

From the command line:

    ./scripts/build.sh        # simulator build, prints errors and our warnings only
    ./scripts/test.sh         # StarHashKit tests, run on the Mac (no simulator)
    ./scripts/screenshot.sh pay -inMemory -skipOnboarding -tab pay -payAmount 5000

Screenshots land in `screenshots/<appearance>/<name>.png`;
`APPEARANCE=light` takes the light one. Dialling needs a real iPhone: on the
simulator Pay shows the code in an alert instead.

## Layout

- `Packages/StarHashKit` - models, the store, persistence, the USSD codes,
  the SMS parser and all pure logic.
- `StarHash` - the SwiftUI app and its App Intents.

See `AGENTS.md` for conventions and the debug launch arguments.

## License

StarHash is free and open source, under the
[GNU General Public License v3.0](LICENSE). You may use, study, share and
change it; anything you distribute that is built on it must be under the same
license, with its source.

## Credits

Space Grotesk by Florian Karsten, under the SIL Open Font License 1.1
(`StarHash/Resources/Fonts/SpaceGrotesk.ttf`).

The MTN and Airtel logos on Pay's wallet switcher and onboarding are trademarks of MTN Group
and Airtel Africa, shown only to tell the two wallets apart; StarHash is not
affiliated with either. The files come from Wikimedia Commons
(`MTN_2022_logo.svg`, the same drawing as on mtn.com, with MTN's yellow
added inside the oval; `Airtel_Africa_logo.svg`).
