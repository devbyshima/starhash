# Changelog

Every change people using StarHash would notice, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html), as [RELEASING.md](RELEASING.md) applies them to the app.

A version's section starts as `Unreleased` when its release branch is cut and gets its date when it ships to the App Store. Betas and release candidates (`v1.0.0-beta.1`, `v1.0.0-rc.1`) have no sections of their own: what they bring is in their version's.

## [Unreleased]

### Added

- Your photo with your QR code: people who scan it see your photo beside your number (a photo saved in their Contacts comes first). It is kept on StarHash's new small server under a random id, never with your number, and removing your photo deletes it there. StarHash also counts how many people use it, by a random id once a day; the privacy policy says so.
- Two SIMs: say so in Settings and give the other number, and money between your own SIMs is filed under Your own accounts, counted as neither spent nor received. The other number is part of your profile: Profile shows and changes it, the backup carries it, and Settings asks for it only until it is in, putting the keyboard away once it is.
- A Nearby suggestion passed over five times in a row stops being suggested; picking it keeps it, and paying it any other way brings it back.
- Money paid to MTN itself shows as bought: bundles and packs (by MTN Rwandacell, Voice Pack MTN, Data Bundle MTN) and airtime, from MoMo's own messages. Topping up MoMo's virtual card, or taking money back off it, shows as a move between your own accounts and counts as neither spent nor received; a new category, Your own accounts, does the same for any payment you mark.
- MTN Virtual Card (*182*2*6#) is one of Buy's built-in codes, added once to lists saved before it.
- Scan to Pay: the scan button on Pay reads a merchant's MoMo QR code or a friend's StarHash code, and Pay dials them with no recipient screen, the amount filled in when the code carries one. Photos reads a code from a picture. A code other than StarHash's (a MoMo USSD code, a merchant's sticker, a bare number) shows as its number or code alone, with no picture, since it says nothing more.
- Your own QR code, for others to scan and pay you: your name and number, asked for in onboarding and kept in Settings' new Profile, with your photo. The code stands as a little tree of blocks, turning slowly, that turns on into place and flattens into the QR code at a tap, on Profile and in the scanner's My Code. Share Code sends StarHash's own version of it, with the mark in the middle.
- Purchases of airtime, bundles, electricity, water and TV show as bought rather than sent, and payments sort into categories, by their names and, with Smart categories, by Apple Intelligence.
- Scam warnings: a message that looks like MoMo's but comes from someone's own number, or asks for money back, is never logged, and a notification warns you before you send anything back.
- Export and import: everything StarHash keeps as one file, in Settings' Your Data.
- A long press on StarHash's icon offers Scan to Pay, Balance (for your wallet), Buy and Activity, in the language chosen in StarHash.
- Widgets, four of them after the owner's reference: Buy, tiles that dial your codes, two (small) or four (medium), which you choose in Edit Widget (any left unchosen show Buy's next codes), and Quick Pay, a Pay pill with Scan and Balance under it (small) or Scan, Balance, Buy and Activity (medium). Scan to Pay stays in Control Center.
- English, French and Kinyarwanda, chosen in StarHash's own Settings (Language) and changed at once, dates and month names included. The widgets and iOS's own prompts keep the iPhone's language.
- What's New: the first launch after an update shows what the version brought, with a video of each new feature. It shows once, and never on a fresh install.
- Auto-verify reads MoMoAdvance's messages: when MTN's overdraft pays for a payment, its access fee joins that payment's fee, on a row of its own in the payment's details.
- Verify replaces Mark as Confirmed: paste the wallet's message for a payment, and StarHash confirms it (or marks it failed) only if the message is that payment's, with its real fee, reference and balance. Confirm Without Message stays as the last resort.
- Support on Ko-fi, in Settings' More, and Buy Shima a coffee in the developer's note, each opening Shima's Ko-fi page in the browser. StarHash stays free.

### Changed

- A photo you pick for your profile opens on a Move and Scale screen first: pinch to resize, drag to frame it in the circle, then Choose.
- With two SIMs, Profile shows both numbers in one box.
- Pending payments are yellow again, beside red for failed and green for confirmed.
- The tab bar is a little shorter, so its highlight sits the same distance from every edge.
- Onboarding's screens change visibly: the screen before drifts up into a blur as it fades, and the new title and line rise in word by word.
- Onboarding asks for your photo after your name and number, for the people who scan your code. On "Confirm payments automatically", Set Up and Maybe Later sit side by side where Set Up was.
- Activity's transactions and the recipient list have a line under each row, from where its words start to where they end. Report's title and its week, month and year control sit up beside the back button, and the recipient screen's Total sits where the tab bar does.
- Buy's codes and pinned tiles are outlined cards, as a transaction's details and Settings are.
- Pay: the wallet's logo sits on its own above the keypad, Balance is a Liquid Glass button in light and dark, and a number saved with no name shows the StarHash mark where a "#" was.
- The developer's note is in StarHash's green, with deep green words, so it stands apart from the page under it.
- Activity lists every transaction by month under a large title, each with the same tile the recipient list uses (a contact's photo, their initials, a shop for a merchant, or the carrier's logo for airtime and bundles), and its number, date, time and status. The spending summary and chart move to a Report page, from the chart button beside search.
- A transaction's page puts its picture, name, date and amount down the middle, its details in outlined cards grouped by what they say (the category a menu under Status), and Pay Again, Verify, Mark as Failed and Delete in one list.
- Settings' cards are outlined, with each section's title above its card, shorter rows and even margins on both sides. Every separator in the app is a solid line.
- A new look after the owner's references: a white page in light mode and #171717 in dark, #F5F6F5 and #262626 for what is filled, hairline outlines, and StarHash's green #64D27B with the deep green #091D11 on it for buttons, switches, the chart and the mark; red stays only for deletes and failures. The QR code icon is redrawn.
- A new look: a #F2F3F6 page with white cards in light mode, black with #171717 cards in dark, and the green #00D957 as the accent and the brand, on the buttons, switches, chart, tab bar, app icon and launch. Cards and lists are flat; Liquid Glass stays on the tab bar, the header buttons, sheets and Buy's call buttons. Status colours: green for money in, yellow for pending, blood red for money out and deletes.
- Settings' rows each have a green icon; a row's description shows when you tap its icon, and hides at the next tap.
- StarHash's own icons everywhere: one soft, rounded set drawn for the app, in place of the system's symbols, in the tab bar, buttons, menus, Settings, Buy's codes and the widgets.
- Profile, My Code, the empty screens and a few sheets drop their explanatory lines, leaving the titles; onboarding keeps a line under each title.
- Onboarding's number screen lines up with the screens around it, and Continue moves on with or without a number.
- Activity's period control offers the week, the month and the year; the day is gone.
- Auto-verify's automation step asks only to turn the StarHash SMS automation on, and the setup's pictures are smaller, so each step fits without scrolling.
- Pay's wallet switcher is now the logo above the keypad, where RWF was.
- Buttons with words show the words alone, without an icon: Balance, Delete, Share Code, Photos, My Code, Dial, Unlock and the transaction's category.
- The recipient screen's Total floats over the list as Liquid Glass, clear of the rows in light mode.
- Every notification is on to begin with, Confirmed payments and Money received included.
- A new launch animation: a stroke sweeps round the screen, and as it lands the StarHash star snaps together out of a dot.
- New drawings for the empty screens, hand-drawn in the accent's greens.
- A number saved in your Contacts always shows under the name you saved it with.

### Fixed

- Tapping a StarHash notification opens the app again, on what it is about.
- Onboarding sets up auto-verify's shortcut and automation again, on its last screens, a replay included, instead of skipping them when auto-verify had been set up before.
- This Week runs Monday to Sunday and holds all of the week's payments, today's included, whatever region the iPhone is set to; on a Sunday it held only that day where weeks start on Sunday.
- Onboarding's auto-verify screen keeps Set Up level with Continue on the screens before it.

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
