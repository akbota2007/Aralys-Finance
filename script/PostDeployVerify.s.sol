// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { AralysTimelock } from "../contracts/governance/AralysTimelock.sol";
import { AralysGovernor } from "../contracts/governance/AralysGovernor.sol";

/**
 * @title PostDeployVerify
 * @notice Reads deployment addresses and asserts:
 *           - Timelock delay = configured value
 *           - Deployer no longer has DEFAULT_ADMIN_ROLE
 *           - Governor parameters match spec
 *           - All UUPS-upgradeable contracts have Timelock as owner
 *
 *         Output of this script must be committed to docs/post-deploy-verification.txt
 *
 *         OWNERSHIP: Team Lead
 */
contract PostDeployVerify is Script {
    function run() external view {
        address timelockAddr = vm.envAddress("TIMELOCK_ADDRESS");
        address governorAddr = vm.envAddress("GOVERNOR_ADDRESS");
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));

        AralysTimelock t = AralysTimelock(payable(timelockAddr));
        AralysGovernor g = AralysGovernor(payable(governorAddr));

        // 1. Delay
        uint256 expectedDelay = vm.envUint("TIMELOCK_DELAY");
        require(t.getMinDelay() == expectedDelay, "TL delay mismatch");
        console2.log("OK: timelock delay", t.getMinDelay());

        // 2. Deployer renounced
        require(!t.hasRole(t.DEFAULT_ADMIN_ROLE(), deployer), "deployer still admin!");
        console2.log("OK: deployer not admin");

        // 3. Governor parameters
        require(g.votingDelay() == vm.envUint("VOTING_DELAY_BLOCKS"), "voting delay wrong");
        require(g.votingPeriod() == vm.envUint("VOTING_PERIOD_BLOCKS"), "voting period wrong");
        require(g.proposalThreshold() == vm.envUint("PROPOSAL_THRESHOLD"), "threshold wrong");
        console2.log("OK: governor parameters match spec");

        // TODO: 4. UUPS owners check (read each proxy's owner() and assert == timelock)
    }
}
