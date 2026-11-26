# People Nearby, Requests and Split the Bill

A plan, built through Phase 3 behind the `peopleNearby` and `requestsAnywhere` flags (2026-11-26).

## What's in it

- **People Nearby.** While StarHash is open, StarHash users close by appear on Pay. Tap one and pay them, with no QR code.
- **Requests.** Ask one StarHash user for money, whether they're next to you or anywhere else. They get a card with Pay and Decline.
- **Split the Bill.** Ask several people for their share of one amount, and see who has paid.

Not in it: a request shown to everyone nearby, request links, and people without StarHash. Those wait for [web pay](web-pay.md).

## What must not change

- **Nearby**, the suggestions of people paid where you are standing, keeps its name, its switch and its location permission. The new feature is **People Nearby**, with its own switch, and it never uses location.
- **Split Large Payments** (`SplitPlan`) stays as it is. The new feature is **Split the Bill**, `BillSplit` in code.
- `PaymentRequest`, the type for a scanned code, keeps its name. A request for money is `MoneyRequest`.
- Pay keeps its order, amount then who then dial. People Nearby adds one more way to choose who.
- A request never dials by itself. The payer always taps Pay, and the PIN is only ever typed into MTN's or Airtel's menu.
- Show My Name and the directory work as they do. The server only gains a column and a table, and the `/v1` endpoints the app uses today don't change.
- Free-team builds keep signing. Nothing here needs an entitlement except push notifications (Phase 5), which go behind a project switch like `STARHASH_APP_GROUPS`.
- Each phase ships off behind a feature flag (`FeatureFlag.swift`) and rolls out as [RELEASING.md](../RELEASING.md) describes.

## People Nearby

**How phones find each other.** They use MultipeerConnectivity over Bluetooth and peer-to-peer Wi-Fi, with no internet and no server. Info.plist gains `NSLocalNetworkUsageDescription` and `NSBonjourServices` (`_starhash-near._tcp`, `_starhash-near._udp`). iOS asks for Local Network access the first time.

**Being seen.** While StarHash is in front and **Let People Near You See You** is on, the phone announces three things:
- the owner's name,
- their photo's id,
- a random id for that session.

The announcement never includes the number. When StarHash leaves the front, the phone stops announcing and drops off everyone's list within seconds.

**Seeing others** doesn't require being seen. Anyone with People Nearby on can browse.

**Paying.** A tap connects the two phones, with Multipeer's encryption required. The other phone sends its default SIM's number, the same one its QR code carries. Pay then has that person chosen, with their name and photo, just as Pay Again does (`chosenRecipient`). Type the amount and Pay dials. Pay always shows the number. Someone who turned on Let People Near You See You has agreed to this, so there's no accept step on their side.

**Where they show up:**
- A row of faces on Pay, above the keypad, that comes and goes as people do.
- A People Nearby section at the top of the recipient picker, above Nearby.

People found most recently come first. Multipeer gives no distance. Distance and "point at the person" could come later, through Nearby Interaction on iPhone 11 and later.

**Turning it on.** It's off until the owner says yes. Let People Near You See You is asked once, the first time Pay opens with the flag on, just before the Local Network prompt. It lives in Settings next to Show My Name.

## Requests

There's one model, `MoneyRequest`, with two ways to deliver it.

**What a request holds:**
- who asks (name, number, photo id) and who is asked,
- the amount, and an optional note of up to 60 characters,
- when it was made, and when it expires (7 days),
- its status: waiting, paid, declined, cancelled or expired,
- a group id when it belongs to a Split the Bill.

**Asking.** Type the amount on Pay and tap **Request**, beside Pay. Then choose who:
- People Nearby come first.
- Then contacts and typed numbers that are on StarHash. Each is checked with the directory lookup that already exists, at the moment it's chosen, never the whole contact list.
- A number not on StarHash says so and offers Share Message: your number, the amount and the note, through the share sheet.

**Delivery:**
- **Nearby:** over the People Nearby connection, at once. If the other person walks away before answering, the request goes through the server instead.
- **Anywhere:** through the server (below).

**Being asked.** Only people in your Contacts can ask you. The check runs on the phone, since your contacts never leave it.
- A request from a number not in your Contacts isn't shown. It's deleted from the server without an answer, so all the asker ever sees is that it expired. This applies to nearby requests too: a shop has to be saved as a contact first.
- If StarHash can't read Contacts, it can't tell who someone is, so it shows no requests, and the Requests page says why.
- A request that gets through shows as a card on Pay with the photo, name, amount and note, and **Pay** and **Decline** buttons. Pay opens Pay with the person and the amount filled in, and dials when they tap Pay, as usual. Decline tells the asker. The number always shows, and Block is one tap away.

**The Requests page.** Every request you've sent is listed with its status (Waiting, Paid, Declined, Cancelled or Expired) and Cancel. So is every split, and every request waiting for your answer. You reach it from Pay and from Transactions.

**Closing.** A request shows as Paid when either of these happens:
- The asker's auto-verify reads a money-received SMS with the same amount and the same last three digits of the number. MTN's message hides the rest, so that's all it gives. It also has to arrive while the request is waiting.
- The payer's app sees its own sent-money SMS and reports Paid back.

Without auto-verify, the asker marks it Paid by hand. The matching rules live in StarHashKit with their own tests.

## The server, for requests anywhere

- **Both people need a directory entry**, which means Show My Name on. That's how a number finds a phone.
- **The directory gains `public_key`,** a Curve25519 key per entry, made with CryptoKit on the phone. A request's amount, note and the asker's number are sealed with HPKE to the other person's key. The server sees who asked whom and when, but not how much or why.
- **A `requests` table:**
  - id,
  - `to_hash` (a `number_hash`),
  - `from_key_hash`,
  - the sealed content,
  - `created_at` and `expires_at`.
- **Endpoints:**
  - `POST /v1/requests`: the asker's key as bearer, the other person's number in the body (never in a URL), and the sealed content. It returns 404 when the number isn't on StarHash. The server also checks that the asker's own number, sent alongside, is one their key lists in the directory, so nobody can ask in someone else's name. Then it drops the number.
  - `GET /v1/requests`: everything addressed to the caller's numbers, and the answers to their own requests.
  - `POST /v1/requests/<id>/answer`, for paid or declined, sealed to the asker.
  - `DELETE /v1/requests/<id>`, when the asker cancels.
- **Limits:** 20 requests a day per key, one waiting request per pair of people, and a size cap. The nightly cron deletes expired requests along with lapsed directory entries.
- **Getting them:** the app checks when it opens and through Background App Refresh, then shows a local notification. A real push arrives only with the paid team (Phase 5), and the push never carries the amount.
- **The privacy policy** (`LegalPages.swift`, [privacy.md](privacy.md)) gains a line on what the server holds for a request and for how long.

## Split the Bill

- Start from a payment you made (**Split This** on its page), or from Request by choosing several people.
- Set the total, the people, and equal or custom shares, with your own share left out.
- It sends one request per person under one group id.
- The split, on the Requests page, shows each person as Waiting, Paid or Declined, the total collected so far, and Remind, which sends again at most once a day.
- Each friend needs you in their Contacts, or your request to them is never shown.
- Anyone not on StarHash gets Share Message with their share, and a web pay link once that exists.

## Phases

### Phase 0: decide and try it

Build the first version against the Simulator and Serein. Once a borrowed second iPhone is here, check on two real phones how fast they find each other, from how far, and what it costs in battery. The Simulator can't show range or Bluetooth.

### Phase 1: People Nearby

See StarHash users nearby and pay them. **Done when**:
- two iPhones see each other within a few seconds of opening StarHash,
- a tap opens Pay with the number, name and photo,
- turning visibility off, or leaving the app, removes you from the other's list,
- Nearby's suggestions work as before.

### Phase 2: requests nearby

`MoneyRequest`, Request on Pay, the cards, Decline, the Requests page, and matching received-money SMS. **Done when**:
- a request from one phone shows up as a card on the other when the asker is in that phone's Contacts, and doesn't when they aren't,
- Pay dials with the amount filled in,
- Decline shows on the asker's phone,
- the received-money SMS marks the request Paid.

### Phase 3: requests anywhere

The directory's keys, sealing, the `requests` table and its endpoints, Background App Refresh and local notifications. **Done when**:
- a request reaches a phone that isn't nearby the next time StarHash opens,
- requests expire after 7 days,
- the limits hold,
- the privacy policy says what's kept.

### Phase 4: Split the Bill

**Done when** a three-person split shows each share's status and the total collected, and fills in as the SMS arrive.

### Phase 5: push notifications (paid team)

APNs from the Worker, so a request arrives with StarHash closed.

### Phase 6 (optional): a Verified mark

A phone in People Nearby proves, with its directory key, that it owns the entry for the number it hands over.

## Decided in Phase 3 (2026-11-26)

- **Its own flag**, `requestsAnywhere`, on top of `peopleNearby` (which brings Request to Pay), so People Nearby and nearby requests can ship without the server's part.
- **The public key is a table, `directory_keys`, not a column.** `schema.sql` is run again whole after each change, and SQLite cannot add a column only when it is missing. One row per owner key, written with the listing (`key` in `PUT /v1/directory`, sent only while the flags are on), deleted with it, and lapsing with it after 45 days. Lookups return it as `key`.
- **The iPhone asked checks the asker's number too.** The server's check that `from` is the asker's own number cannot see into the seal, so the seal is authenticated by the asker's key (HPKE's auth mode) and the iPhone asked looks the sealed number up: it must be listed under the key that sealed the request, or the request is dropped. The server keeps the asker's public key on the request for that.
- **An answer is only a decline.** A request settles from the transactions alone, so the payer's iPhone never reports Paid. Instead the asker's iPhone closes on the server every request of theirs that no longer waits (paid, cancelled, declined or expired), which wipes what was sealed and frees the two of them to ask each other again, and the iPhone asked sees it closed (Cancelled, unless it was already paid there).
- **`DELETE /v1/requests/<id>` is the asker's close and the asked's drop.** A drop (someone not in Contacts) wipes the sealed part but keeps the row waiting for the asker, so all they see is that it expires, and they cannot ask again meanwhile. `DELETE /v1/requests` is Delete All Data's: every request sent closed, every one waiting dropped.
- **A request belongs to the key the number was listed under when it was asked** (`to_key_hash`), not to the number: listing a number needs no proof of the SIM, so whoever lists it later cannot read, answer or drop what was asked before.
- **Rows stay to the end of the week** (who asked whom and when, nothing sealed once closed) so the limits hold: 20 sent in any 24 hours per key, closed ones included, and one waiting per pair.
- **While Contacts cannot be read**, requests wait on the server unread rather than being dropped, and the Requests page says why.
- **Notifications only from Background App Refresh.** Opening StarHash shows the card, so a banner then would say the same thing twice. The Notifications page has a Requests switch.
- **Not built yet:** a nearby request going through the server when the other person walks away before answering.
- **Trying it on two Simulators:** `npm run dev` in `server/` (with `--var DIRECTORY_SECRET:<anything>` and `--persist-to` a folder that `wrangler d1 execute starhash --local --file schema.sql` set up), then launch each with `-server http://127.0.0.1:8787` and its own `-profileName` and `-profileNumber`: a Worker on the Mac lets the Simulator list its owner. `starhash://refresh` runs what Background App Refresh does.

## Decided in Phase 2 (2026-11-26)

- While People Nearby is on, **Request takes Balance's place** beside Pay. Settings, Pay & Buy, **Beside Pay** puts Balance back.
- **No button twice on a screen, and no keypad where nothing is typed.** The request card on Pay has no buttons: a tap opens the request, whose sheet has one Pay and one Decline (or, for one the owner sent, Mark as Paid and Cancel Request). Paying a request dials its amount straight from that sheet.
- The Requests page opens from a row at the top of Transactions, which also shows when there are no transactions yet.

## Decided (2026-11-26)

1. **Visibility** is off until the owner says yes, asked once.
2. **Names:** People Nearby, Let People Near You See You, and Split the Bill. Nearby and Split Large Payments keep their names.
3. **Requests anywhere use Show My Name.** Turning it off stops requests from anywhere. Nearby requests still work.
4. **Sent requests and splits** are listed on a Requests page of their own.
5. **Only your Contacts can ask you.** Other requests are dropped on the phone without a reply.
6. **Requests last 7 days,** and one person can send 20 a day.
7. **A second iPhone will be borrowed** for testing. Until it's here, the Simulator and Serein stand in.

## Risks

- **Impersonation nearby.** Anyone can announce someone else's name and photo. Pay always shows the number, and MTN's menu names the real recipient before the PIN. Phase 6 adds a proof.
- **Request scams,** such as "MTN Rwanda requests 5,000". Only your Contacts can ask you, so a stranger's request never shows. A contact's request still shows the number, Block is one tap away, and a request can't carry a link.
- **Contacts-only shuts out people you haven't saved.** A shop or someone new can't ask you until you save their number. If that turns out to hurt, a later version could show other requests under their own heading instead of dropping them.
- **Crowds.** A market can hold dozens of StarHash users, so the row has a cap and the picker's section scrolls.
- **The SMS match picks the wrong request.** Two waiting requests with the same amount and the same last three digits would be rare. The oldest one is matched, and marking Paid can be undone.
- **App Review.** The Local Network prompt's text has to say plainly why StarHash asks.
