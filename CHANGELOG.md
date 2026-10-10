# Changelog

Every change people using StarHash would notice, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html), as [RELEASING.md](RELEASING.md) applies them to the app.

A version's section starts as `Unreleased` when its release branch is cut and gets its date when it ships to the App Store. Betas and release candidates (`v1.0.0-beta.1`, `v1.0.0-rc.1`) have no sections of their own: what they bring is in their version's.

## [Unreleased]

### Added

- Scan to Pay: the scan button on Pay reads a merchant's MoMo QR code or a friend's StarHash code, and Pay dials them with no recipient screen, the amount filled in when the code carries one. Photos reads a code from a picture.
- Your own QR code, for others to scan and pay you: your name and number, asked for in onboarding and kept in Settings' new Profile, where the code can be shared. Profile shows your name large under a face you pick ("Pick your vibe").
- Reports: each month in large, bold figures, day by day, broken down by category and recipient, compared with the month before, with a summary written on the iPhone (by Apple Intelligence on iOS 26 and later). The weekly and monthly summaries open it.
- Purchases of airtime, bundles, electricity, water and TV show as bought rather than sent, and payments sort into categories, by their names and, with Smart categories, by Apple Intelligence.
- Scam warnings: a message that looks like MoMo's but comes from someone's own number, or asks for money back, is never logged, and a notification warns you before you send anything back.
- Export and import: everything StarHash keeps as one file, in Settings' Your Data.
- Widgets: Buy's codes on the Home Screen with nothing else on the card, each dialled in a tap and paged with More without opening StarHash, and Scan to Pay in Control Center.
- Kinyarwanda, chosen in the Settings app.
- What's New: the first launch after an update shows what the version brought, with a video of each new feature. It shows once, and never on a fresh install.
- Auto-verify reads MoMoAdvance's messages: when MTN's overdraft pays for a payment, its access fee joins that payment's fee, on a row of its own in the payment's details.
- Verify replaces Mark as Confirmed: paste the wallet's message for a payment, and StarHash confirms it (or marks it failed) only if the message is that payment's, with its real fee, reference and balance. Confirm Without Message stays as the last resort.

### Changed

- A new blue, #3020FE, with white text on it in light mode, and new status colours: green for money in, yellow for pending, red for money out and deletes.
- Pay's wallet switcher is now the logo above the keypad, where RWF was, and Balance is clear glass in light mode.
- A new launch animation: a stroke sweeps round the screen, and as it lands the StarHash star snaps together out of a dot.
- New drawings for the empty screens, hand-drawn in the page's own blues.
- A number saved in your Contacts always shows under the name you saved it with.

### Fixed

- Tapping a StarHash notification opens the app again, on what it is about.

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
