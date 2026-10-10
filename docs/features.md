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

Six screens, picked up where you left off:

1. A short reel of what StarHash does.
2. Your wallet: MTN MoMo or Airtel Money.
3. Your name and number, for your own QR code (Maybe Later skips it).
4. Contacts, so you can pick who to pay.
5. Nearby, which asks for your location.
6. Auto-verify, which you can set up now or later.

Each permission screen has one button, Continue, which opens the system prompt. A short note from the developer opens over Pay when onboarding ends, and a single note two weeks later asks for a rating.

## Pay

- A large amount on a 3 by 4 keypad, in whole francs up to 10,000,000 RWF. Holding delete clears it.
- **Pay** opens the recipient screen. Tapped with nothing typed, the amount shakes and the phone beats twice, like a heartbeat.
- **Balance** dials your wallet's balance code.
- The wallet pill just above the keypad shows your wallet's logo and switches between MTN MoMo and Airtel Money.
- The scan button at the top right opens the QR scanner (below).

## Scan to pay

The scanner reads a merchant's MoMo QR code (its USSD code, a `tel:` link or the EMV payload Rwanda's merchant codes carry), a friend's StarHash code, or a bare number or merchant code. Whoever it names waits under the amount, with the amount filled in when the code carries one, and Pay dials them straight away, with no recipient screen. A code that is not a payment code says so, and scanning goes on. **Photos** reads a code from a picture, and the torch helps in the dark.

**My Code** shows your own code for someone else to scan: a `starhash://pay?to=...` link, so the iPhone's own Camera opens StarHash on it too. It needs your number, given in onboarding or in Settings' **Profile**, where the code can also be shared. Profile puts your face and your name large at the top; tap the face to pick another from "Pick your vibe", and type the name in place.

## Choosing a recipient

The recipient screen opens with the keyboard up on its numbers, since most payments go to a merchant code typed on the spot. One field takes codes, numbers and names. From the top:

1. **Saved**: a contact or someone paid before whose number or code matches what you typed. Anything else shows as a **Number** or a **Merchant code**, paid as typed.
2. **Nearby**: codes and numbers you paid where you are standing (see [Nearby](#nearby)).
3. **Recent**: up to ten people and codes you paid last.
4. **Contacts**: matched letters are highlighted.

A number saved in your Contacts always shows under the name you saved it with, here, in Activity and on Pay, ahead of the name a wallet's message gives. The total rides in a bar above the keyboard. A contact with several numbers asks which one, each shown with its carrier's logo, and a long press opens a contact's details with this year's total. Picking someone dials at once: the iPhone's call prompt, showing the whole code, is the approval. With Save transactions on, the payment is then saved as Pending, and dialling the same recipient and amount again within five minutes reuses it rather than adding a second.

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
- Payments are grouped by day, with a red arrow for money out and a green one for money in. Pending payments carry a yellow badge; failed ones are struck through and count towards nothing.
- Airtime, bundles, electricity, water and TV show as **Bought**, with what was bought as their symbol, rather than as money sent. Their wallet's message says so ("You have bought 1,000 RWF of airtime"), or the name they were paid to does.
- The chart button opens **Reports**.
- Search covers every payment, not just the period: names, numbers, codes, amounts and references.
- Hold a payment for Verify, Mark as Failed and Delete. On iOS 27, swipe left for a red trash, or all the way across to delete at once.

## Reports

A month at a time, stepping back through every month with payments in it: what went out, compared with the month before, what came in and the fees; a few sentences on what stands out, written on the iPhone (by Apple Intelligence on iOS 26 and later in a language it speaks, by StarHash itself otherwise); where the money went by category; who was paid the most; and the month's highlights (the biggest payment, the average a day, the busiest weekday, what was bought). The weekly and monthly summary notifications open it.

## Categories

Every payment can carry a category: Airtime, Bundles, Electricity, Water, TV, Restaurants, Groceries, Transport, Bills, Shopping, Health, Education, Family, Savings or Other. StarHash fills them in from the merchant's name and, with **Smart categories** on (Settings, Transactions), asks the on-device model about names its rules cannot place. Only the name is asked about; a category chosen by hand is never changed.

## Transaction details

A page of its own for each payment: who, how much, a category, the fee, date and time, the carrier's reference, the number or merchant code, the balance after, the status, a map of where you paid (with Nearby on) and what you sent them this year.

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
| Profile | Your name and number, and your QR code |
| Transactions | Save transactions, Auto-verify transactions, Ask before deleting, Smart categories, Notifications |
| Recipients | Enable contacts, Nearby, Save recent recipients |
| Pay & Buy | Default page: Pay or Buy |
| Display | Appearance: System, Dark or Light; Language, English or Kinyarwanda, in the Settings app |
| Security | Face ID (Touch ID, or Passcode Lock on an iPhone without either), Scam warnings |
| Your Data | Export data, Import data |
| More | Terms of Service, Privacy Policy, Request a Feature, About StarHash |

- The lock is off until you turn it on, and asks before it turns on or off. It asks as StarHash opens and after more than a minute away, so a payment's trip to the call screen does not trigger it, and it hides StarHash in the app switcher.
- **About StarHash** holds What's New, Replay Onboarding, the developer's note and a link to the source code.
- **Export data** saves everything StarHash keeps (payments, Buy's codes and your profile) as one JSON file, wherever you choose. **Import data** adds what is in such a file and not already here, changing nothing that is.
- **Scam warnings** holds back a message that looks like your wallet's but came from someone's own number, or asks for money back, and warns you instead of logging it ([Auto-verify](auto-verify.md#scam-warnings)).
- **Delete All Data** erases everything StarHash keeps (payments, Buy's codes, your wallet and settings) and starts again from onboarding, like deleting an account.
- The footer shows the version and the build, for example `1.0.0 (1)`.

## Shortcuts, Siri and links

| Action | What it does |
| --- | --- |
| Pay with StarHash | Opens the Pay keypad |
| Check Wallet Balance | Dials your wallet's balance code |
| Process Carrier SMS | With Auto-verify on, logs or confirms an MTN MoMo or Airtel Money message, without opening the app |

Siri knows phrases such as "Pay with StarHash" and "Check my balance in StarHash".

The `starhash://` scheme opens `pay`, `buy`, `activity`, `settings`, `transaction/<id>`, `scan` (the scanner) or `report` (this month's report). `starhash://pay?to=<number or code>&name=<name>&amount=<n>` is a StarHash QR code's link and chooses who to pay.

## Widgets

- **Buy**: your codes and nothing else, on GO Club's white card (the near black in dark mode), pinned codes first. A tap on a code dials it through the iPhone's call prompt. With more codes than fit, the last tile is More, which pages through them right on the widget; the small widget shows one code at a time with its own arrow, and the large one adds Balance and Scan to Pay.
- **Scan to Pay**: a Control Center and Lock Screen control that opens the scanner.

The widgets read your data through an App Group, which needs a paid developer team ([Development](development.md#widgets-and-the-app-group)); without one they show StarHash's own codes.

## Look and feel

- Four colours: blue `#3020FE`, pale grey `#F4F4F4`, near black `#171717` and grey `#616161`. Light mode is blue throughout, with white text on it, white cards and white buttons with near-black words; dark mode is near black with blue buttons. Green `#05D079`, yellow `#F2BB07` and red `#F36209` appear only for money in, pending payments, and money out, failed payments and deletes.
- English and Kinyarwanda, chosen per app in the Settings app.
- [Space Grotesk](https://github.com/floriankarsten/space-grotesk) throughout, following Dynamic Type.
- Liquid Glass on iOS 26 and later, with materials in its place on iOS 18.
- Hand-drawn doodles for every empty state, and haptics on every press.
