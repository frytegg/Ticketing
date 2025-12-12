// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TicketingTypes} from "./core/Types.sol";
import {TicketingErrors} from "./core/Errors.sol";
import {TicketingEvents} from "./core/Events.sol";

import {PricingLib} from "./libraries/PricingLib.sol";
import {RedeemCodeLib} from "./libraries/RedeemCodeLib.sol";

contract Ticketing {
    using PricingLib for uint256;

    // -----------------------
    // Reentrancy guard
    // -----------------------
    uint256 private _lock = 1;
    modifier nonReentrant() {
        require(_lock == 1, "REENTRANCY");
        _lock = 2;
        _;
        _lock = 1;
    }

    // -----------------------
    // Storage
    // -----------------------
    uint256 private _nextArtistId = 1;
    uint256 private _nextVenueId = 1;
    uint256 private _nextConcertId = 1;
    uint256 private _nextTicketId = 1;

    mapping(uint256 => TicketingTypes.Artist) private _artists;
    mapping(uint256 => TicketingTypes.Venue) private _venues;
    mapping(uint256 => TicketingTypes.Concert) private _concerts;
    mapping(uint256 => TicketingTypes.Ticket) private _tickets;

    // Anti-double-counting: only first sale from artist counts as primary revenue.
    mapping(uint256 => bool) private _primarySold;

    // concertId => codeHash => RedeemCode
    mapping(uint256 => mapping(bytes32 => TicketingTypes.RedeemCode)) private _redeemCodes;

    // -----------------------
    // ETH handling
    // -----------------------
    receive() external payable {}

    function _sendETH(address to, uint256 amountWei) internal {
        if (amountWei == 0) return;
        (bool ok,) = to.call{value: amountWei}("");
        require(ok, "ETH_SEND_FAIL");
    }

    // -----------------------
    // Modifiers / checks
    // -----------------------
    function _requireArtist(uint256 artistId) internal view {
        if (!_artists[artistId].exists) revert TicketingErrors.ArtistDoesNotExist(artistId);
    }

    function _requireVenue(uint256 venueId) internal view {
        if (!_venues[venueId].exists) revert TicketingErrors.VenueDoesNotExist(venueId);
    }

    function _requireConcert(uint256 concertId) internal view {
        if (!_concerts[concertId].exists) revert TicketingErrors.ConcertDoesNotExist(concertId);
    }

    function _requireTicket(uint256 ticketId) internal view {
        if (!_tickets[ticketId].exists) revert TicketingErrors.TicketDoesNotExist(ticketId);
    }

    modifier onlyArtistAdmin(uint256 artistId) {
        _requireArtist(artistId);
        if (msg.sender != _artists[artistId].admin) revert TicketingErrors.NotAuthorized();
        _;
    }

    modifier onlyVenueAdmin(uint256 venueId) {
        _requireVenue(venueId);
        if (msg.sender != _venues[venueId].admin) revert TicketingErrors.NotAuthorized();
        _;
    }

    // -----------------------
    // Views (helpers for tests/UI)
    // -----------------------
    function nextIds()
        external
        view
        returns (uint256 nextArtistId, uint256 nextVenueId, uint256 nextConcertId, uint256 nextTicketId)
    {
        return (_nextArtistId, _nextVenueId, _nextConcertId, _nextTicketId);
    }

    function getArtist(uint256 artistId) external view returns (TicketingTypes.Artist memory) {
        _requireArtist(artistId);
        return _artists[artistId];
    }

    function getVenue(uint256 venueId) external view returns (TicketingTypes.Venue memory) {
        _requireVenue(venueId);
        return _venues[venueId];
    }

    function getConcert(uint256 concertId) external view returns (TicketingTypes.Concert memory) {
        _requireConcert(concertId);
        return _concerts[concertId];
    }

    function getTicket(uint256 ticketId) external view returns (TicketingTypes.Ticket memory) {
        _requireTicket(ticketId);
        return _tickets[ticketId];
    }

    function isConcertConfirmed(uint256 concertId) public view returns (bool) {
        _requireConcert(concertId);
        TicketingTypes.Concert storage c = _concerts[concertId];
        return c.confirmedByArtist && c.confirmedByVenue;
    }

    // -----------------------
    // Artists
    // -----------------------
    function createArtist(string calldata name, string calldata artistType, address payout)
        external
        returns (uint256 artistId)
    {
        if (bytes(name).length == 0) revert TicketingErrors.InvalidInput();
        if (payout == address(0)) revert TicketingErrors.InvalidInput();

        artistId = _nextArtistId++;
        _artists[artistId] = TicketingTypes.Artist({
            name: name, artistType: artistType, admin: msg.sender, payout: payout, totalTicketsSold: 0, exists: true
        });

        emit TicketingEvents.ArtistCreated(artistId, msg.sender, payout, name, artistType);
    }

    function updateArtist(
        uint256 artistId,
        string calldata name,
        string calldata artistType,
        address newAdmin,
        address payout
    ) external onlyArtistAdmin(artistId) {
        if (bytes(name).length == 0) revert TicketingErrors.InvalidInput();
        if (newAdmin == address(0) || payout == address(0)) revert TicketingErrors.InvalidInput();

        TicketingTypes.Artist storage a = _artists[artistId];
        a.name = name;
        a.artistType = artistType;
        a.admin = newAdmin;
        a.payout = payout;

        emit TicketingEvents.ArtistUpdated(artistId, newAdmin, payout, name, artistType);
    }

    // -----------------------
    // Venues
    // -----------------------
    function createVenue(string calldata name, uint256 capacity, uint16 venueShareBps, address payout)
        external
        returns (uint256 venueId)
    {
        if (bytes(name).length == 0) revert TicketingErrors.InvalidInput();
        if (capacity == 0) revert TicketingErrors.InvalidInput();
        if (payout == address(0)) revert TicketingErrors.InvalidInput();
        if (venueShareBps > TicketingTypes.BPS_DENOMINATOR) revert TicketingErrors.InvalidVenueShareBps(venueShareBps);

        venueId = _nextVenueId++;
        _venues[venueId] = TicketingTypes.Venue({
            name: name,
            capacity: capacity,
            venueShareBps: venueShareBps,
            admin: msg.sender,
            payout: payout,
            exists: true
        });

        emit TicketingEvents.VenueCreated(venueId, msg.sender, payout, name, capacity, venueShareBps);
    }

    function updateVenue(
        uint256 venueId,
        string calldata name,
        uint256 capacity,
        uint16 venueShareBps,
        address newAdmin,
        address payout
    ) external onlyVenueAdmin(venueId) {
        if (bytes(name).length == 0) revert TicketingErrors.InvalidInput();
        if (capacity == 0) revert TicketingErrors.InvalidInput();
        if (newAdmin == address(0) || payout == address(0)) revert TicketingErrors.InvalidInput();
        if (venueShareBps > TicketingTypes.BPS_DENOMINATOR) revert TicketingErrors.InvalidVenueShareBps(venueShareBps);

        TicketingTypes.Venue storage v = _venues[venueId];
        v.name = name;
        v.capacity = capacity;
        v.venueShareBps = venueShareBps;
        v.admin = newAdmin;
        v.payout = payout;

        emit TicketingEvents.VenueUpdated(venueId, newAdmin, payout, name, capacity, venueShareBps);
    }

    // -----------------------
    // Concerts
    // -----------------------
    /// @notice Anyone can create a concert, but it must be confirmed by both artist & venue to be "valid".
    function createConcert(uint64 date, uint256 artistId, uint256 venueId) external returns (uint256 concertId) {
        _requireArtist(artistId);
        _requireVenue(venueId);
        if (date <= uint64(block.timestamp)) revert TicketingErrors.ConcertDateInPast(date);

        concertId = _nextConcertId++;
        _concerts[concertId] = TicketingTypes.Concert({
            date: date,
            artistId: artistId,
            venueId: venueId,
            confirmedByArtist: false,
            confirmedByVenue: false,
            cashedOut: false,
            revenueWei: 0,
            ticketsEmitted: 0,
            exists: true
        });

        emit TicketingEvents.ConcertCreated(concertId, artistId, venueId, date, msg.sender);
    }

    function confirmConcertAsArtist(uint256 concertId) external {
        _requireConcert(concertId);
        TicketingTypes.Concert storage c = _concerts[concertId];
        _requireArtist(c.artistId);

        if (msg.sender != _artists[c.artistId].admin) revert TicketingErrors.NotAuthorized();
        c.confirmedByArtist = true;

        emit TicketingEvents.ConcertConfirmedByArtist(concertId, c.artistId, msg.sender);
    }

    function confirmConcertAsVenue(uint256 concertId) external {
        _requireConcert(concertId);
        TicketingTypes.Concert storage c = _concerts[concertId];
        _requireVenue(c.venueId);

        if (msg.sender != _venues[c.venueId].admin) revert TicketingErrors.NotAuthorized();
        c.confirmedByVenue = true;

        emit TicketingEvents.ConcertConfirmedByVenue(concertId, c.venueId, msg.sender);
    }

    // -----------------------
    // Ticket minting (artist) and redeem codes
    // -----------------------
    function _checkCapacity(uint256 concertId, uint256 additional) internal view {
        TicketingTypes.Concert storage c = _concerts[concertId];
        uint256 cap = _venues[c.venueId].capacity;
        if (c.ticketsEmitted + additional > cap) {
            revert TicketingErrors.CapacityExceeded(cap, additional, c.ticketsEmitted);
        }
    }

    function _mintTicket(uint256 concertId, address owner, uint256 lastPaidPriceWei, bool saleAllowed)
        internal
        returns (uint256 ticketId)
    {
        ticketId = _nextTicketId++;
        _tickets[ticketId] = TicketingTypes.Ticket({
            concertId: concertId,
            owner: owner,
            lastPaidPriceWei: lastPaidPriceWei,
            used: false,
            saleAllowed: saleAllowed,
            listed: false,
            listPriceWei: 0,
            exists: true
        });
    }

    /// @notice Artist emits tickets (owned by artist admin). These can be sold/transferred.
    function emitTickets(uint256 concertId, uint256 quantity, uint256 primaryPriceWei, bool saleAllowed)
        external
        returns (uint256 firstTicketId)
    {
        _requireConcert(concertId);
        TicketingTypes.Concert storage c = _concerts[concertId];

        // only the artist admin for this concert can emit
        if (msg.sender != _artists[c.artistId].admin) revert TicketingErrors.NotAuthorized();
        if (quantity == 0) revert TicketingErrors.InvalidInput();

        _checkCapacity(concertId, quantity);

        // Mint tickets to artist admin
        address artistAdmin = _artists[c.artistId].admin;

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tid = _mintTicket(concertId, artistAdmin, primaryPriceWei, saleAllowed);
            if (i == 0) firstTicketId = tid;
            _primarySold[tid] = false;
        }

        c.ticketsEmitted += quantity;

        emit TicketingEvents.TicketsEmitted(concertId, quantity, primaryPriceWei, saleAllowed);
    }

    /// @notice Create redeem codes for distributed tickets (cannot be sold).
    /// @dev Stores hashes only; pre-mints reserved tickets owned by address(0) until redeemed.
    function createRedeemCodes(uint256 concertId, string[] calldata codes)
        external
        returns (uint256[] memory ticketIds)
    {
        _requireConcert(concertId);
        TicketingTypes.Concert storage c = _concerts[concertId];

        if (msg.sender != _artists[c.artistId].admin) revert TicketingErrors.NotAuthorized();
        if (codes.length == 0) revert TicketingErrors.InvalidInput();

        _checkCapacity(concertId, codes.length);

        ticketIds = new uint256[](codes.length);

        for (uint256 i = 0; i < codes.length; i++) {
            bytes32 h = RedeemCodeLib.hashCode(codes[i]);
            if (_redeemCodes[concertId][h].exists) revert TicketingErrors.AlreadyExists();

            uint256 tid = _mintTicket(concertId, address(0), 0, false);
            _primarySold[tid] = true; // never counts as primary sale revenue

            _redeemCodes[concertId][h] = TicketingTypes.RedeemCode({ticketId: tid, redeemed: false, exists: true});

            ticketIds[i] = tid;
            emit TicketingEvents.RedeemCodeCreated(concertId, h, tid);
        }

        c.ticketsEmitted += codes.length;
    }

    /// @notice Redeem a distributed ticket using a code.
    function redeemTicket(uint256 concertId, string calldata code) external returns (uint256 ticketId) {
        _requireConcert(concertId);

        bytes32 h = RedeemCodeLib.hashCode(code);
        TicketingTypes.RedeemCode storage rc = _redeemCodes[concertId][h];
        if (!rc.exists) revert TicketingErrors.InvalidRedeemCode();
        if (rc.redeemed) revert TicketingErrors.RedeemCodeAlreadyUsed();

        ticketId = rc.ticketId;
        _requireTicket(ticketId);

        TicketingTypes.Ticket storage t = _tickets[ticketId];
        if (t.owner != address(0)) revert TicketingErrors.InvalidRedeemCode();

        rc.redeemed = true;
        t.owner = msg.sender;

        emit TicketingEvents.TicketRedeemed(concertId, h, ticketId, msg.sender);
    }

    // -----------------------
    // Listing / buying / transferring
    // -----------------------
    function listTicket(uint256 ticketId, uint256 priceWei) external {
        _requireTicket(ticketId);
        TicketingTypes.Ticket storage t = _tickets[ticketId];

        if (t.owner != msg.sender) revert TicketingErrors.TicketNotOwned(ticketId);
        if (t.used) revert TicketingErrors.TicketAlreadyUsed(ticketId);
        if (!t.saleAllowed) revert TicketingErrors.TicketSaleNotAllowed(ticketId);
        if (t.listed) revert TicketingErrors.TicketAlreadyListed(ticketId);

        TicketingTypes.Concert storage c = _concerts[t.concertId];
        if (uint64(block.timestamp) >= c.date) revert TicketingErrors.TicketUseWindowClosed(ticketId);

        // Anti-scalping: cannot sell above last paid price (primary price initializes lastPaidPriceWei)
        PricingLib.enforcePriceCap(t.lastPaidPriceWei, priceWei);

        t.listed = true;
        t.listPriceWei = priceWei;

        emit TicketingEvents.TicketListed(ticketId, priceWei);
    }

    function unlistTicket(uint256 ticketId) external {
        _requireTicket(ticketId);
        TicketingTypes.Ticket storage t = _tickets[ticketId];

        if (t.owner != msg.sender) revert TicketingErrors.TicketNotOwned(ticketId);
        if (!t.listed) revert TicketingErrors.TicketNotListed(ticketId);

        t.listed = false;
        t.listPriceWei = 0;

        emit TicketingEvents.TicketUnlisted(ticketId);
    }

    function buyTicket(uint256 ticketId) external payable nonReentrant {
        _buyTicket(ticketId, msg.value);
    }

    /// @notice Alias to satisfy “safe trade ticket for money” requirement.
    /// @dev Atomic: payment + ownership transfer happen in one transaction.
    function safeTrade(uint256 ticketId) external payable nonReentrant {
        _buyTicket(ticketId, msg.value);
    }

    function _buyTicket(uint256 ticketId, uint256 valueWei) internal {
        _requireTicket(ticketId);
        TicketingTypes.Ticket storage t = _tickets[ticketId];

        if (!t.listed) revert TicketingErrors.TicketNotListed(ticketId);
        if (t.used) revert TicketingErrors.TicketAlreadyUsed(ticketId);
        if (!t.saleAllowed) revert TicketingErrors.TicketSaleNotAllowed(ticketId);

        TicketingTypes.Concert storage c = _concerts[t.concertId];
        if (uint64(block.timestamp) >= c.date) revert TicketingErrors.TicketUseWindowClosed(ticketId);

        uint256 priceWei = t.listPriceWei;
        PricingLib.enforceExactPayment(priceWei, valueWei);

        address seller = t.owner;
        if (seller == address(0) || seller == msg.sender) revert TicketingErrors.InvalidInput();

        // Unlist + transfer
        t.listed = false;
        t.listPriceWei = 0;
        t.owner = msg.sender;

        // Update cap for next sale
        t.lastPaidPriceWei = priceWei;

        // Primary sale revenue goes to contract for later split cashout.
        address artistAdmin = _artists[c.artistId].admin;
        bool isPrimary = (seller == artistAdmin) && (!_primarySold[ticketId]);

        if (isPrimary) {
            _primarySold[ticketId] = true;
            c.revenueWei += priceWei;
            _artists[c.artistId].totalTicketsSold += 1;
        } else {
            // Secondary sale pays seller immediately (still capped by lastPaidPriceWei rule)
            _sendETH(seller, priceWei);
        }

        emit TicketingEvents.TicketBought(ticketId, seller, msg.sender, priceWei);
    }

    /// @notice Gift transfer (no payment).
    function transferTicket(uint256 ticketId, address to) external {
        _requireTicket(ticketId);
        TicketingTypes.Ticket storage t = _tickets[ticketId];

        if (t.owner != msg.sender) revert TicketingErrors.TicketNotOwned(ticketId);
        if (to == address(0) || to == msg.sender) revert TicketingErrors.InvalidInput();
        if (t.used) revert TicketingErrors.TicketAlreadyUsed(ticketId);

        TicketingTypes.Concert storage c = _concerts[t.concertId];
        if (uint64(block.timestamp) >= c.date) revert TicketingErrors.TicketUseWindowClosed(ticketId);

        // cannot transfer while listed (force explicit unlist)
        if (t.listed) revert TicketingErrors.TicketAlreadyListed(ticketId);

        t.owner = to;

        emit TicketingEvents.TicketTransferred(ticketId, msg.sender, to);
    }

    // -----------------------
    // Use ticket (24h before concert)
    // -----------------------
    function useTicket(uint256 ticketId) external {
        _requireTicket(ticketId);
        TicketingTypes.Ticket storage t = _tickets[ticketId];

        if (t.owner != msg.sender) revert TicketingErrors.TicketNotOwned(ticketId);
        if (t.used) revert TicketingErrors.TicketAlreadyUsed(ticketId);

        TicketingTypes.Concert storage c = _concerts[t.concertId];
        if (!isConcertConfirmed(t.concertId)) revert TicketingErrors.ConcertNotConfirmed(t.concertId);

        uint64 concertDate = c.date;
        uint64 nowTs = uint64(block.timestamp);

        // usable in the 24h window BEFORE the concert, up to the concert time
        uint64 windowStart = concertDate - 24 hours;

        if (nowTs < windowStart) revert TicketingErrors.TicketNotUsableYet(ticketId);
        if (nowTs > concertDate) revert TicketingErrors.TicketUseWindowClosed(ticketId);

        t.used = true;

        emit TicketingEvents.TicketUsed(ticketId, msg.sender);
    }

    // -----------------------
    // Cashout (artist triggers after concert)
    // -----------------------
    function cashOut(uint256 concertId) external nonReentrant {
        _requireConcert(concertId);
        TicketingTypes.Concert storage c = _concerts[concertId];

        // only concert's artist admin can cash out
        if (msg.sender != _artists[c.artistId].admin) revert TicketingErrors.NotAuthorized();

        if (!isConcertConfirmed(concertId)) revert TicketingErrors.ConcertNotConfirmed(concertId);
        if (c.cashedOut) revert TicketingErrors.ConcertAlreadyCashedOut(concertId);

        if (uint64(block.timestamp) <= c.date) revert TicketingErrors.ConcertNotPassedYet(concertId, c.date);

        c.cashedOut = true;

        uint256 revenue = c.revenueWei;
        c.revenueWei = 0;

        TicketingTypes.Venue storage v = _venues[c.venueId];
        TicketingTypes.Artist storage a = _artists[c.artistId];

        uint256 venueAmount = (revenue * uint256(v.venueShareBps)) / TicketingTypes.BPS_DENOMINATOR;
        uint256 artistAmount = revenue - venueAmount;

        _sendETH(v.payout, venueAmount);
        _sendETH(a.payout, artistAmount);

        emit TicketingEvents.CashOut(concertId, c.artistId, c.venueId, artistAmount, venueAmount);
    }
}
