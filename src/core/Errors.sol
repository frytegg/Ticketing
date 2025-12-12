// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library TicketingErrors {
    // -------- Generic --------
    error NotAuthorized();
    error InvalidInput();
    error NotFound();
    error AlreadyExists();

    // -------- Profiles --------
    error ArtistDoesNotExist(uint256 artistId);
    error VenueDoesNotExist(uint256 venueId);
    error InvalidVenueShareBps(uint16 bps);

    // -------- Concerts --------
    error ConcertDoesNotExist(uint256 concertId);
    error ConcertDateInPast(uint64 date);
    error ConcertNotConfirmed(uint256 concertId);
    error ConcertAlreadyCashedOut(uint256 concertId);
    error ConcertNotPassedYet(uint256 concertId, uint64 date);

    // -------- Tickets --------
    error TicketDoesNotExist(uint256 ticketId);
    error TicketNotOwned(uint256 ticketId);
    error TicketAlreadyUsed(uint256 ticketId);
    error TicketNotUsableYet(uint256 ticketId);
    error TicketUseWindowClosed(uint256 ticketId);
    error TicketSaleNotAllowed(uint256 ticketId);

    error TicketNotListed(uint256 ticketId);
    error TicketAlreadyListed(uint256 ticketId);
    error InvalidPayment(uint256 expectedWei, uint256 actualWei);

    // Anti-scalping
    error PriceAboveCap(uint256 capWei, uint256 askedWei);

    // Capacity
    error CapacityExceeded(uint256 capacity, uint256 requested, uint256 emitted);

    // Redeem
    error InvalidRedeemCode();
    error RedeemCodeAlreadyUsed();
}
