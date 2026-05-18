// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { AralysGovernor } from "../../contracts/governance/AralysGovernor.sol";
import { AralysTimelock } from "../../contracts/governance/AralysTimelock.sol";
import { ARLY } from "../../contracts/tokens/ARLY.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";

contract AralysGovernorTest is Test {
    AralysGovernor internal governor;
    AralysTimelock internal timelock;
    ARLY internal arly;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint48  constant VOTING_DELAY  = 1;
    uint32  constant VOTING_PERIOD = 50;
    uint256 constant QUORUM        = 4;
    uint256 constant THRESHOLD     = 1000e18;
    uint256 constant DELAY         = 2 days;

    function setUp() public {
        arly = new ARLY(alice);

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new AralysTimelock(DELAY, proposers, executors, alice);

        governor = new AralysGovernor(
            arly, TimelockController(payable(address(timelock))),
            VOTING_DELAY, VOTING_PERIOD, THRESHOLD, QUORUM
        );

        vm.startPrank(alice);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), alice);
        arly.delegate(alice);
        vm.stopPrank();

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
    }

    function test_GovernorName() public view {
        assertEq(governor.name(), "AralysGovernor");
    }

    function test_VotingDelay() public view {
        assertEq(governor.votingDelay(), VOTING_DELAY);
    }

    function test_VotingPeriod() public view {
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
    }

    function test_ProposalThreshold() public view {
        assertEq(governor.proposalThreshold(), THRESHOLD);
    }

    function test_Propose_Succeeds() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _dummyProposal();
        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test proposal");
        assertGt(proposalId, 0);
    }

    function test_Propose_Reverts_BelowThreshold() public {
        vm.prank(bob); // bob has no tokens
        vm.expectRevert();
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _dummyProposal();
        governor.propose(targets, values, calldatas, "fail");
    }

    function test_FullLifecycle_ProposeVoteQueueExecute() public {
        // 1. Propose
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _dummyProposal();
        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "E2E test");

        // 2. Wait voting delay
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // 3. Vote
        vm.prank(alice);
        governor.castVote(proposalId, 1); // 1 = For

        // 4. Wait voting period
        vm.roll(block.number + VOTING_PERIOD + 1);
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // 5. Queue
        governor.queue(targets, values, calldatas, keccak256(bytes("E2E test")));
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // 6. Wait timelock delay
        vm.warp(block.timestamp + DELAY + 1);

        // 7. Execute
        governor.execute(targets, values, calldatas, keccak256(bytes("E2E test")));
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    }

    function test_CastVote_Reverts_BeforeVotingDelay() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _dummyProposal();
        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "too early");
        vm.prank(alice);
        vm.expectRevert();
        governor.castVote(proposalId, 1);
    }

    function _dummyProposal() internal view returns (
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) {
        targets = new address[](1);
        targets[0] = address(timelock);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        calldatas[0] = "";
    }
}
