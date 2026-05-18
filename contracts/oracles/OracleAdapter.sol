// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { AggregatorV3Interface } from "../interfaces/AggregatorV3Interface.sol";
<<<<<<< HEAD:contracts/oracles/OracleAdapter.sol
=======

>>>>>>> 59d5972 (test(vault): add YieldVaultV2 upgrade tests, fix V2 constructor):aralys-finance/contracts/oracles/OracleAdapter.sol

/**
 * @title OracleAdapter
 * @notice Wraps Chainlink AggregatorV3 with staleness, zero, and round-completion checks.
 *         Acts as the only oracle interface for the protocol so we can swap implementations
 *         (e.g. mock in tests, multi-oracle in v2) without touching consumers.
 *
 *         OWNERSHIP: Ayauzhan
 */
contract OracleAdapter is AccessControl {
    bytes32 public constant FEED_MANAGER_ROLE = keccak256("FEED_MANAGER_ROLE");

    /// @notice Maximum age of a Chainlink answer before we consider it stale (seconds).
    uint256 public constant STALENESS_THRESHOLD = 3600;

    mapping(address asset => AggregatorV3Interface feed) public feeds;

    // --- errors ---
    error StalePrice(uint256 updatedAt, uint256 nowTs);
    error InvalidPrice(int256 answer);
    error IncompleteRound(uint80 roundId, uint80 answeredInRound);
    error FeedNotSet(address asset);

    // --- events ---
    event FeedSet(address indexed asset, address indexed feed);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FEED_MANAGER_ROLE, admin);
    }

    function setFeed(address asset, address feed) external onlyRole(FEED_MANAGER_ROLE) {
        feeds[asset] = AggregatorV3Interface(feed);
        emit FeedSet(asset, feed);
    }

    /**
     * @notice Returns latest price for `asset`, scaled to 1e18.
     * @dev Reverts on stale, zero, negative, or incomplete-round answers.
     */
    function getPrice(address asset) external view returns (uint256 price1e18) {
        AggregatorV3Interface feed = feeds[asset];
        if (address(feed) == address(0)) revert FeedNotSet(asset);

        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();

        if (answer <= 0) revert InvalidPrice(answer);
        if (answeredInRound < roundId) revert IncompleteRound(roundId, answeredInRound);
        if (block.timestamp - updatedAt > STALENESS_THRESHOLD) {
            revert StalePrice(updatedAt, block.timestamp);
        }

        // Chainlink price is at `feed.decimals()`. Normalize to 1e18.
        uint8 decimals = feed.decimals();
        if (decimals < 18) {
            price1e18 = uint256(answer) * (10 ** (18 - decimals));
        } else if (decimals > 18) {
            price1e18 = uint256(answer) / (10 ** (decimals - 18));
        } else {
            price1e18 = uint256(answer);
        }
    }
}
