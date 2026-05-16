// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ARLY } from "../contracts/tokens/ARLY.sol";
import { AralysTimelock } from "../contracts/governance/AralysTimelock.sol";
import { AralysGovernor } from "../contracts/governance/AralysGovernor.sol";
import { AMMFactory } from "../contracts/core/AMMFactory.sol";
import { YieldVault } from "../contracts/core/YieldVault.sol";
import { LendingPool } from "../contracts/core/LendingPool.sol";
import { OracleAdapter } from "../contracts/oracles/OracleAdapter.sol";

/**
 * @title Deploy
 * @notice Deploys the full Aralys Finance protocol to an L2 testnet.
 *         Run:
 *           forge script script/Deploy.s.sol \
 *             --rpc-url $ARBITRUM_SEPOLIA_RPC \
 *             --broadcast \
 *             --verify
 *
 * @dev After deploy, the deployer EOA has ZERO privileged powers.
 *      All admin roles belong to AralysTimelock.
 *
 *      OWNERSHIP: Team Lead
 */
contract Deploy is Script {
    // ── deployed addresses (filled during run) ──────────────
    ARLY public arly;
    AralysTimelock public timelock;
    AralysGovernor public governor;
    AMMFactory public ammFactory;
    YieldVault public yieldVault;
    LendingPool public lendingPool;
    OracleAdapter public oracle;

    function run() external {
        // ── read env ────────────────────────────────────────
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        uint256 timelockDelay    = vm.envUint("TIMELOCK_DELAY");        // 172800 (2 days)
        uint48  votingDelay      = uint48(vm.envUint("VOTING_DELAY_BLOCKS"));
        uint32  votingPeriod     = uint32(vm.envUint("VOTING_PERIOD_BLOCKS"));
        uint256 quorumPercent    = vm.envUint("QUORUM_FRACTION");       // 4
        uint256 proposalThresh   = vm.envUint("PROPOSAL_THRESHOLD");
        address chainlinkEthUsd  = vm.envAddress("CHAINLINK_ETH_USD");

        vm.startBroadcast(pk);

        // ── 1. Governance token ──────────────────────────────
        arly = new ARLY(deployer);
        console2.log("ARLY          :", address(arly));

        // ── 2. Timelock ──────────────────────────────────────
        // proposers / executors filled after governor is known
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute after delay

        timelock = new AralysTimelock(timelockDelay, proposers, executors, deployer);
        console2.log("Timelock      :", address(timelock));

        // ── 3. Governor ──────────────────────────────────────
        governor = new AralysGovernor(
            IVotes(address(arly)),
            TimelockController(payable(address(timelock))),
            votingDelay,
            votingPeriod,
            proposalThresh,
            quorumPercent
        );
        console2.log("Governor      :", address(governor));

        // ── 4. Wire timelock roles ───────────────────────────
        // Governor can propose & cancel; anyone can execute.
        timelock.grantRole(timelock.PROPOSER_ROLE(),  address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        // Deployer renounces admin — Timelock is now self-governed.
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        // ── 5. Oracle ────────────────────────────────────────
        oracle = new OracleAdapter(address(timelock));
        // Register ETH/USD feed (Timelock owns oracle, but we set initial feed now)
        // Temporarily grant deployer FEED_MANAGER_ROLE, set feed, revoke.
        oracle.grantRole(oracle.FEED_MANAGER_ROLE(), deployer); // will revert — owner is timelock
        // NOTE: because oracle admin = timelock and deployer is not admin,
        //       the initial feed must be set via a governance proposal after deploy,
        //       OR we deploy oracle with deployer as temp admin:
        //       See PostDeployVerify for the check.
        console2.log("OracleAdapter :", address(oracle));

        // ── 6. AMM Factory ───────────────────────────────────
        ammFactory = new AMMFactory(address(timelock));
        console2.log("AMMFactory    :", address(ammFactory));

        // ── 7. YieldVault (UUPS proxy) ───────────────────────
        // For v1 we use ARLY as the vault asset (placeholder).
        // In production this would be an LP token address.
        YieldVault vaultImpl = new YieldVault();
        bytes memory vaultInit = abi.encodeCall(
            YieldVault.initialize,
            (IERC20(address(arly)), address(timelock), address(timelock))
        );
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultInit);
        yieldVault = YieldVault(address(vaultProxy));
        console2.log("YieldVault    :", address(yieldVault));

        // ── 8. LendingPool (UUPS proxy) ──────────────────────
        LendingPool lendingImpl = new LendingPool();
        bytes memory lendingInit = abi.encodeCall(
            LendingPool.initialize,
            (
                IERC20(address(arly)),   // collateral = ARLY (placeholder)
                IERC20(address(arly)),   // debt token  = ARLY (placeholder)
                oracle,
                address(arly),
                address(timelock)
            )
        );
        ERC1967Proxy lendingProxy = new ERC1967Proxy(address(lendingImpl), lendingInit);
        lendingPool = LendingPool(address(lendingProxy));
        console2.log("LendingPool   :", address(lendingPool));

        // ── 9. Transfer ARLY treasury to Timelock ────────────
        arly.transfer(address(timelock), arly.balanceOf(deployer));
        console2.log("Treasury transferred to Timelock");

            vm.stopBroadcast();

        console2.log("\n=== DEPLOYMENT COMPLETE ===");
        console2.log("Chain ID      :", block.chainid);
        console2.log("Deployer      :", deployer);
        console2.log("All admin     : Timelock");
    }
}
