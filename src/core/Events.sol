// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library TicketingEvents {
    // -------- Profiles --------
    event ArtistCreated(
        uint256 indexed artistId, address indexed admin, address indexed payout, string name, string artistType
    );
    event ArtistUpdated(
        uint256 indexed artistId, address indexed admin, address indexed payout, string name, string artistType
    );

    event VenueCreated(
        uint256 indexed venueId,
        address indexed admin,
        address indexed payout,
        string name,
        uint256 capacity,
        uint16 venueShareBps
    );
    event VenueUpdated(
        uint256 indexed venueId,
        address indexed admin,
        address indexed payout,
        string name,
        uint256 capacity,
        uint16 venueShareBps
    );

    // -------- Concerts --------
    event ConcertCreated(
        uint256 indexed concertId, uint256 indexed artistId, uint256 indexed venueId, uint64 date, address creator
    );
    event ConcertConfirmedByArtist(uint256 indexed concertId, uint256 indexed artistId, address confirmer);
    event ConcertConfirmedByVenue(uint256 indexed concertId, uint256 indexed venueId, address confirmer);

    // -------- Tickets --------
    event TicketsEmitted(uint256 indexed concertId, uint256 quantity, uint256 primaryPriceWei, bool saleAllowed);
    event TicketListed(uint256 indexed ticketId, uint256 priceWei);
    event TicketUnlisted(uint256 indexed ticketId);
    event TicketBought(uint256 indexed ticketId, address indexed from, address indexed to, uint256 priceWei);
    event TicketTransferred(uint256 indexed ticketId, address indexed from, address indexed to);
    event TicketUsed(uint256 indexed ticketId, address indexed user);

    // -------- Settlement --------
    event CashOut(
        uint256 indexed concertId,
        uint256 indexed artistId,
        uint256 indexed venueId,
        uint256 artistAmountWei,
        uint256 venueAmountWei
    );

    // -------- Redeem --------
    event RedeemCodeCreated(uint256 indexed concertId, bytes32 indexed codeHash, uint256 indexed ticketId);
    event TicketRedeemed(
        uint256 indexed concertId, bytes32 indexed codeHash, uint256 indexed ticketId, address redeemer
    );
}
