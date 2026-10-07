# Changelog

Every change people using StarHash would notice, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html), as [RELEASING.md](RELEASING.md) applies them to the app.

A version's section starts as `Unreleased` when its release branch is cut and gets its date when it ships to the App Store. Betas and release candidates (`v1.0.0-beta.1`, `v1.0.0-rc.1`) have no sections of their own: what they bring is in their version's.

## [Unreleased]

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
