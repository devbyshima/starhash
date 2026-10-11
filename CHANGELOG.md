# Changelog

Every change people using StarHash would notice, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html), as [RELEASING.md](RELEASING.md) applies them to the app.

A version's section starts as `Unreleased` when its release branch is cut and gets its date when it ships to the App Store. Betas and release candidates (`v1.0.0-beta.1`, `v1.0.0-rc.1`) have no sections of their own: what they bring is in their version's.

## [Unreleased]

### Added

- Scan to Pay: the scan button on Pay reads a merchant's MoMo QR code or a friend's StarHash code, and Pay dials them with no recipient screen, the amount filled in when the code carries one. Photos reads a code from a picture.
- Your own QR code, for others to scan and pay you: your name and number, asked for in onboarding and kept in Settings' new Profile, with your photo. The code stands as a little tree of blocks that turns into the QR code at a tap, on Profile and in the scanner's My Code, and can be shared.
- Purchases of airtime, bundles, electricity, water and TV show as bought rather than sent, and payments sort into categories, by their names and, with Smart categories, by Apple Intelligence.
- Scam warnings: a message that looks like MoMo's but comes from someone's own number, or asks for money back, is never logged, and a notification warns you before you send anything back.
- Export and import: everything StarHash keeps as one file, in Settings' Your Data.
- Widgets: Buy's codes on the Home Screen, each its symbol and name, dialled in a tap without opening StarHash; Scan to Pay as a small widget and in Control Center.
- Kinyarwanda, chosen in the Settings app.
- What's New: the first launch after an update shows what the version brought, with a video of each new feature. It shows once, and never on a fresh install.
- Auto-verify reads MoMoAdvance's messages: when MTN's overdraft pays for a payment, its access fee joins that payment's fee, on a row of its own in the payment's details.
- Verify replaces Mark as Confirmed: paste the wallet's message for a payment, and StarHash confirms it (or marks it failed) only if the message is that payment's, with its real fee, reference and balance. Confirm Without Message stays as the last resort.

### Changed

- A new look: a white page with #F2F3F6 cards in light mode, #171717 with #3A3A3A cards in dark, and the green #00D957 as the accent and the brand, on the buttons, switches, chart, tab bar, app icon and launch. Cards and lists are flat; Liquid Glass stays on the tab bar, the header buttons, sheets and Buy's call buttons. Status colours: green for money in, yellow for pending, red for money out and deletes.
- Settings' rows each have an icon in StarHash's green glass style, and no line of description under them.
- Onboarding, Profile, My Code and the empty screens drop their explanatory lines, leaving the titles.
- Onboarding's number screen lines up with the screens around it, and Continue moves on with or without a number.
- Activity's period control offers the week, the month and the year; the day is gone.
- Pay's wallet switcher is now the logo above the keypad, where RWF was.
- A new launch animation: a stroke sweeps round the screen, and as it lands the StarHash star snaps together out of a dot.
- New drawings for the empty screens, hand-drawn in the accent's greens.
- A number saved in your Contacts always shows under the name you saved it with.

### Fixed

- Tapping a StarHash notification opens the app again, on what it is about.
- Onboarding sets up auto-verify's shortcut and automation again, on its last screens, a replay included, instead of skipping them when auto-verify had been set up before.

## [1.0.0] - Unreleased

The first release: pay with MTN MoMo or Airtel Money without typing USSD codes, and keep every payment in one place.

### Added

- Pay: type an amount, pick a contact, a recent recipient, a number or a merchant code, and StarHash dials the wallet's code. The PIN is only ever typed into the wallet's own prompt.
- MTN MoMo and Airtel Money, chosen during onboarding and switched from Pay.
- Buy: the codes dialled often (pending approvals, cash out, bundles), one tap each, with up to eight pinned to the top.
- Nearby: an opt-in suggestion of the numbers and codes paid at the place you are in.
- Activity: every payment by day, week, month or year, with a chart, search and each payment's details.
- Auto-verify: a Shortcuts automation passes the wallet's SMS to StarHash, which confirms each payment with its fee, reference and new balance, and fails one no message confirms within the hour.
- Notifications: reminders for pending payments, word of confirmed and received money, and weekly and monthly summaries, each chosen in Settings.
- Face ID lock, an Appearance setting (System, Dark or Light), and Shortcuts and Siri actions.
- No account, no server and no tracking: everything stays on the iPhone.

### Fixed

- The auto-verify guide has a step of its own for making the automation in Shortcuts (the one the shared shortcut was meant to bring on iOS 27 never appeared), and auto-verify waits for a real message through it before failing any payment on its own, so a missing automation no longer fails payments that went through.
- Auto-verify reads more MTN MoMo messages: payments through MoMo's partners (airtime, banks, savings) under the partner's own name, transfers whose message leaves out the number, and refunds.

[Unreleased]: https://github.com/devbyshima/starhash/compare/release/1.0...main
[1.0.0]: https://github.com/devbyshima/starhash/tree/release/1.0
