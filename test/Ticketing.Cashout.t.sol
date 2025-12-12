// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseTicketing.t.sol";
import {TicketingErrors} from "../src/core/Errors.sol";

contract TicketingCashoutTest is BaseTicketingTest {
    function test_cashOut_onlyAfterConcert_andSplitsRevenue() public {
        _confirmConcert(concertId);

        uint256 price = 2 ether;
        uint256 tid = _emitOneTicket(concertId, price, true);

        vm.prank(artistAdmin);
        ticketing.listTicket(tid, price);

        vm.prank(buyer1);
        ticketing.buyTicket{value: price}(tid);

        assertEq(address(ticketing).balance, price);

        vm.prank(artistAdmin);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.ConcertNotPassedYet.selector, concertId, concertDate));
        ticketing.cashOut(concertId);

        _warpTo(uint64(concertDate + 1));

        uint256 venueBalBefore = venuePayout.balance;
        uint256 artistBalBefore = artistPayout.balance;

        uint256 venueExpected = (price * 2500) / 10_000;
        uint256 artistExpected = price - venueExpected;

        vm.prank(artistAdmin);
        ticketing.cashOut(concertId);

        assertEq(venuePayout.balance, venueBalBefore + venueExpected);
        assertEq(artistPayout.balance, artistBalBefore + artistExpected);
        assertEq(address(ticketing).balance, 0);

        vm.prank(artistAdmin);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.ConcertAlreadyCashedOut.selector, concertId));
        ticketing.cashOut(concertId);
    }

    function test_cashOut_onlyArtistAdmin() public {
        _confirmConcert(concertId);

        _warpTo(uint64(concertDate + 1));
        address bad = makeAddr("bad");

        vm.prank(bad);
        vm.expectRevert(TicketingErrors.NotAuthorized.selector);
        ticketing.cashOut(concertId);
    }
}
