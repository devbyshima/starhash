# Auto-verify

A payment dialled from StarHash is **Pending** until your wallet's SMS confirms it. iOS does not let apps read messages, so a Shortcuts automation hands each one to StarHash, which confirms the matching payment with its fee, reference and new balance.

> [!NOTE]
> Auto-verify only works with **Save transactions** on, and StarHash keeps nothing from a message that is not a MoMo or Airtel Money transaction.

## Set it up

Open **Settings › Auto-verify transactions**, or choose **Set Up** on the last onboarding screen. The guide has two steps, each shown with a screenshot of Shortcuts.

1. **Add the StarHash SMS shortcut.** StarHash opens the shared shortcut on Shortcuts' Add screen. It runs the **Process Carrier SMS** action on the message it is given.
   - **On iOS 27**, the shortcut brings its automation with it: when a message containing **RWF** arrives, run without asking. Turn off **Notify When Run** on the automation, or iOS announces every run.
   - **On iOS 18 to 26**, a shared shortcut cannot carry its automation, so the guide walks you through making it: **Automation › + › Message**, Message Contains **RWF**, **Run Immediately**, **Notify When Run** off, then pick **StarHash SMS**.
2. **Verify the shortcut.** StarHash runs it with a sample message (never saved) and waits for it to come back. Auto-verify only turns on once this works; if it does not, the guide offers Try Again.

Every MTN MoMo and Airtel Money transaction message contains "RWF", which is why the automation keys on it.

## How a message is matched

Each message either confirms a pending payment or is logged as a new one.

- **A match** has the same amount and the same number or merchant code, was dialled within six hours of the message, and came from the same wallet. When several match, the closest in time wins.
- **A message without the number or code** (some merchant and cross-network messages leave it out) settles for a pending payment of the same kind. It can fill in a missing name but never replaces one.
- **No match**: the message is logged as a new confirmed payment, sent or received.
- **The same message twice**, because the automation ran again or the action was run by hand, is only logged once.
- **MoMoAdvance**, MTN's overdraft, sends a message of its own when it pays for a payment your balance could not cover. It is not a second payment: its access fee joins the fee of the payment it paid for, whichever of the two messages arrives first. A loan repaid from your balance is not logged either, since the money was counted when it was spent.

A confirmed payment takes the fee, the carrier's reference and the balance after from the message, and keeps the time it was dialled. A merchant also takes the name its code is registered under, when the message names the code.

Messages about failed, cancelled or declined payments are ignored. Neither carrier publishes a format to read them by, and a payment wrongly marked failed would drop out of your totals, so a payment that did not go through stays pending until you mark it failed by hand.

> [!WARNING]
> Airtel Money's messages are read with the template Airtel Africa uses across its countries ("SENT.TID ... RWF 1,000 to NAME 07... Fee ... Bal ..."), since no Rwandan sample has been published. If a real Airtel message is not picked up, please [open an issue](https://github.com/devbyshima/starhash/issues/new) without your numbers or amounts.

## With your own build

The shared shortcut points at the official app. A build signed with a different bundle id needs a shortcut of its own, either way:

- **By hand**: in Shortcuts, make a shortcut named exactly **StarHash SMS** with your build's **Process Carrier SMS** action, fed the Shortcut Input, then add its automation as the iOS 18 to 26 steps above describe (Message Contains **RWF**, **Run Immediately**, **Notify When Run** off). The Verify step runs it by that name.
- **With the script**: set `BUNDLE_ID` and `TEAM_ID` in `scripts/make_shortcut.py` and run it (the Mac must be signed in to iCloud). It writes and signs `StarHash/Resources/StarHash SMS.shortcut`, with the iOS 27 automation built in. Share it from Shortcuts and set `StarHashShortcut.iCloudLink` to the new link.

```bash
python3 scripts/make_shortcut.py
```

Run the script again after renaming the action, the bundle id or the team, and share the result again: an iCloud link is a copy of the shortcut as it was when shared.
