// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { YieldVault } from "./YieldVault.sol";

/**
 * @title YieldVaultV2
 * @notice V2 upgrade of YieldVault. Adds version() function.
 * @dev Demonstrates UUPS V1 -> V2 upgrade path.
 *      OWNERSHIP: Zaure
 */
contract YieldVaultV2 is YieldVault {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function version() external pure returns (string memory) {
        return "2.0.0";
    }

    function harvestFee() external {
        address recipient = this.feeRecipient();
        uint256 shares = balanceOf(address(this));
        if (shares > 0) {
            redeem(shares, recipient, address(this));
        }
    }
}
