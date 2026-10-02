# StarHash

**MTN MoMo (Rwanda) without the USSD menus.**

Native iOS · SwiftUI · iOS 18 and later · no third-party packages

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

Type an amount, pick who gets it, and StarHash dials the MoMo code for you.
MTN's own prompt asks for your PIN, as always; StarHash never sees it and
never moves money itself. Every payment is kept in Activity, and with a
Shortcuts automation MTN's confirmation SMS fills in the fee, the reference
and your new balance. No account, no login, no server: everything stays on
your iPhone.

Free and open source.

## Features

- **What's New and Replay Onboarding**: Settings lists every release with
  what it brought (`ReleaseHistory` in StarHashKit; add a release at the top
  when shipping), and can show the welcome screens again.

- **Side menu**: the menu button at the top left of every page, or a swipe
  in from the left edge, slides the page aside, as X does. At the top, your
  photo (from Contacts, when your number is saved there with one) or
  initials and your MoMo number, asked for once in onboarding (change it in
  Settings, My Wallets). Then Pay, Buy (coming soon) and Activity, and
  Settings and Help at the bottom.
- **Pay**: a big amount on a keypad, Balance and Pay underneath. Pay slides
  in the recipient screen with the number pad already up, since most
  payments go to a merchant code typed on the spot. A number or code you
  have saved (a contact, or someone paid before) comes up at the top by
  name; anything else shows as typed. Recent recipients and contacts
  follow. A contact with several numbers asks which one. The amount sits
  above the keyboard with Pay. Picking someone dials at once: the iPhone's
  call prompt, showing the whole code, is the approval.
- **Fees**: shown only in Activity, and only once MTN's SMS has confirmed a
  payment and given its fee. Pay shows no fees. The keypad takes up to
  10,000,000. Numbers starting 072 or 073 are Airtel and dial
  `*182*1*2*NUMBER*AMOUNT#`.
- **Activity**: payments grouped by day with a red arrow out and a green
  arrow in, a bar chart for Today, This Week, This Month, This Year or All
  Time with the total spent and MTN fees, and search across everything.
- **Transaction details**: who, how much, a category, the fee, date, time,
  carrier code, a map of where you paid (when Nearby is on), what you sent
  them this year, Pay Again, Mark as Confirmed and Delete.
- **Settings**: your profile and this year's totals, My Wallets (MTN MoMo
  marked Main; Airtel Money and banks coming soon), switches for saving
  transactions, contacts, Nearby and recent recipients, the auto
  verification guide, How StarHash Works and Privacy.
- **Shortcuts and Siri**: Process Carrier SMS, Check MoMo Balance and Pay
  with StarHash actions.
- Light and dark appearance, monochrome, with Liquid Glass on iOS 26 and
  later.

## USSD codes

| What | Code |
| --- | --- |
| Send to an MTN number | `*182*1*1*NUMBER*AMOUNT#` |
| Send to an Airtel number (072, 073) | `*182*1*2*NUMBER*AMOUNT#` |
| Pay a merchant code | `*182*8*1*CODE*AMOUNT#` |
| Check your balance | `*182*6*1#` |

Ten digits or more is a phone number (`+250 788 123 456` becomes
`0788123456`); fewer is a MoMo Pay merchant code. In the `tel:` link the `#`
is sent as `%23`.

## Auto verification

A payment dialled from StarHash is Pending until MTN's SMS confirms it.
iOS does not let apps read messages, so a Shortcuts automation hands them
over. Settings, Auto-verify transactions sets it up in two steps, each
shown with a real screenshot of Shortcuts:

1. **Add Shortcut** opens the shared **StarHash SMS** shortcut
   (`StarHashShortcut.iCloudLink`) on Shortcuts' Add screen. It is the
   Process Carrier SMS action fed the shortcut's input, with its automation
   built in (iOS 27): when a message containing **RWF** arrives (every
   M-Money message does), run without asking. Nothing to build.
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
