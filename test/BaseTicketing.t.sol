// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {Ticketing} from "../src/Ticketing.sol";
import {TicketingTypes} from "../src/core/Types.sol";

abstract contract BaseTicketingTest is Test {
    Ticketing internal ticketing;

    address internal deployer;
    address internal artistAdmin;
    address internal venueAdmin;

    address internal artistPayout;
    address internal venuePayout;

    address internal creator;

    address internal buyer1;
    address internal buyer2;

    uint256 internal artistId;
    uint256 internal venueId;
    uint256 internal concertId;

    uint64 internal concertDate;

    function setUp() public virtual {
        // Deterministic, valid addresses
        deployer = makeAddr("deployer");
        artistAdmin = makeAddr("artistAdmin");
        venueAdmin = makeAddr("venueAdmin");
        artistPayout = makeAddr("artistPayout");
        venuePayout = makeAddr("venuePayout");
        creator = makeAddr("creator");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");

        vm.startPrank(deployer);
        ticketing = new Ticketing();
        vm.stopPrank();

        // Fund accounts used in tests
        vm.deal(artistAdmin, 100 ether);
        vm.deal(venueAdmin, 100 ether);
        vm.deal(creator, 100 ether);
        vm.deal(buyer1, 100 ether);
        vm.deal(buyer2, 100 ether);

        // Create a default artist + venue + concert for tests
        vm.prank(artistAdmin);
        artistId = ticketing.createArtist("Artist", "Band", artistPayout);

        vm.prank(venueAdmin);
        venueId = ticketing.createVenue("Venue", 100, 2500, venuePayout); // 25%

        concertDate = uint64(block.timestamp + 3 days);

        vm.prank(creator);
        concertId = ticketing.createConcert(concertDate, artistId, venueId);
    }

    function _confirmConcert(uint256 _concertId) internal {
        vm.prank(artistAdmin);
        ticketing.confirmConcertAsArtist(_concertId);

        vm.prank(venueAdmin);
        ticketing.confirmConcertAsVenue(_concertId);
    }

    function _emitOneTicket(uint256 _concertId, uint256 primaryPriceWei, bool saleAllowed)
        internal
        returns (uint256 ticketId)
    {
        vm.prank(artistAdmin);
        ticketId = ticketing.emitTickets(_concertId, 1, primaryPriceWei, saleAllowed);
    }

    function _getTicket(uint256 ticketId) internal view returns (TicketingTypes.Ticket memory) {
        return ticketing.getTicket(ticketId);
    }

    function _warpTo(uint64 ts) internal {
        vm.warp(ts);
    }
}
