// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { YieldVault } from "../../contracts/core/YieldVault.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title AccessControl_Fix
 * @notice Proves that initialize() on implementation is disabled (_disableInitializers).
 * @dev    Case study S-02 from audit.md
 *         OWNERSHIP: Team Lead
 */
contract AccessControlFixTest is Test {
    YieldVault internal implementation;
    YieldVault internal vault;
    ERC20Mock internal asset;

    address internal owner = makeAddr("owner");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        asset = new ERC20Mock();

        // Deploy implementation
        implementation = new YieldVault();

        // Deploy proxy + initialize properly
        bytes memory initData = abi.encodeCall(
            YieldVault.initialize,
            (asset, owner, owner)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        vault = YieldVault(address(proxy));
    }

    /// @notice Attacker cannot call initialize() on implementation directly
    function test_AccessControl_ImplementationInitializeBlocked() public {
        vm.prank(attacker);
        vm.expectRevert();
        implementation.initialize(asset, attacker, attacker);
    }

    /// @notice Attacker cannot call initialize() on proxy (already initialized)
    function test_AccessControl_ProxyInitializeBlocked() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.initialize(asset, attacker, attacker);
    }

    /// @notice Only owner (Timelock) can upgrade
    function test_AccessControl_OnlyOwnerCanUpgrade() public {
        YieldVault newImpl = new YieldVault();
        vm.prank(attacker);
        vm.expectRevert();
        vault.upgradeToAndCall(address(newImpl), "");
    }

    /// @notice Owner can upgrade successfully
    function test_AccessControl_OwnerCanUpgrade() public {
        YieldVault newImpl = new YieldVault();
        vm.prank(owner);
        vault.upgradeToAndCall(address(newImpl), "");
    }
}
