// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { OracleAdapter } from "../../contracts/oracles/OracleAdapter.sol";
import { AggregatorV3Interface } from "../../contracts/interfaces/AggregatorV3Interface.sol";

contract MockAggregator is AggregatorV3Interface {
    int256 public price;
    uint8 public decimals = 8;
    uint80 public roundId = 1;
    uint256 public updatedAt;

    constructor(int256 _price) {
        price = _price;
        updatedAt = block.timestamp;
    }

    function setPrice(int256 _price) external { price = _price; }
    function setUpdatedAt(uint256 _ts) external { updatedAt = _ts; }
    function description() external pure returns (string memory) { return "Mock"; }
    function version() external pure returns (uint256) { return 1; }
    function getRoundData(uint80) external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, price, 0, updatedAt, roundId);
    }
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, price, 0, updatedAt, roundId);
    }
}

contract OracleAdapterTest is Test {
    OracleAdapter internal oracle;
    MockAggregator internal feed;
    address internal owner = makeAddr("owner");
    address internal asset = makeAddr("asset");

    function setUp() public {
        oracle = new OracleAdapter(owner);
        feed = new MockAggregator(2000e8); // $2000 with 8 decimals
        vm.prank(owner);
        oracle.setFeed(asset, address(feed));
    }

    function test_GetPrice_ReturnsCorrectPrice() public view {
        uint256 price = oracle.getPrice(asset);
        assertEq(price, 2000e18);
    }

    function test_GetPrice_Reverts_StaleFeed() public {
        vm.warp(10000); feed.setUpdatedAt(1);
        vm.expectRevert();
        oracle.getPrice(asset);
    }

    function test_GetPrice_Reverts_ZeroPrice() public {
        feed.setPrice(0);
        vm.expectRevert();
        oracle.getPrice(asset);
    }

    function test_GetPrice_Reverts_NegativePrice() public {
        feed.setPrice(-1);
        vm.expectRevert();
        oracle.getPrice(asset);
    }

    function test_GetPrice_Reverts_FeedNotSet() public {
        vm.expectRevert();
        oracle.getPrice(makeAddr("unknown"));
    }

    function test_SetFeed_OnlyFeedManager() public {
        vm.prank(makeAddr("attacker"));
        vm.expectRevert();
        oracle.setFeed(asset, address(feed));
    }

    function test_SetFeed_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit OracleAdapter.FeedSet(asset, address(feed));
        vm.prank(owner);
        oracle.setFeed(asset, address(feed));
    }
}

