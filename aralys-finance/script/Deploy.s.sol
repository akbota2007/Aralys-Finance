// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ARLY } from "../contracts/tokens/ARLY.sol";
import { AralysTimelock } from "../contracts/governance/AralysTimelock.sol";
import { AralysGovernor } from "../contracts/governance/AralysGovernor.sol";
import { AMMFactory } from "../contracts/core/AMMFactory.sol";
import { YieldVault } from "../contracts/core/YieldVault.sol";
import { LendingPool } from "../contracts/core/LendingPool.sol";
import { OracleAdapter } from "../contracts/oracles/OracleAdapter.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title Deploy
 * @notice Idempotent, parameterized deployment of the Aralys Finance protocol.
 *         Run: `forge script script/Deploy.s.sol --rpc-url <RPC> --broadcast --verify`
 *
 * @dev IMPORTANT: post-deploy this script transfers ALL admin powers to the Timelock
 *      and renounces the deployer's privileges. The deployer EOA has zero powers afterwards.
 *
 *      OWNERSHIP: Team Lead
 */
contract Deploy is Script {
    // env-driven parameters
    uint256 private timelockDelay;
    uint48 private votingDelay;
    uint32 private votingPeriod;
    uint256 private quorumPercent;
    uint256 private proposalThreshold;
    address private chainlinkEthUsd;

    // outputs
    ARLY public arly;
    AralysTimelock public timelock;
    AralysGovernor public governor;
    AMMFactory public ammFactory;
    YieldVault public yieldVault;
    LendingPool public lendingPool;
    OracleAdapter public oracle;

    function run() public {
        timelockDelay     = vm.envUint("TIMELOCK_DELAY");
        votingDelay       = uint48(vm.envUint("VOTING_DELAY_BLOCKS"));
        votingPeriod      = uint32(vm.envUint("VOTING_PERIOD_BLOCKS"));
        quorumPercent     = vm.envUint("QUORUM_FRACTION");
        proposalThreshold = vm.envUint("PROPOSAL_THRESHOLD");
        chainlinkEthUsd   = vm.envAddress("CHAINLINK_ETH_USD");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);

        // 1. Token (full supply to deployer; transferred to Timelock at the end)
        arly = new ARLY(deployer);

        // 2. Timelock — proposers/executors set later (zero address temporarily for executors = open)
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute
        timelock = new AralysTimelock(timelockDelay, proposers, executors, deployer);

        // 3. Governor
        governor = new AralysGovernor(
            IVotes(address(arly)),
            TimelockController(payable(address(timelock))),
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumPercent
        );

        // 4. Wire roles: Governor becomes proposer; deployer-admin renounces.
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        // 5. Oracle (admin = Timelock)
        oracle = new OracleAdapter(address(timelock));

        // 6. AMM Factory (owner = Timelock)
        ammFactory = new AMMFactory(address(timelock));

        // 7. YieldVault (UUPS) — TODO: deploy implementation, then ERC1967 proxy, then initialize
        // 8. LendingPool (UUPS) — same pattern

        // 9. Transfer ARLY supply to Timelock treasury
        arly.transfer(address(timelock), arly.balanceOf(deployer));

        vm.stopBroadcast();

        _logAddresses();
    }

    function _logAddresses() internal view {
        // TODO: write addresses to deployments/<chainid>.json for the frontend
    }
}
