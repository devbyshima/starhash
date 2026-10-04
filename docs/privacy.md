# Privacy

StarHash has no account, no server and no tracking. What it keeps stays on your iPhone. The app's own Privacy Policy, under **Settings › More**, is the one that applies; this page explains how the code backs it up.

## Permissions

| Permission | When it is asked | What it is for |
| --- | --- | --- |
| Contacts | During onboarding, or from **Enable contacts** | Picking who to pay. Contacts are read on the phone; StarHash keeps no copy of them, only the name and number on a payment you make |
| Location, while using the app | On onboarding's Nearby screen, or when you turn **Nearby** on in Settings | Suggesting who you paid where you are, and the map on a payment. Precise location is required; Always is never asked |
| Face ID | Only when you turn the lock on or off, and when it opens StarHash | Keeping your payments to yourself. StarHash only learns pass or fail |

Each permission screen in onboarding has a single **Continue** button that opens the system prompt.

## What is stored, and where

- **Payments**: one JSON file in the app's Application Support folder, holding who, how much, when, the status, and the fee, reference and balance when a message gives them. With Nearby on, a payment to a merchant code or to a number not in your Contacts also keeps where it was made. A file that cannot be read is set aside rather than overwritten, so it can be recovered.
- **Settings and Buy's codes**: the app's preferences. Recent recipients are not stored separately: they are read from the payments file.
- **Messages**: only the ones your own Shortcuts automation passes in. Anything that is not a MoMo or Airtel Money transaction is ignored and not kept.

The payments file is protected until the phone is first unlocked after a restart, so a message that arrives while the phone is locked can still be logged.

The payments file and the preferences are part of your iPhone's own iCloud or computer backups, as your other app data is. **Delete All Data** in Settings erases them and starts StarHash again from onboarding.

## What leaves the phone

StarHash has no networking code, no analytics, no advertising and no third-party packages. The only things that reach beyond the app are system ones you start:

- dialling a code through the iPhone's call prompt;
- opening GitHub in your browser (Request a Feature, the developer's note, the source code) or the shared shortcut in Shortcuts;
- Apple's own rating prompt;
- the map on a payment's page, which Apple Maps draws from its own servers around the saved spot.

## Nearby, in detail

- Off until you turn it on. Refusing precise location turns it back off.
- Location is read only while you pay, and never delays the dial.
- Paying a contact never records where you were. If StarHash cannot read your Contacts, a payment to a number keeps no place, since it cannot tell; a payment to a merchant code still does.
- No place is ever named or looked up.
- Deleting a payment forgets its place, and turning Nearby off erases every saved place.

## Privacy manifest

`StarHash/App/PrivacyInfo.xcprivacy` declares no tracking, no tracking domains and no collected data. The one required-reason API it uses is UserDefaults, for the app's own settings (reason `CA92.1`).
