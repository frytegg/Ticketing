// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TicketingErrors} from "../core/Errors.sol";

library PricingLib {
    /// @notice Enforce anti-scalping: asked price must be <= cap (typically lastPaidPriceWei).
    function enforcePriceCap(uint256 capWei, uint256 askedWei) internal pure {
        if (askedWei > capWei) revert TicketingErrors.PriceAboveCap(capWei, askedWei);
    }

    /// @notice Enforce exact payment (simple marketplace flow).
    function enforceExactPayment(uint256 expectedWei, uint256 actualWei) internal pure {
        if (expectedWei != actualWei) revert TicketingErrors.InvalidPayment(expectedWei, actualWei);
    }
}
