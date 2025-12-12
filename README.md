# Ticketing (Blockchain Programming TD)

This project is a simple on-chain ticketing system for concerts.  
It manages **artists**, **venues**, **concerts**, and **tickets**, with rules enforced by the smart contract.

## What the contract does

The main contract is: `src/Ticketing.sol`

It supports:

- **Artist profiles**
  - name, type, admin address, payout address
  - tracks `totalTicketsSold` (counted on primary sales)

- **Venue profiles**
  - name, capacity, admin address, payout address
  - venue share in **basis points** (example: `2500` = 25%)

- **Concerts**
  - anyone can create a concert with (date, artistId, venueId)
  - **must be confirmed by both** the artist admin and venue admin before tickets can be used
  - stores revenue from primary sales for later cashout

- **Tickets**
  - artist can **emit/mint** tickets for a concert (owned by artist at first)
  - tickets can be listed and bought (marketplace inside the contract)
  - owner can **use a ticket only during the 24h before the concert** (and only if concert is confirmed)
  - ticket resale is **price-capped** to prevent scalping: you can’t list for more than the last paid price
  - gift transfers are possible (`transferTicket`)

- **Cashout**
  - after the concert date has passed, the artist admin can cash out
  - money is split between venue and artist using venueShareBps
  - only primary sale revenue is held by the contract (secondary sales are paid directly to the seller)

- **Redeem codes**
  - artist can generate tickets tied to secret codes
  - users redeem with `redeemTicket(concertId, code)`
  - redeemed tickets are **not sellable** (saleAllowed = false)

---

## Quick overview of the workflow

### 1) Create profiles
- Artist creates themselves:
  - `createArtist(name, artistType, payout)`
- Venue creates themselves:
  - `createVenue(name, capacity, venueShareBps, payout)`

The caller becomes the **admin** of that profile.

### 2) Create a concert
Anyone can call:
- `createConcert(date, artistId, venueId)`

Then confirmations:
- Artist admin: `confirmConcertAsArtist(concertId)`
- Venue admin: `confirmConcertAsVenue(concertId)`

A concert is “valid” when both confirmations are done.

### 3) Emit tickets
Artist admin calls:
- `emitTickets(concertId, quantity, primaryPriceWei, saleAllowed)`

Notes:
- Capacity is enforced using the venue capacity.
- Tickets are minted and owned by the artist admin initially.

### 4) Sell and buy tickets
Seller lists:
- `listTicket(ticketId, priceWei)`

Buyer buys:
- `buyTicket(ticketId)` (payable)

Anti-scalping rule:
- listing price must be `<= lastPaidPriceWei`

Primary vs secondary:
- If the **artist sells a freshly minted ticket**, the contract keeps the funds for later cashout.
- If a **normal user resells**, the seller is paid immediately.

### 5) Use ticket (check-in)
Ticket owner calls:
- `useTicket(ticketId)`

Conditions:
- concert must be confirmed
- current time must be within `[concertDate - 24h, concertDate]`
- ticket can be used only once

### 6) Cashout (after concert)
Artist admin calls:
- `cashOut(concertId)`

Conditions:
- concert confirmed
- current time > concert date
- not cashed out already

Split:
- venue gets `revenue * venueShareBps / 10000`
- artist gets the rest

### 7) Redeem tickets
Artist admin pre-creates redeem tickets:
- `createRedeemCodes(concertId, codes[])`

User redeems:
- `redeemTicket(concertId, "CODE")`

Redeemed tickets:
- are owned by the redeemer
- cannot be listed or sold

---


## Build and test (Foundry)

### Install dependencies
If you haven’t already:
```bash
forge install
forge build
forge test -vv

forge script script/Deploy.s.sol

```

Deploy to a real network (or local node)

You need an RPC URL and a private key.

Example:

```bash

forge script script/Deploy.s.sol \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY> \
  --broadcast

```
