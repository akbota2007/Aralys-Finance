// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { YieldVault } from "../../contracts/core/YieldVault.sol";
import { YieldVaultV2 } from "../../contracts/core/YieldVaultV2.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract YieldVaultV2Test is Test {
    YieldVault internal vault;
    ERC20Mock internal asset;
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");

    function setUp() public {
        asset = new ERC20Mock();
        YieldVault impl = new YieldVault();
        bytes memory initData = abi.encodeCall(YieldVault.initialize, (asset, owner, owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        vault = YieldVault(address(proxy));
    }

    function test_V2_Upgrade_Succeeds() public {
        YieldVaultV2 implV2 = new YieldVaultV2();
        vm.prank(owner);
        vault.upgradeToAndCall(address(implV2), "");
        assertEq(YieldVaultV2(address(vault)).version(), "2.0.0");
    }

    function test_V2_Version_Is_2() public {
        YieldVaultV2 implV2 = new YieldVaultV2();
        vm.prank(owner);
        vault.upgradeToAndCall(address(implV2), "");
        string memory v = YieldVaultV2(address(vault)).version();
        assertEq(v, "2.0.0");
    }

    function test_V2_OnlyOwner_Can_Upgrade() public {
        YieldVaultV2 implV2 = new YieldVaultV2();
        vm.prank(alice);
        vm.expectRevert();
        vault.upgradeToAndCall(address(implV2), "");
    }

    function test_V1_ImplementationDisabled() public {
        YieldVault impl = new YieldVault();
        vm.expectRevert();
        impl.initialize(asset, alice, alice);
    }

    function test_V2_Owner_Preserved_After_Upgrade() public {
        YieldVaultV2 implV2 = new YieldVaultV2();
        vm.prank(owner);
        vault.upgradeToAndCall(address(implV2), "");
        assertEq(vault.owner(), owner);
    }
}
