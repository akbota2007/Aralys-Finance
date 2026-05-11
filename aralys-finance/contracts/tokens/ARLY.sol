// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title ARLY — Aralys Finance governance token
 * @notice Fixed-supply ERC-20 with on-chain voting (ERC20Votes) and gasless approvals (ERC20Permit).
 * @dev Total supply minted to deployer at construction. No mint/burn after deploy.
 *      Owner: Aralys Timelock will receive the entire supply post-deploy via one-time `transfer`
 *      from deployer (deploy script does this automatically).
 *
 *      OWNERSHIP: Ayauzhan
 */
contract ARLY is ERC20, ERC20Permit, ERC20Votes {
    /// @dev 1,000,000 ARLY total supply, 18 decimals.
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;

    constructor(address initialHolder) ERC20("Aralys", "ARLY") ERC20Permit("Aralys") {
        _mint(initialHolder, INITIAL_SUPPLY);
    }

    // --- OZ v5 hooks (ERC20Votes + Nonces multiple-inheritance plumbing) ---

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }
}
