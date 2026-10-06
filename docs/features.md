# Features

A tour of what StarHash does, screen by screen. For the codes it dials see [Codes and fees](codes-and-fees.md), and for the SMS automation see [Auto-verify](auto-verify.md).

- [Getting around](#getting-around)
- [Onboarding](#onboarding)
- [Pay](#pay)
- [Choosing a recipient](#choosing-a-recipient)
- [Buy](#buy)
- [Activity](#activity)
- [Transaction details](#transaction-details)
- [Nearby](#nearby)
- [Settings](#settings)
- [Shortcuts, Siri and links](#shortcuts-siri-and-links)
- [Look and feel](#look-and-feel)

## Getting around

A floating glass tab bar holds Activity on the left, Pay in the middle and Settings on the right. The round button at the top left of Pay switches the middle place to Buy and back, and the bar remembers whichever showed last. The bar shrinks while a page scrolls down and steps aside for pushed screens and search. Every press is felt, and page changes play a short haptic of their own.

## Onboarding

Five screens, picked up where you left off:

1. A short reel of what StarHash does.
2. Your wallet: MTN MoMo or Airtel Money.
3. Contacts, so you can pick who to pay.
4. Nearby, which asks for your location.
5. Auto-verify, which you can set up now or later.

Each permission screen has one button, Continue, which opens the system prompt. A short note from the developer opens over Pay when onboarding ends, and a single note two weeks later asks for a rating.

## Pay

- A large amount on a 3 by 4 keypad, in whole francs up to 10,000,000 RWF. Holding delete clears it.
- **Pay** opens the recipient screen. Tapped with nothing typed, the amount shakes and the phone beats twice, like a heartbeat.
- **Balance** dials your wallet's balance code.
- The wallet button at the top right shows your wallet's logo and switches between MTN MoMo and Airtel Money.

## Choosing a recipient

The recipient screen opens with the keyboard up on its numbers, since most payments go to a merchant code typed on the spot. One field takes codes, numbers and names. From the top:

1. **Saved**: a contact or someone paid before whose number or code matches what you typed. Anything else shows as a **Number** or a **Merchant code**, paid as typed.
2. **Nearby**: codes and numbers you paid where you are standing (see [Nearby](#nearby)).
3. **Recent**: up to ten people and codes you paid last.
4. **Contacts**: matched letters are highlighted.

The total rides in a bar above the keyboard. A contact with several numbers asks which one, each shown with its carrier's logo, and a long press opens a contact's details with this year's total. Picking someone dials at once: the iPhone's call prompt, showing the whole code, is the approval. With Save transactions on, the payment is then saved as Pending, and dialling the same recipient and amount again within five minutes reuses it rather than adding a second.

Ten digits or more is a phone number (`+250 788 123 456` becomes `0788123456`); fewer is a MoMo Pay merchant code. Numbers starting 072 or 073 are Airtel, the rest MTN.

## Buy

Codes you dial often, each on a card with its symbol, name and code, and a call button beside it. Buy's codes are not logged in Activity: the menu each one opens asks for the amount and your PIN itself.

- It comes with four: Pending approvals, Cash out, Gwamon' Pack and Airport parking.
- **+** adds your own: a name, a code that starts with `*` or `#` and ends with `#`, an optional note, and one of thirty symbols.
- Tap a card for its details (Edit, Dial, Delete). Hold it for Pin, Edit and Delete.
- Pin up to eight codes as tiles at the top, dialled in one tap. Rearrange in a pinned code's menu sets them wiggling so you can drag them into order.
- On iOS 27, swipe a card from the left to pin it or from the right to delete it.

Delete All Data brings back the four codes Buy came with.

## Activity

- **D W M Y** picks Today, This Week (the default), This Month or This Year.
- A summary card shows what you spent, what came in and the fees, over a bar chart you can press and slide along.
- Payments are grouped by day, with a red arrow for money out and a green one for money in. Pending payments carry an orange badge; failed ones are struck through and count towards nothing.
- Search covers every payment, not just the period: names, numbers, codes, amounts and references.
- Hold a payment for Verify, Mark as Failed and Delete. On iOS 27, swipe left for a red trash, or all the way across to delete at once.

## Transaction details

A page of its own for each payment: who, how much, a category (Restaurant, Groceries, Transport, Bills, Shopping, Health, Family, Other), the fee, date and time, the carrier's reference, the number or merchant code, the balance after, the status, a map of where you paid (with Nearby on) and what you sent them this year.

Its actions are Pay Again (Send Money for money you received), Verify, Mark as Failed and Delete. Verify settles a payment with its wallet's message, pasted in ([Auto-verify](auto-verify.md#verify-a-payment-by-hand)). A payment that did not go through can be marked failed; it stays, struck through, and can still be verified later.

Deletes ask first, except a swipe, unless you turn that off, in Settings or with Don't Ask Again on the question itself.

## Nearby

Off until you turn it on, and it needs precise location.

- Location is read only while you pay, from the moment the recipient screen opens, and never holds up the dial.
- A payment keeps where it was made only when it goes to a merchant code or to a number that is not in your Contacts. Paying a contact never records where you were.
- Suggestions need a fix accurate to 50 m, both now and when the payment was made, and a payment within 40 m of you, or within the two fixes' combined accuracy when that is wider (up to 100 m). Up to three show, nearest first, before you start typing.
- A merchant shows under the name its code is registered under, from its confirmation SMS, which can differ from the shop's sign.
- No place is ever named or looked up. Deleting a payment forgets its place, and turning Nearby off erases them all.

## Settings

| Card | What's in it |
| --- | --- |
| Transactions | Save transactions, Auto-verify transactions, Ask before deleting |
| Recipients | Enable contacts, Nearby, Save recent recipients |
| Pay & Buy | Default page: Pay or Buy |
| Display | Appearance: System, Dark or Light |
| Security | Face ID (Touch ID, or Passcode Lock on an iPhone without either) |
| More | Terms of Service, Privacy Policy, Request a Feature, About StarHash |

- The lock is off until you turn it on, and asks before it turns on or off. It asks as StarHash opens and after more than a minute away, so a payment's trip to the call screen does not trigger it, and it hides StarHash in the app switcher.
- **About StarHash** holds What's New, Replay Onboarding, the developer's note and a link to the source code.
- **Delete All Data** erases everything StarHash keeps (payments, Buy's codes, your wallet and settings) and starts again from onboarding, like deleting an account.
- The footer shows the version and the build, for example `1.0.0 (1)`.

## Shortcuts, Siri and links

| Action | What it does |
| --- | --- |
| Pay with StarHash | Opens the Pay keypad |
| Check Wallet Balance | Dials your wallet's balance code |
| Process Carrier SMS | With Auto-verify on, logs or confirms an MTN MoMo or Airtel Money message, without opening the app |

Siri knows phrases such as "Pay with StarHash" and "Check my balance in StarHash".

The `starhash://` scheme opens `pay`, `buy`, `activity`, `settings` or `transaction/<id>`.

## Look and feel

- Four colours: blue `#05A9F4`, pale grey `#F4F4F4`, near black `#171717` and grey `#616161`. Light mode is blue throughout with near-black buttons; dark mode is near black with blue ones. Green, orange and red appear only for money in, pending payments, and money out, failed payments and deletes.
- [Space Grotesk](https://github.com/floriankarsten/space-grotesk) throughout, following Dynamic Type.
- Liquid Glass on iOS 26 and later, with materials in its place on iOS 18.
- Hand-drawn doodles for every empty state, and haptics on every press.
