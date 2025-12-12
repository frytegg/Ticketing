// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library TicketingTypes {
    uint16 internal constant BPS_DENOMINATOR = 10_000;

    struct Artist {
        string name;
        string artistType;
        address admin; // can confirm concerts, emit tickets, cash out
        address payout; // receives artist share on cashout
        uint256 totalTicketsSold;
        bool exists;
    }

    struct Venue {
        string name;
        uint256 capacity; // max tickets for concerts at this venue
        uint16 venueShareBps; // % of ticket revenue in basis points (0..10000)
        address admin; // can confirm concerts
        address payout; // receives venue share on cashout
        bool exists;
    }

    struct Concert {
        uint64 date; // unix timestamp (seconds)
        uint256 artistId;
        uint256 venueId;

        bool confirmedByArtist;
        bool confirmedByVenue;
        bool cashedOut;

        uint256 revenueWei; // total paid into contract for this concert (primary+secondary if you route it)
        uint256 ticketsEmitted; // used to enforce venue capacity
        bool exists;
    }

    struct Ticket {
        uint256 concertId;
        address owner;

        // Anti-scalping: cannot sell for more than last paid price
        // Primary sale initializes this to the primary price.
        uint256 lastPaidPriceWei;

        bool used;

        // Redeem-only tickets set saleAllowed=false (cannot list/buy/trade)
        bool saleAllowed;

        // Simple built-in listing
        bool listed;
        uint256 listPriceWei;

        bool exists;
    }

    // Redeem codes (store hashes, not raw strings)
    struct RedeemCode {
        uint256 ticketId; // reserved/minted ticket tied to this code
        bool redeemed;
        bool exists;
    }
}
