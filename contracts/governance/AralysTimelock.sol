// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title AralysTimelock
 * @notice 2-day timelock controlling all upgradeable contracts and treasury.
 * @dev Roles:
 *        PROPOSER_ROLE  -> Governor (set in deploy script)
 *        EXECUTOR_ROLE  -> address(0) (anyone can execute after delay)
 *        CANCELLER_ROLE -> deployer multisig until renounced post-deploy
 *        DEFAULT_ADMIN_ROLE -> renounced post-deploy
 *
 *      OWNERSHIP: Team Lead
 */
contract AralysTimelock is TimelockController {
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        TimelockController(minDelay, proposers, executors, admin)
    {}
}
