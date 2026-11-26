# Web pay: one QR code for people with and without StarHash

A plan, not built yet (2026-11-26).

## The goal

A StarHash QR code opens StarHash when the person scanning has it. When they don't, it opens a StarHash page in their browser where they can pay the owner the same way: see who they are paying, type or check the amount, and dial the payment from their own phone. After that, the page asks them to get StarHash.

## What must not change

- Every `starhash://` link keeps working: codes already shown or shared, the widgets, quick actions, `OpenStarHashIntent`, the shortcut's callback and the router (`AppRouter.handle`).
- The in-app scanner still reads MoMo USSD strings, `tel:` links, EMV merchant stickers and bare numbers (`PaymentQR.parse`).
- Payments never touch the server. The web page doesn't send it the number or the amount either (see [The link](#the-link)). The only request it makes is for the photo, which the app already fetches today.
- Free personal team builds keep signing. Universal Links go behind a project switch, the way App Groups do (`STARHASH_APP_GROUPS`).
- The server's `/v1` API stays as it is.
- The page never asks for a PIN, a password or anything else about the payer's wallet. The PIN is only ever typed into MTN's or Airtel's own USSD menu.

## What limits it

1. **Universal Links need the paid Apple Developer Program.** Universal Links are what make one https link open the app when it's installed. They need the Associated Domains entitlement, which the free team (W46T258AXM) can't sign. Until the team is paid, the iPhone Camera opens every https code in Safari, even for people who have StarHash. Scanning inside the app works either way.
2. **iPhone Safari may not dial USSD codes.** Apple documents that a `tel:` link containing `*` or `#` isn't dialled from a web page. Android's Chrome opens the dialler with the code filled in. Test this on Serein and on an Android phone before building the Pay step (Phase 0).
3. **The page can't confirm a payment.** It can't read the payer's SMS, so the end screen comes after they tap Pay, not after a confirmed payment.
4. **There is nowhere to download StarHash yet.** It isn't on the App Store (`DeveloperNoteLinks.appStoreID` is nil), and it's iPhone only, so Android payers have nothing to install.
5. **Paying inside the browser itself** (type a number, approve a prompt) would need MTN's and Airtel's merchant collection APIs and a StarHash account the money passes through. That is out of scope: it would end "payments never leave the phone".

## The link

```
https://<host>/pay#to=0788123456&name=Ariane&amount=500&p=<photo id>
```

- The same fields as `starhash://pay?…` (`to`, `name`, `amount`, `p`), so the two forms map one to one.
- The fields go after `#`. Browsers never send that part to the server, so the Worker's logs see only `/pay`. Universal Links match on the path, so the fragment doesn't get in their way.
- `<host>` is one constant in StarHashKit (`PaymentQR.webHost`). A code counts as a StarHash code, with its name and photo shown, only when the host matches exactly. A lookalike host is read like any other link: its number alone, as today.
- The link is about 25 characters longer than the `starhash://` one, so the code gains modules. Check that `QRTreeView` still scans from the iPhone Camera and from the in-app scanner.

## Phases

Each phase ships on its own and leaves everything working. Nothing anyone sees changes until Phase 4 turns the codes over.

### Phase 0: decide and test (no code)

- Make the decisions in [Decisions](#decisions).
- On Serein, open a test page with a `tel:*182*1*1*0788123456*100%23` link in Safari. Note whether it dials, asks first, or does nothing. Do the same in Chrome on an Android phone. Cancel before the PIN.
- **Done when** it's known which phones can dial from the page and which need the Copy Code route.

### Phase 1: the app reads web links

In `Packages/StarHashKit`:

- `PaymentQR.webHost` and `PaymentQR.webLink(for:amount:photoID:)`, which builds the link above.
- `PaymentQR.parse` reads the web link (fields from the fragment, and from the query as well, so a hand-typed link still works). It returns `isStarHashCode: true` and the photo only for `webHost`.
- `StarHashLink(url:)` reads the web link as `.payment`, so the router opens Pay on it once Universal Links arrive. `StarHashLink.payment(_:).url` stays `starhash://`, since the widgets and quick actions route through it.
- Tests in `PaymentQRTests` and `StarHashLinkTests`: a web link round trip with and without name, amount and photo; a lookalike host isn't a StarHash code and carries no photo; fragment and query both read; every existing `starhash://` case still passes.

**Done when** `./scripts/test.sh` passes. Nothing visible changes.

### Phase 2: the page on the Worker

In `server/`:

- Static files through Workers static assets (`[assets]` in `wrangler.toml`, a `server/web/` folder). The Worker keeps `/v1/*`. `/pay` serves the page with `Cache-Control`, a strict `Content-Security-Policy`, `Referrer-Policy: no-referrer` and `X-Robots-Tag: noindex`.
- The page, plain HTML, CSS and a little JavaScript, small enough for a slow connection:
  1. Read the fragment and check it the way `PaymentQR.parse` does: a Rwandan mobile number (078, 079, 072, 073) or a merchant code of 3 to 9 digits, and an amount from 1 to `Money.maximumAmount`. Anything else shows "This isn't a StarHash payment code".
  2. Show the owner's photo (`GET /v1/photos/<p>`, same origin), name and number. The number always shows, since the name is only what the code says.
  3. The amount, filled in when the code has one.
  4. The payer's wallet, MTN MoMo or Airtel Money, remembered in `localStorage`. The code depends on whether the payer and the recipient share a network.
  5. Pay builds the code exactly as `USSD.payment` does (see [codes-and-fees.md](codes-and-fees.md)). Where Phase 0 showed the browser dials, it opens the `tel:` link with `#` as `%23`. Elsewhere it shows the code large, with Copy Code and "Open Phone, paste and call". Either way, it reminds them that MTN's or Airtel's menu names the recipient before the PIN, and to check it.
  6. The end screen: "You'll get an SMS from MTN or Airtel when it's sent". Below it, Get StarHash: the App Store on an iPhone (and a Smart App Banner once `appStoreID` exists), and whatever was decided for Android.
- English, French and Kinyarwanda, picked from `Accept-Language`, with a switch on the page. Reuse the app's wording from `Localizable.xcstrings` where the words are the same.
- The app's look: white page with `#F5F6F5` fills and `#E1E1E1` outlines in light mode, `#101010` with `#262626` and `#333333` in dark, the text colour as the accent, Space Grotesk, no green, and red only for errors.
- The code builder gets a test table of cases (each network to each network, merchant codes, with an amount). Both `USSD` in StarHashKit and the page's builder are tested against the same table, so the two can't drift.

**Done when** `npm run typecheck` and the builder tests pass, it's deployed, and a hand-made link works on Serein and on an Android phone for an MTN number, an Airtel number and a merchant code, each with and without an amount and a photo. Nothing links to the page yet.

### Phase 3: Universal Links (needs the paid team)

- `GET /.well-known/apple-app-site-association` from the Worker, as `application/json` with no redirect: `applinks` for `<paid team id>.com.devbyshima.starhash`, matching `/pay`. The team id may change when the program is joined, so take it from the paid team.
- Associated Domains (`applinks:<host>`) in `project.yml` behind a switch like `STARHASH_APP_GROUPS`, default `NO`, so free-team builds still sign.
- `onOpenURL` already hands every link to `AppRouter.handle`. Check on Serein that a Universal Link reaches it too, and add `onContinueUserActivity` if it doesn't.

**Done when**, on Serein, the Camera opens StarHash on a web link, and with StarHash deleted the same scan opens the page.

### Phase 4: codes switch over

- A feature flag in `FeatureFlag.swift`, "Web links in QR codes", rolled out `.off`, then `.dev`, then `.everywhere`, and deleted after that, per [RELEASING.md](../RELEASING.md).
- One function picks the code's text (`webLink` with the flag on, `link` with it off). `MyCode.swift` (the shared image and the tree) and `ProfileView.swift` both call it. They each build the link themselves today.
- The privacy policy in `LegalPages.swift` and [privacy.md](privacy.md): the web page, that it only fetches the photo, and that the number and amount stay in the browser. Then [features.md](features.md), `CHANGELOG.md`, and What's New if wanted.

**Done when** codes made with the flag on scan from the Camera (app installed and not) and from the in-app scanner, and codes made before still pay.

### Phase 5 (optional): codes for merchants

Today a StarHash code carries the owner's default SIM number only. If merchants with a MoMo Pay code should get StarHash codes, Profile needs a way to put a merchant code on the code, and possibly a printable sticker (PDF) export. This phase is its own design.

## Decisions

1. **The host.** `starhash.devbyshima.workers.dev` works today. Your own short domain on Cloudflare costs a domain fee, but it makes a smaller code, it's easier to trust on a sticker, and it can move away from `workers.dev`. Printed codes last for years, so pick before Phase 4.
2. **The paid Apple Developer Program.** Phase 3 can't happen without it. The App Store release needs it anyway.
3. **Where Get StarHash points** before the App Store listing exists: a public TestFlight link, a waitlist, or nothing until launch. And what Android payers see, since StarHash is iPhone only.
4. **Merchant codes** (Phase 5): whether owners can put a MoMo Pay code on their StarHash code.
5. **Counting** (optional): an anonymous daily count of page opens and Pay taps, to see whether the page brings people to StarHash. If yes, it needs a line in the privacy policy, and it never includes a number or an amount.

## Risks

- **Fake codes.** Anyone can make a link with someone else's name and their own number. That's true of `starhash://` codes today too. The page always shows the number and points to the carrier's menu, which names the real recipient before the PIN.
- **Copycat pages.** A cloned page on another domain could ask for a PIN. StarHash's page never asks for one, and the end screen and the privacy policy say so.
- **Old app builds** read a web link through `loose()`: the number alone, without the name or amount. Phase 1 should reach installed builds before Phase 4 turns the codes over.
