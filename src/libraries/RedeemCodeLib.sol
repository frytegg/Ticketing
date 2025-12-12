// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library RedeemCodeLib {
    /// @notice Hash a redeem code string. Only store/compare hashes on-chain.
    /// @dev Users submit the raw code; contract hashes it and checks existence.
    function hashCode(string memory code) internal pure returns (bytes32) {
        return keccak256(bytes(code));
    }
}
