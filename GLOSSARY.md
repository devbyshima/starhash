# StarHash

A companion for MTN MoMo and Airtel Money in Rwanda: it dials the wallet's codes to pay, and keeps the transactions its carrier's messages confirm.

## The owner and their SIMs

**Owner**:
The person whose iPhone StarHash runs on. StarHash has no accounts, so the owner is what they have told it: their name, their SIMs and their wallet.
_Avoid_: user, account holder

**Default SIM**:
The SIM whose number the owner's code carries, and the one StarHash expects payments to dial from; with one SIM, that SIM. With two SIMs it is always on the wallet's carrier.
_Avoid_: primary SIM, main number, profile number

**Other SIM**:
The owner's second SIM, when they have two.
_Avoid_: second number, secondary SIM

**Wallet**:
The mobile money account the owner pays from: MTN MoMo or Airtel Money.
_Avoid_: network, account

## Transactions

**Own transfer**:
Money moved between the owner's own accounts (their two SIMs, or MoMo's virtual card): neither spent nor received. Filed under Your Own Accounts.
_Avoid_: self-transfer, internal transfer

**Paying**:
Sending a payment to a recipient, from the amount to the code dialled: refused for a recipient that cannot be paid, recorded before it is dialled, whole or as a split payment, with the place it was made for Nearby (`Paying`). Dialling a code that pays no one (Buy's codes, Balance) is not paying.
_Avoid_: checkout, transfer

**Split payment**:
One payment sent as several smaller ones because together they cost less in fees (MTN's fee jumps from 250 to 1,500 past 150,000). Each is a **part**, its own transaction with its own SMS. Offered only with Split large payments on.
_Avoid_: instalment, chunk

**Counts**:
Whether a transaction counts in the owner's totals, chart, Report and summaries: it does unless it failed or is an own transfer. A pending payment counts, since it was dialled and most go through; a fee counts only once confirmed (`Transaction.counts`).
_Avoid_: valid, included

**Recipient**:
Who a payment goes to: a Rwandan mobile number or a merchant code. Two recipients are the same when their number or code is (`Recipient.Identity`), whatever name each was saved under; a contact can hold several.
_Avoid_: payee, beneficiary

**Category chosen by hand**:
A transaction's category that the owner picked themselves. StarHash never changes it.
_Avoid_: manual category, override

## Auto-verify

**Auto-verify**:
The wallet's SMS, handed to StarHash by the owner's Shortcuts automation, confirming each payment; and a payment no message confirms within the hour failing on its own. It is always in one of four states (`AutoVerify.Status`):
- **Off**: never set up, or turned off. Messages are ignored and payments stay pending until settled by hand.
- **Waiting**: set up with a shortcut that runs, but no real message has come through the automation since, so nothing fails on its own yet.
- **Active**: messages confirm payments, and one with none within the hour fails.
- **Looks broken**: no message for a week and the last three payments unconfirmed. The automation has likely stopped, so nothing more fails until a message comes.
_Avoid_: SMS sync, auto-confirm, verification (Verify is settling one payment by hand with its message)

**Proven**:
Auto-verify once a real message has come through the automation since the setup: Active or Looks broken. The setup's own check runs the shortcut by hand, which proves the shortcut but not the automation.
_Avoid_: verified, confirmed
