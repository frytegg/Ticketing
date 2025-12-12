// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseTicketing.t.sol";
import {TicketingErrors} from "../src/core/Errors.sol";

contract TicketingTicketsTest is BaseTicketingTest {
    function test_emitTickets_onlyArtistAdmin_andCapacity() public {
        address bad = makeAddr("bad");

        vm.prank(bad);
        vm.expectRevert(TicketingErrors.NotAuthorized.selector);
        ticketing.emitTickets(concertId, 1, 0.1 ether, true);

        // tiny venue/concert to test capacity
        vm.prank(venueAdmin);
        uint256 v2 = ticketing.createVenue("Small", 2, 1000, venuePayout);

        uint64 d2 = uint64(block.timestamp + 5 days);
        vm.prank(creator);
        uint256 c2 = ticketing.createConcert(d2, artistId, v2);

        vm.prank(artistAdmin);
        ticketing.emitTickets(c2, 2, 0.1 ether, true);

        vm.prank(artistAdmin);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.CapacityExceeded.selector, 2, 1, 2));
        ticketing.emitTickets(c2, 1, 0.1 ether, true);
    }

    function test_listBuy_primarySale_goesToContract_revenue() public {
        _confirmConcert(concertId);

        uint256 price = 0.2 ether;
        uint256 tid = _emitOneTicket(concertId, price, true);

        vm.prank(artistAdmin);
        ticketing.listTicket(tid, price);

        uint256 contractBalBefore = address(ticketing).balance;

        vm.prank(buyer1);
        ticketing.buyTicket{value: price}(tid);

        assertEq(address(ticketing).balance, contractBalBefore + price);

        TicketingTypes.Ticket memory t = _getTicket(tid);
        assertEq(t.owner, buyer1);
        assertEq(t.lastPaidPriceWei, price);
        assertFalse(t.listed);

        TicketingTypes.Artist memory a = ticketing.getArtist(artistId);
        assertEq(a.totalTicketsSold, 1);
    }

    function test_secondarySale_paysSellerImmediately_andCapped() public {
        _confirmConcert(concertId);

        uint256 price = 1 ether;
        uint256 tid = _emitOneTicket(concertId, price, true);

        vm.prank(artistAdmin);
        ticketing.listTicket(tid, price);

        vm.prank(buyer1);
        ticketing.buyTicket{value: price}(tid);

        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.PriceAboveCap.selector, price, price + 1));
        ticketing.listTicket(tid, price + 1);

        vm.prank(buyer1);
        ticketing.listTicket(tid, price);

        uint256 sellerBalBefore = buyer1.balance;

        vm.prank(buyer2);
        ticketing.buyTicket{value: price}(tid);

        assertEq(buyer1.balance, sellerBalBefore + price);

        TicketingTypes.Ticket memory t = _getTicket(tid);
        assertEq(t.owner, buyer2);
    }

    function test_transferTicket_failsIfListed_orAfterConcert() public {
        _confirmConcert(concertId);

        uint256 tid = _emitOneTicket(concertId, 0.5 ether, true);

        vm.prank(artistAdmin);
        ticketing.listTicket(tid, 0.5 ether);
        vm.prank(buyer1);
        ticketing.buyTicket{value: 0.5 ether}(tid);

        vm.prank(buyer1);
        ticketing.listTicket(tid, 0.5 ether);

        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.TicketAlreadyListed.selector, tid));
        ticketing.transferTicket(tid, buyer2);

        vm.prank(buyer1);
        ticketing.unlistTicket(tid);

        vm.prank(buyer1);
        ticketing.transferTicket(tid, buyer2);

        TicketingTypes.Ticket memory t = _getTicket(tid);
        assertEq(t.owner, buyer2);

        _warpTo(concertDate);
        vm.prank(buyer2);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.TicketUseWindowClosed.selector, tid));
        ticketing.transferTicket(tid, buyer1);
    }

    function test_useTicket_24hWindow_requiresConfirmed() public {
        uint256 tid = _emitOneTicket(concertId, 0.3 ether, true);

        _warpTo(uint64(concertDate - 12 hours));

        // not confirmed => cannot use
        vm.prank(artistAdmin);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.ConcertNotConfirmed.selector, concertId));
        ticketing.useTicket(tid);

        _confirmConcert(concertId);

        // too early
        _warpTo(uint64(concertDate - 24 hours - 1));
        vm.prank(artistAdmin);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.TicketNotUsableYet.selector, tid));
        ticketing.useTicket(tid);

        // within window => ok
        _warpTo(uint64(concertDate - 12 hours));
        vm.prank(artistAdmin);
        ticketing.useTicket(tid);

        // cannot reuse
        vm.prank(artistAdmin);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.TicketAlreadyUsed.selector, tid));
        ticketing.useTicket(tid);
    }

    function test_buyTicket_requiresExactPayment() public {
        _confirmConcert(concertId);

        uint256 tid = _emitOneTicket(concertId, 0.4 ether, true);

        vm.prank(artistAdmin);
        ticketing.listTicket(tid, 0.4 ether);

        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.InvalidPayment.selector, 0.4 ether, 0.3 ether));
        ticketing.buyTicket{value: 0.3 ether}(tid);
    }
}
