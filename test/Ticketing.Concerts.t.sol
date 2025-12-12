// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseTicketing.t.sol";
import {TicketingErrors} from "../src/core/Errors.sol";

contract TicketingConcertsTest is BaseTicketingTest {
    function test_anyoneCanCreateConcert() public {
        address random = makeAddr("random");
        vm.deal(random, 1 ether);

        uint64 date = uint64(block.timestamp + 10 days);

        vm.prank(random);
        uint256 cid = ticketing.createConcert(date, artistId, venueId);

        TicketingTypes.Concert memory c = ticketing.getConcert(cid);
        assertEq(c.artistId, artistId);
        assertEq(c.venueId, venueId);
        assertEq(c.date, date);
        assertFalse(c.confirmedByArtist);
        assertFalse(c.confirmedByVenue);
    }

    function test_confirmConcert_accessControl() public {
        address bad = makeAddr("bad");

        vm.prank(bad);
        vm.expectRevert(TicketingErrors.NotAuthorized.selector);
        ticketing.confirmConcertAsArtist(concertId);

        vm.prank(bad);
        vm.expectRevert(TicketingErrors.NotAuthorized.selector);
        ticketing.confirmConcertAsVenue(concertId);

        _confirmConcert(concertId);
        assertTrue(ticketing.isConcertConfirmed(concertId));
    }

    function test_cannotCreateConcertInPast() public {
        uint64 past = uint64(block.timestamp - 1);

        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.ConcertDateInPast.selector, past));
        ticketing.createConcert(past, artistId, venueId);
    }
}
