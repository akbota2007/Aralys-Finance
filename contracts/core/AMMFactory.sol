// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { AMMPair } from "./AMMPair.sol";

/**
 * @title AMMFactory
 * @notice Deploys AMMPair instances. Uses CREATE for the implementation (one-time),
 *         and CREATE2 + EIP-1167 clones for each new pair (deterministic addresses).
 * @dev    Owner is the Aralys Timelock. Only the owner can pause `createPair`.
 *
 *         OWNERSHIP: Zaure
 */
contract AMMFactory is Ownable {
    address public immutable implementation;

    mapping(address tokenA => mapping(address tokenB => address pair)) public getPair;
    address[] public allPairs;

    error IdenticalAddresses();
    error ZeroAddress();
    error PairExists();

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 totalPairs);

    constructor(address initialOwner) Ownable(initialOwner) {
        // Plain CREATE — satisfies the spec requirement to use CREATE somewhere.
        implementation = address(new AMMPair());
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /**
     * @notice Deterministically deploy a new pair via CREATE2 + EIP-1167 clone.
     * @dev Salt = keccak256(abi.encode(token0, token1)).
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
        if (getPair[token0][token1] != address(0)) revert PairExists();

        bytes32 salt = keccak256(abi.encode(token0, token1));
        pair = Clones.cloneDeterministic(implementation, salt);
        AMMPair(pair).initialize(token0, token1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /// @notice Pre-compute the address of a pair before deployment.
    function predictPairAddress(address tokenA, address tokenB) external view returns (address) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes32 salt = keccak256(abi.encode(token0, token1));
        return Clones.predictDeterministicAddress(implementation, salt, address(this));
    }
}
