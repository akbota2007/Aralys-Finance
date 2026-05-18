// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Fork tests
 * @notice Tests against real Arbitrum Sepolia contracts.
 * @dev Run with: forge test --match-path test/fork/Fork.t.sol --fork-url $ARBITRUM_SEPOLIA_RPC
 *      OWNERSHIP: Team Lead
 */
contract ForkTest is Test {
    // Arbitrum Sepolia USDC
    address constant USDC = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    // Arbitrum Sepolia ETH/USD Chainlink feed
    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;

    function setUp() public {
        // Fork Arbitrum Sepolia — requires ARBITRUM_SEPOLIA_RPC env var
        string memory rpc = vm.envOr("ARBITRUM_SEPOLIA_RPC", string("https://sepolia-rollup.arbitrum.io/rpc"));
        vm.createSelectFork(rpc);
    }

    function testFork_USDC_Exists() public view {
        uint256 supply = IERC20(USDC).totalSupply();
        assertGt(supply, 0, "USDC should have supply on Arb Sepolia");
    }

    function testFork_ChainlinkFeed_ReturnsPrice() public view {
        (bool success, bytes memory data) = ETH_USD_FEED.staticcall(
            abi.encodeWithSignature("latestRoundData()")
        );
        assertTrue(success, "Chainlink call should succeed");
        (,int256 answer,,,) = abi.decode(data, (uint80, int256, uint256, uint256, uint80));
        assertGt(answer, 0, "ETH price should be positive");
    }

    function testFork_USDC_Decimals() public view {
        (bool success, bytes memory data) = USDC.staticcall(
            abi.encodeWithSignature("decimals()")
        );
        assertTrue(success);
        uint8 decimals = abi.decode(data, (uint8));
        assertEq(decimals, 6, "USDC has 6 decimals");
    }
}
