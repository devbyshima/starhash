# Privacy

StarHash has no account and no tracking, and your payments stay on your iPhone. Its one server (`server/`, a Cloudflare Worker) keeps your profile photo, which goes with your QR code; your name and numbers for Show My Name, unless you turn it off; and an anonymous count of who uses StarHash. The app's own Privacy Policy, under **Settings › More**, is the one that applies; this page explains how the code backs it up.

## Permissions

| Permission | When it is asked | What it is for |
| --- | --- | --- |
| Contacts | During onboarding, or from **Enable contacts** | Picking who to pay. Contacts are read on the phone; StarHash keeps no copy of them, only the name and number on a payment you make |
| Location, while using the app | On onboarding's Nearby screen, or when you turn **Nearby** on in Settings | Suggesting who you paid where you are, and the map on a payment. Precise location is required; Always is never asked |
| Face ID | Only when you turn the lock on or off, and when it opens StarHash | Keeping your payments to yourself. StarHash only learns pass or fail |
| Camera | The first time you open the QR scanner | Reading a payment QR code. Nothing is recorded or kept; a code chosen from Photos is read the same way, through the system's picker |

Each permission screen in onboarding has a single **Continue** button that opens the system prompt.

## What is stored, and where

- **Payments**: one JSON file in the app's Application Support folder, holding who, how much, when, the status, and the fee, reference and balance when a message gives them. With Nearby on, a payment to a merchant code or to a number not in your Contacts also keeps where it was made. A file that cannot be read is set aside rather than overwritten, so it can be recovered.
- **Settings and Buy's codes**: the app's preferences. Recent recipients are not stored separately: they are read from the payments file.
- **Your profile**: the name and numbers you give for your QR code, in the app's preferences. They leave the phone in a code you show or share, and, while Show My Name is on, on StarHash's server (below). Your photo is kept on the phone too, and on StarHash's server whenever you have one.
- **Messages**: only the ones your own Shortcuts automation passes in, and who sent them. Anything that is not a MoMo or Airtel Money transaction is ignored and not kept, and so is a message held back as a possible scam.
- **Widgets**: with an App Group, Buy's codes and your wallet, which the Buy widget reads, in the group's preferences on the phone.

The payments file is protected until the phone is first unlocked after a restart, so a message that arrives while the phone is locked can still be logged.

The payments file and the preferences are part of your iPhone's own iCloud or computer backups, as your other app data is. **Delete All Data** in Settings erases them and starts StarHash again from onboarding.

## What leaves the phone

StarHash talks to one server of its own, `starhash.devbyshima.workers.dev` (`StarHashCloud`, and `server/` for the Worker), and only for these:

- **Your photo, with your QR code**: whenever you have a photo, it is uploaded under a random id (`cloudPhotoID`) that your code then carries, so whoever scans the code sees it beside your number. The photo is stored under that id alone; while Show My Name is on, your listing (next) names the id beside your name. A random key made on the phone is needed to replace or delete it: it is kept in the Keychain and in the iPhone's encrypted backups (never in iCloud Keychain), so an iPhone restored from a backup keeps it, and the server keeps only the key's hash, beside the photo in its D1 database. Removing your photo deletes it from the server; a change or delete that does not reach it (offline, say) is sent again each time StarHash opens, Delete All Data included.
- **Show My Name**: on unless you turn it off in Settings, under Your SIMs. Your name, your numbers (one SIM or two) and your photo's id, so someone who types one of your numbers to pay sees who it is. The numbers travel over HTTPS and are kept only as a keyed hash (an HMAC under a secret only the Worker holds), never as the numbers themselves. StarHash sends the listing when it changes and once a week while you use it. Turning Show My Name off, removing your numbers or Delete All Data deletes it from the server; a listing not sent again for 45 days (a lost iPhone, a deleted app) is deleted that night. Two iPhones listing one number show neither.
- **Looking up a number**: typing a Rwandan mobile number that is in neither your contacts nor your recent payments asks the server whose it is. The number goes in the request's body, never in a URL; the server compares its keyed hash with the listings and keeps nothing of the question.
- **Counting who uses StarHash**: once a day, a random id made on the first launch (`cloudInstallID`) and the app's version. The server keeps the id, the first and last day it was seen, and the version.

Nothing else is sent: no payment, no location, no contacts. There are no analytics or advertising packages. Beyond that, the only things that reach beyond the app are system ones you start:

- dialling a code through the iPhone's call prompt;
- opening GitHub in your browser (Request a Feature, the developer's note, the source code), Ko-fi (Support on Ko-fi, and Buy Shima a coffee in the developer's note), or the shared shortcut in Shortcuts;
- Apple's own rating prompt;
- the map on a payment's page, which Apple Maps draws from its own servers around the saved spot;
- **Export data**, which saves a file wherever you choose (Files, iCloud Drive, AirDrop), and sharing your QR code.

Smart categories and the reports' summaries use Apple's on-device model (Apple Intelligence, iOS 26 and later). It runs on the iPhone: the categories send it only a merchant's name, and the summaries the month's totals.

## Nearby, in detail

- Off until you turn it on. Refusing precise location turns it back off.
- Location is read only while you pay, and never delays the dial.
- Paying a contact never records where you were. If StarHash cannot read your Contacts, a payment to a number keeps no place, since it cannot tell; a payment to a merchant code still does.
- No place is ever named or looked up.
- Deleting a payment forgets its place, and turning Nearby off erases every saved place.

## Privacy manifest

`StarHash/App/PrivacyInfo.xcprivacy` declares no tracking and no tracking domains, and four collected data types: photos (the one you share with your code) and a device id (the random install id, for counting users), neither linked to you; and your name and phone number (Show My Name), linked to you. All but the install id are for the app's function. The one required-reason API it uses is UserDefaults, for the app's own settings (reason `CA92.1`).
