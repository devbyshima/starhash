# The StarHash Architecture

<https://github.com/devbyshima/starhash>

## Introduction

StarHash is an iPhone app for paying with MTN MoMo and Airtel Money in Rwanda. It turns an amount and a recipient into the wallet's USSD code and hands it to the phone app, so the iPhone's call prompt is the approval and the carrier asks for the PIN. It then keeps every payment in one file on the phone, confirms each one from the wallet's SMS through a Shortcuts automation, and works out reports from them.

Everything that can be tested lives in one Foundation-only Swift package, `StarHashKit`. The app, the widgets and the App Intents are thin SwiftUI and system layers over it. A small Cloudflare Worker holds the only data that leaves the phone: the photo an owner shares with their QR code, the names behind Show My Name, and an anonymous daily count of installs.

## What StarHash is NOT

- StarHash is not a wallet. It never holds money, never sees a PIN and never moves anything itself: it only dials the code the owner approves.
- StarHash is not connected to MTN or Airtel. It knows a payment went through only from the wallet's own SMS, handed to it by the owner's Shortcuts automation, or from the owner by hand.
- StarHash is not a cloud service. Payments never reach the server.

## Major Components

### StarHash Core [SWIFT PACKAGE]

#### [StarHashKit](Packages/StarHashKit)

Foundation and Observation only, a `public` interface, iOS 18 and macOS 15, tested on the Mac by `scripts/test.sh` with Swift Testing (`Packages/StarHashKit/Tests`). The app target has no tests of its own, so any rule worth testing belongs here.

- **Choosing who to pay:** `RecipientList` (the picker's Nearby, saved matches, Recent and Contacts for a search, each person once by `Recipient.Identity`) and `RecipientSearch`.
- **Money and people:** `Recipient` (a name, the digits and a kind: ten or more digits is a phone, fewer a merchant code; `network` from the prefix, `isPayable`), `Transaction` (direction, status, fee, MoMoAdvance's access fee, wallet, category), `Money`, `AmountInput`, `Tariff` (the carriers' published fees).
- **Dialling:** `USSD` (`payment(to:amount:from:)`, `balance`, `telURL`), `USSDShortcut` and `USSDShortcutList` (Buy's codes), `PaymentQR` (scanned codes and StarHash's own `starhash://pay` link), `StarHashLink` (every starhash:// link, made and read in one place: the router, quick actions, notifications, widgets and the shortcut's callback).
- **Reading messages:** `CarrierSMS` (`read`, one entry for the three kinds of `WalletMessage`, over `parse`, `parseFailure` and `parseOverdraft` for MTN's and Airtel's SMS), `ScamCheck`, `Verification`, and `AutoVerify`: `receive`, everything a message does in one place (the sample, Off, scam warnings, the store, expiry), returning an `Outcome`; the setup's `check` (`beginCheck`, `checkReturned`); the one-hour window; `looksBroken`.
- **The store:** `StarHashStore`, `@MainActor @Observable`, one JSON file and every rule for matching a message to a payment (`apply` says what it did: `Applied`), retries (`retryWindow`), own transfers, expiry and Verify. What the owner settles by hand goes through its verbs (`markFailed`, `confirmByHand`, `chooseCategory`), and so do the categories StarHash works out (`categorizeByRules`, `fillCategory`) and the place a payment was made (`attachPlace` with a `PlaceTicket`); there is no way to replace a transaction whole.
- **The owner:** `Owner` (name, default and other SIM, wallet, and the rules between them, with `NumberProblem` for why a number is refused), `OwnerWallets`, `OwnAccounts`.
- **Settings' choices:** `Preferences` (every switch and notification choice, under its key with its one default) and `NotificationPlan.Settings.stored`.
- **The first run:** `FirstRun` (onboarding's screens, the one left saved by name, and the sheets that open after it, one at a time, in order).
- **Reading the history:** `ActivitySummary` (totals, the chart's buckets, day and month groups, search), `SpendingReport` (the Report page: comparison with the period before and with the usual, the summary's insight, categories, top payments, payment types, each day spent on and the key days), `TransactionCategory` and `TransactionCategorizer`.
- **Everything else:** `NotificationPlan` (what each local notification says and when), `Nearby` (and `remembersPlace`: a shop's place always, a number's only when it is no contact), `StarHashBackup` and `OwnerProfile`, `WidgetSnapshot`, `FeatureFlag` and `ReleaseChannel`, `ReleaseHistory` and `WhatsNew`, `StarHashLanguage` with `String(starhash:)` and `String(kit:)`.

### The App [SWIFTUI]

#### [StarHash/App](StarHash/App)

The lifecycle and the wiring. `AppEnvironment` holds the single `StarHashStore`, `Owner` and `AppRouter` (tabs, the open transaction, `starhash://` and `tel:` links). `StarHashApp` reloads the store, runs `AutoVerify.expireUnconfirmed`, syncs notifications (`StarHashNotifications`) and publishes the widgets' snapshot. Also `StarHashCloud` (the Worker's client), `AppLock` (the Face ID lock), `QuickActions`, `SmartCategories` (Apple Intelligence on iOS 26), `FeatureFlags`, `DebugLaunch` and `SampleData`.

#### [StarHash/Features](StarHash/Features)

One folder per part of the app:

- **Pay:** `PayView` and its keypad, `RecipientPickerView` (contacts, recents, Nearby, a typed number), `QRScannerView`, `PaymentServices` (`USSDDialer`, `PaymentLocation`).
- **Activity** (the Transactions tab): `ActivityView` (the period control, `ActivitySummaryCard`'s chart, every transaction by month), `TransactionDetailPage`, `VerifyPaymentSheet`, and the Report: `ReportPage`, `ReportCards` (the summary sentence, the cards, the Payment Types orbs, the By Day calendar and `ReportFlowLayout`, which sets the sentences word by word), `ReportExport` (the PDF) and `ReportGallery` (Debug only: every sentence length, in every language).
- **Buy**, **Profile** (the owner's photo, numbers and `QRTreeView`), **Settings** (`SettingsView`, `AutoVerificationGuide`, `NotificationSettingsView`, `LicencesView`), **Onboarding**, **Safety** and **WhatsNew**.

#### [StarHash/Design](StarHash/Design)

The design system: `Theme` (every colour, `StarHashMetrics`, Space Grotesk), `Glass` (Liquid Glass with an iOS 18 fallback, containers, Soft Edge), `SheetKit`, `Components`, `Icons` (Keyline icons as custom symbols), `ShadowAvatar`, `DistortionWave` (a Metal shader over snapshots in `Shaders/`, the wave that turns a confirmation sheet into its `SheetOutcome`), haptics and the glass segmented control.

#### [StarHash/Intents](StarHash/Intents)

App Intents: `ProcessCarrierSMSIntent` (what the Shortcuts automation runs on each SMS: `AutoVerify.receive`, then the notification its outcome is worth), `CheckBalanceIntent`, `OpenPayIntent`, and `StarHashShortcut` (the bundled shortcut, its links and its test run).

### Extensions [WIDGETKIT]

#### [StarHashWidgets](StarHashWidgets)

Buy's codes as Home Screen tiles, Quick Pay, and Scan to Pay in Control Center. It shares `Theme.swift`, `Icons.swift` and the mark with the app, and reads `WidgetSnapshot` through an App Group, which needs a paid team: until then it shows the default codes.

### Server [TYPESCRIPT]

#### [server](server)

A Cloudflare Worker with one D1 database: `/v1/photos/:id` for the photo shared with a QR code, `/v1/directory` and `/v1/directory/lookup` for Show My Name (numbers kept only as HMACs), and `/v1/ping` for the daily count. `schema.sql` defines the tables; `stats/` holds the usage queries.

## External Pieces

- **The carriers:** the USSD codes and SMS formats StarHash reads are MTN Rwanda's and Airtel Rwanda's, written down in [Codes and fees](docs/codes-and-fees.md).
- **Shortcuts:** the "StarHash SMS" shortcut, made and signed by `scripts/make_shortcut.py` for the bundle id and team and bundled in the app. A shortcut file cannot give it StarHash's icon, so auto-verify's guide has the owner choose it in Shortcuts.
- **Shipped with the app:** Space Grotesk (SIL OFL 1.1), Keyline Icons (MIT) and DiceBear's Shadows silhouettes (CC0 1.0), each listed under Licences in the app with its licence bundled.

## Tooling

`scripts/`: `build.sh` (XcodeGen, then a simulator build), `test.sh`, `screenshot.sh` (a simulator screenshot from debug launch arguments), `make_shortcut.py`, `make_icons.swift`, `make_doodles.py`, `make_avatars.py`, `make_whats_new_video.swift`, `bump_version.sh` and `check_release.sh`. The Xcode project is generated from `project.yml` and never committed.

# Workflows

## What does a payment look like?

1. On Pay, the keypad edits an `AmountInput`. Pay opens `RecipientPickerView`, unless Pay Again, a `starhash://pay` link or a scanned code has already chosen the recipient.
2. `PayView` records a pending transaction in `StarHashStore` (a retry within five minutes reuses it), builds the code with `USSD.payment` against `Owner.wallet`, and hands its `tel:` URL to the phone app.
3. The iPhone's call prompt shows the code, and the wallet asks for the PIN.

## What does a confirmation look like?

1. The wallet's SMS arrives, and the owner's automation runs the "StarHash SMS" shortcut, which calls `ProcessCarrierSMSIntent(message:sender:)` without opening the app.
2. The intent hands it to `AutoVerify.receive`, which holds back a look-alike with `ScamCheck`, reads the message with `CarrierSMS.read`, and calls the store's `apply`, `applyFailure` or `applyOverdraft`. The intent posts what `NotificationPlan.after` makes of the outcome.
3. `apply` confirms the closest open payment with the same amount, wallet and number or code within six hours, taking the fee, reference and balance from the SMS; with none, it adds the movement as a new transaction. `AutoVerify.expireUnconfirmed` then fails what no message confirmed within the hour, and `StarHashNotifications` reschedules.
4. By hand, the owner pastes the message into Verify (`StarHashStore.verify`), or uses Confirm Without Message (the fee from `Tariff`).

## What does the Development flow look like?

Work goes on `main`, unfinished work behind a `FeatureFlag`. `./scripts/build.sh` and `./scripts/test.sh` before each pull request, and `./scripts/screenshot.sh` for every screen changed, in light and dark. CI only builds and tests. The branch rules are in [CONTRIBUTING.md](CONTRIBUTING.md).

## What does the Release flow look like?

`release/X.Y` branches build the Release configuration for TestFlight and the App Store and take fixes only, merged forward into `main`. Each upload raises the build number. The steps are in [RELEASING.md](RELEASING.md).

# Invariants

Things the code relies on that are easy to break:

- **Money:** an amount is always positive whole RWF; the direction gives the sign. A failed payment counts for nothing, a pending one counts, money moved between the owner's own accounts is neither spent nor received, and a fee counts only on a confirmed payment. `Transaction.counts`, `countsAsSpent` and `countedFee` hold that rule; `ActivitySummary`, `SpendingReport` and `NotificationPlan` ask them and never filter for it themselves.
- **Fees** come only from the SMS, or from `Tariff` when a payment is confirmed by hand. MoMoAdvance's access fee is kept apart and added on top.
- **Matching:** a message applied twice is caught by its reference or its moment. A payment failed for want of a message stays open to a late one; one failed by hand is never revived. Only a pending payment is marked failed by hand. A category chosen by hand is never changed: the store's verbs hold these, so a screen cannot skip them.
- **Dialling:** only an `isPayable` recipient is dialled: a Rwandan mobile number or a merchant code. iOS dials on the default voice line; StarHash cannot choose the SIM.
- **The store** is one instance on the main actor, shared by views and intents. A file it cannot read is set aside, never overwritten.
- **The owner's** name, numbers and wallet go through `Owner`, never `UserDefaults` or `@AppStorage` directly.
- **Settings' choices** each have one default, in `Preferences`: views read them with `@AppStorage(Preferences.x)`, everything else with `Preferences.x.value()`, and neither writes a default of its own.
- **Delete All Data** keeps the directory's record of what it last sent through the wipe, so the owner's Show My Name listing is deleted from the server after it.
- **Text** built at run time goes through `String(starhash:)` (`String(kit:)` in the package), never `String(localized:)`, so the language chosen in Settings applies at once. There are three catalogs: the app's, the package's and the widgets'.
- **The shortcut contract:** `ProcessCarrierSMSIntent`'s name and parameters, the bundle id and the team are written into the shared shortcut, and the app builds with `ENABLE_DEBUG_DYLIB: NO`, or Shortcuts cannot run the action.
- **Shared sources:** `Theme.swift`, `Icons.swift` and the mark compile into the widgets too, so they hold nothing app-only.
- **Colours** come only from `Theme.swift`.

## License

StarHash is source-available under the [PolyForm Noncommercial License 1.0.0](LICENSE).
