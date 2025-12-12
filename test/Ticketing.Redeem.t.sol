// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseTicketing.t.sol";
import {TicketingErrors} from "../src/core/Errors.sol";

contract TicketingRedeemTest is BaseTicketingTest {
    function test_createRedeemCodes_andRedeem_once_only() public {
        vm.prank(venueAdmin);
        uint256 v2 = ticketing.createVenue("Small", 2, 1000, venuePayout);

        uint64 d2 = uint64(block.timestamp + 7 days);
        vm.prank(creator);
        uint256 c2 = ticketing.createConcert(d2, artistId, v2);
        string[] memory codes = new string[](2);
        codes[0] = "CODE-AAA";
        codes[1] = "CODE-BBB";

        vm.prank(artistAdmin);
        uint256[] memory tids = ticketing.createRedeemCodes(c2, codes);
        assertEq(tids.length, 2);

        vm.prank(buyer1);
        uint256 redeemedId = ticketing.redeemTicket(c2, "CODE-AAA");

        TicketingTypes.Ticket memory t = ticketing.getTicket(redeemedId);
        assertEq(t.owner, buyer1);
        assertFalse(t.saleAllowed);

        vm.prank(buyer2);
        vm.expectRevert(TicketingErrors.RedeemCodeAlreadyUsed.selector);
        ticketing.redeemTicket(c2, "CODE-AAA");

        vm.prank(buyer2);
        vm.expectRevert(TicketingErrors.InvalidRedeemCode.selector);
        ticketing.redeemTicket(c2, "NOPE");
    }

    function test_redeemedTickets_cannotBeSold() public {
        string[] memory codes = new string[](1);
        codes[0] = "FREE-1";

        vm.prank(artistAdmin);
        uint256[] memory tids = ticketing.createRedeemCodes(concertId, codes);

        vm.prank(buyer1);
        uint256 tid = ticketing.redeemTicket(concertId, "FREE-1");
        assertEq(tid, tids[0]);

        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.TicketSaleNotAllowed.selector, tid));
        ticketing.listTicket(tid, 1 wei);
    }

    function test_createRedeemCodes_capacityExceeded() public {
        vm.prank(venueAdmin);
        uint256 v2 = ticketing.createVenue("Small", 1, 1000, venuePayout);

        uint64 d2 = uint64(block.timestamp + 7 days);
        vm.prank(creator);
        uint256 c2 = ticketing.createConcert(d2, artistId, v2);
        string[] memory codes = new string[](2);
        codes[0] = "A";
        codes[1] = "B";

        vm.prank(artistAdmin);
        vm.expectRevert(abi.encodeWithSelector(TicketingErrors.CapacityExceeded.selector, 1, 2, 0));
        ticketing.createRedeemCodes(c2, codes);
    }
}
