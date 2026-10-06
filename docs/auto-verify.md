# Auto-verify

A payment dialled from StarHash is **Pending** until your wallet's SMS confirms it. iOS does not let apps read messages, so a Shortcuts automation hands each one to StarHash, which confirms the matching payment with its fee, reference and new balance.

> [!NOTE]
> Auto-verify only works with **Save transactions** on, and StarHash keeps nothing from a message that is not a MoMo or Airtel Money transaction.

## Set it up

Open **Settings › Auto-verify transactions**, or choose **Set Up** on the last onboarding screen. The guide has two steps, each shown with a screenshot of Shortcuts.

1. **Add the StarHash SMS shortcut and its automation.** StarHash opens the shared shortcut on Shortcuts' Add screen. It runs the **Process Carrier SMS** action on the message it is given. Then make the automation that hands it every message: **Automation › + › Message**, Message Contains **RWF**, **Run Immediately**, **Notify When Run** off, then pick **StarHash SMS**. The shared shortcut carries no working automation, on iOS 27 either, so it is always made by hand.
2. **Verify the shortcut.** StarHash runs it with a sample message (never saved) and waits for it to come back. Auto-verify only turns on once this works; if it does not, the guide offers Try Again. This checks the shortcut, not the automation: if payments still go unconfirmed, check the automation is in Shortcuts' **Automation** tab.

Every MTN MoMo and Airtel Money transaction message contains "RWF", which is why the automation keys on it.

## How a message is matched

Each message either confirms a pending payment or is logged as a new one.

- **A match** has the same amount and the same number or merchant code, was dialled within six hours of the message, and came from the same wallet. When several match, the closest in time wins.
- **A message without the number or code** (some merchant and cross-network messages leave it out) settles for a pending payment of the same kind. It can fill in a missing name but never replaces one.
- **No match**: the message is logged as a new confirmed payment, sent or received.
- **The same message twice**, because the automation ran again or the action was run by hand, is only logged once.
- **MoMoAdvance**, MTN's overdraft, sends a message of its own when it pays for a payment your balance could not cover. It is not a second payment: its access fee joins the fee of the payment it paid for, whichever of the two messages arrives first. A loan repaid from your balance is not logged either, since the money was counted when it was spent.

A confirmed payment takes the fee, the carrier's reference and the balance after from the message, and keeps the time it was dialled. A merchant also takes the name its code is registered under, when the message names the code.

With auto-verify on, a payment that did not go through is marked failed for you, and its details say why:

- **No message within an hour.** A wallet's message comes within a minute or two, so a payment none has confirmed after an hour almost surely never went through: cancelled at the wallet's prompt, a wrong PIN, a dropped call. If its message turns up later, within the six hours a match allows, it still confirms the payment.
- **The wallet said it failed.** A message saying a payment failed, was cancelled or was declined fails it at once, but only when it names the amount and the number or merchant code, since that is what ties it to the payment you dialled. One that says less is ignored.

A late message never confirms a payment the wallet said failed, or one you marked failed yourself; if one did go through after all, verify it with its message (below). Payments dialled before auto-verify was set up are left as they are, and so is every payment while auto-verify is off: each stays pending until you mark it.

If the shortcut seems to have stopped (your last three payments all went unconfirmed and no message has come for a week), StarHash stops failing payments rather than fail ones that probably went through, and Settings says to check the shortcut. Nothing more is marked failed until a message comes again.

## Verify a payment by hand

A payment its message never reached (the automation was off, or the message came before it was set up) can still be settled by that message. Open the payment and tap **Verify** (or hold it in Activity, or tap **Verify** on its reminder), copy the wallet's message in Messages, and tap **Paste Message**. iOS lets no app read your messages, so this is the one way StarHash sees it.

StarHash reads it as the automation would and applies it only when it is this payment's: the same amount, the same number or merchant code, the same wallet, within six hours. A message that it went through confirms it with the fee, reference and balance; one that it failed marks it failed; MoMoAdvance's adds its access fee. A message about another payment changes nothing and says which payment it is about. **Confirm Without Message** is the last resort, for a message deleted or never sent; its fee comes from the carriers' prices.

> [!WARNING]
> Airtel Money's messages are read with the template Airtel Africa uses across its countries ("SENT.TID ... RWF 1,000 to NAME 07... Fee ... Bal ..."), since no Rwandan sample has been published. If a real Airtel message is not picked up, please [open an issue](https://github.com/devbyshima/starhash/issues/new) without your numbers or amounts.

## With your own build

The shared shortcut points at the official app. A build signed with a different bundle id needs a shortcut of its own, either way:

- **By hand**: in Shortcuts, make a shortcut named exactly **StarHash SMS** with your build's **Process Carrier SMS** action, fed the Shortcut Input, then add its automation as the iOS 18 to 26 steps above describe (Message Contains **RWF**, **Run Immediately**, **Notify When Run** off). The Verify step runs it by that name.
- **With the script**: set `BUNDLE_ID` and `TEAM_ID` in `scripts/make_shortcut.py` and run it (the Mac must be signed in to iCloud). It writes and signs `StarHash/Resources/StarHash SMS.shortcut` (the automation it writes in for iOS 27 has not been seen to work, so make the automation by hand too). Share it from Shortcuts and set `StarHashShortcut.iCloudLink` to the new link.

```bash
python3 scripts/make_shortcut.py
```

Run the script again after renaming the action, the bundle id or the team, and share the result again: an iCloud link is a copy of the shortcut as it was when shared.
