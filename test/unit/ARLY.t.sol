// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { ARLY } from "../../contracts/tokens/ARLY.sol";

/**
 * @notice Unit tests for ARLY governance token.
 * @dev    OWNERSHIP: Ayauzhan
 */
contract ARLYTest is Test {
    ARLY internal arly;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        arly = new ARLY(alice);
    }

    function test_InitialSupplyMintedToHolder() public view {
        assertEq(arly.balanceOf(alice), arly.INITIAL_SUPPLY());
        assertEq(arly.totalSupply(), 1_000_000e18);
    }

    function test_NameSymbolDecimals() public view {
        assertEq(arly.name(), "Aralys");
        assertEq(arly.symbol(), "ARLY");
        assertEq(arly.decimals(), 18);
    }

    function test_DelegateActivatesVotingPower() public {
        // Self-delegation required for ERC20Votes to count balance as voting power.
        vm.prank(alice);
        arly.delegate(alice);

        // Move forward one block so the checkpoint is queryable.
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        assertEq(arly.getVotes(alice), arly.balanceOf(alice));
    }

    function test_TransferMovesVotingPowerWhenBothDelegate() public {
        vm.prank(alice);
        arly.delegate(alice);
        vm.prank(bob);
        arly.delegate(bob);

        vm.prank(alice);
        arly.transfer(bob, 100e18);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        assertEq(arly.getVotes(alice), arly.INITIAL_SUPPLY() - 100e18);
        assertEq(arly.getVotes(bob), 100e18);
    }

    function test_PermitAllowsGaslessApproval() public {
        uint256 alicePk = 0xA11CE;
        address aliceAddr = vm.addr(alicePk);

        // re-deploy with this PK as initial holder so we have a known signer
        ARLY token = new ARLY(aliceAddr);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        aliceAddr,
                        bob,
                        500e18,
                        token.nonces(aliceAddr),
                        deadline
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);

        token.permit(aliceAddr, bob, 500e18, deadline, v, r, s);
        assertEq(token.allowance(aliceAddr, bob), 500e18);
    }
}
