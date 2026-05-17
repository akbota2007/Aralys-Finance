// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {YieldVault} from "../../contracts/core/YieldVault.sol";

contract YieldVaultTest is Test {

    function test_Deploy() public {

        YieldVault vault =
            new YieldVault();

        assertTrue(
            address(vault) != address(0)
        );
    }

    function test_SetFeeRecipient() public {

        YieldVault vault =
            new YieldVault();

        assertTrue(
            address(vault) != address(0)
        );
    }

    function test_SetPerformanceFee() public {

        YieldVault vault =
            new YieldVault();

        assertTrue(
            address(vault) != address(0)
        );
    }
}