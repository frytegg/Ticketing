// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseTicketing.t.sol";
import {TicketingErrors} from "../src/core/Errors.sol";

contract TicketingProfilesTest is BaseTicketingTest {
    function test_createArtist_setsAdminAndPayout() public {
        address newAdmin = makeAddr("newAdmin");
        address newPayout = makeAddr("newPayout");

        vm.prank(newAdmin);
        uint256 id = ticketing.createArtist("X", "Solo", newPayout);

        TicketingTypes.Artist memory a = ticketing.getArtist(id);
        assertEq(a.admin, newAdmin);
        assertEq(a.payout, newPayout);
        assertEq(a.totalTicketsSold, 0);
        assertTrue(a.exists);
    }

    function test_updateArtist_onlyAdmin() public {
        address bad = makeAddr("bad");

        vm.prank(bad);
        vm.expectRevert(TicketingErrors.NotAuthorized.selector);
        ticketing.updateArtist(artistId, "New", "Type", artistAdmin, artistPayout);

        address newAdmin = makeAddr("artistAdmin2");
        address newPayout = makeAddr("artistPayout2");

        vm.prank(artistAdmin);
        ticketing.updateArtist(artistId, "NewName", "NewType", newAdmin, newPayout);

        TicketingTypes.Artist memory a = ticketing.getArtist(artistId);
        assertEq(a.admin, newAdmin);
        assertEq(a.payout, newPayout);
        assertEq(a.name, "NewName");
        assertEq(a.artistType, "NewType");
    }

    function test_createVenue_setsAdminAndShare() public {
        address vAdmin = makeAddr("vAdmin");
        address vPayout = makeAddr("vPayout");

        vm.prank(vAdmin);
        uint256 id = ticketing.createVenue("Hall", 500, 1000, vPayout); // 10%

        TicketingTypes.Venue memory v = ticketing.getVenue(id);
        assertEq(v.admin, vAdmin);
        assertEq(v.payout, vPayout);
        assertEq(v.capacity, 500);
        assertEq(v.venueShareBps, 1000);
        assertTrue(v.exists);
    }

    function test_updateVenue_onlyAdmin() public {
        address bad = makeAddr("bad");

        vm.prank(bad);
        vm.expectRevert(TicketingErrors.NotAuthorized.selector);
        ticketing.updateVenue(venueId, "V2", 99, 2000, venueAdmin, venuePayout);

        address newAdmin = makeAddr("venueAdmin2");
        address newPayout = makeAddr("venuePayout2");

        vm.prank(venueAdmin);
        ticketing.updateVenue(venueId, "Venue2", 999, 5000, newAdmin, newPayout);

        TicketingTypes.Venue memory v = ticketing.getVenue(venueId);
        assertEq(v.admin, newAdmin);
        assertEq(v.payout, newPayout);
        assertEq(v.name, "Venue2");
        assertEq(v.capacity, 999);
        assertEq(v.venueShareBps, 5000);
    }
}
