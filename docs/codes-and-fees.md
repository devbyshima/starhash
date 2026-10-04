# Codes and fees

StarHash dials USSD codes on your behalf. This page lists every code it builds, how it reads what you type, and how fees are worked out.

## Payment codes

MTN MoMo and Airtel Money share the `*182#` menu, so the codes are the same from either wallet. Only which network counts as "other" changes.

| What | Code |
| --- | --- |
| Send to a number on your wallet's network | `*182*1*1*NUMBER*AMOUNT#` |
| Send to a number on the other network | `*182*1*2*NUMBER*AMOUNT#` |
| Pay a merchant code | `*182*8*1*CODE*AMOUNT#` |
| Check your balance, MTN MoMo | `*182*6*1#` |
| Check your balance, Airtel Money | `*182#` (the menu: no balance shortcut has been confirmed) |

The code is opened as a `tel:` link, with each `#` sent as `%23`.

> [!WARNING]
> The Airtel codes follow Airtel Rwanda's Airtel Money customer service charter (`*182#`, and `*182*8*1#` for merchants) and its note that `*182*1*2#` sends between Airtel Money and MTN MoMo. They still need a check on a real Airtel SIM.

## How what you type is read

- Ten digits or more is a phone number. `+250 788 123 456` and `00250788123456` both become `0788123456`.
- Fewer than ten digits is a MoMo Pay merchant code.
- Numbers starting 072 or 073 are Airtel; 078 and 079 are MTN.
- A number on the other network from your wallet is sent with `*182*1*2*`.
- Amounts are whole francs, from 1 to 10,000,000 RWF.

StarHash only dials a recipient it can pay: a sender whose number is masked in an SMS, for example, has nothing to dial.

## Buy's codes

Buy comes with four codes. Each opens a menu that asks for the amount and your PIN, so Buy's dials are not logged in Activity.

| Code | What it does |
| --- | --- |
| `*182*7*1#` | Pending approvals: payments waiting for your PIN, such as a shop's or Irembo's request |
| `*182*7*2#` | Cash out: start a withdrawal, which MTN asks for before an agent's prompt |
| `*154*0#` | Gwamon' Pack: MTN's minutes and data, for 7 days |
| `*182*3*8#` | Airport parking: pay a Kigali airport parking ticket |

These are MTN codes, shown whichever wallet you use. You can add your own: a code must start with `*` or `#`, end with `#`, and hold only digits, `*` and `#`.

## Fees

Pay never shows a fee. Fees appear only in Activity, once a payment is confirmed:

- **Confirmed by SMS**: the fee is the one in your wallet's message.
- **Confirmed by hand**: the fee is worked out from the carriers' published prices, for the wallet the payment was dialled with.

A pending payment has no fee yet, and marking a payment failed clears it.

### Published prices used (checked 4 October 2026)

**MTN MoMo to MTN MoMo**

| Amount (RWF) | Fee (RWF) |
| --- | --- |
| 1 to 1,000 | 20 |
| 1,001 to 10,000 | 100 |
| 10,001 to 150,000 | 250 |
| 150,001 to 2,000,000 | 1,500 |
| 2,000,001 to 5,000,000 | 3,000 |
| 5,000,001 to 10,000,000 | 5,000 |

**Everything else**

| Payment | Fee (RWF) |
| --- | --- |
| To the other network | 20: transfers between providers run over eKash since 14 July 2026, capped at 20 |
| Airtel Money to Airtel Money | 0: Airtel Rwanda made sending free in June 2021 |
| To a merchant code | 0 for the payer |
| Money received | 0 |

The sources are listed in `Packages/StarHashKit/Sources/StarHashKit/Tariff.swift`. If a carrier changes its prices, a payment confirmed by SMS still shows the right fee; only payments confirmed by hand use these tables.
