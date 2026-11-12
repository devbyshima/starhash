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
