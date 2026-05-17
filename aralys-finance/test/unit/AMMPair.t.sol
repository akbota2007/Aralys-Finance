// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {AMMPair} from "../../contracts/core/AMMPair.sol";

contract AMMPairTest is Test {

    AMMPair pair;

    address token0 = address(0x1);
    address token1 = address(0x2);

    function setUp() public {
        pair = new AMMPair();
    }

    function test_Initialize() public {
        pair.initialize(
            token0,
            token1
        );

        assertEq(
            pair.token0(),
            token0
        );

        assertEq(
            pair.token1(),
            token1
        );
    }

    function test_RevertIfZeroAddress() public {
        vm.expectRevert();

        pair.initialize(
            address(0),
            token1
        );
    }

    function test_RevertIfInitializedTwice() public {

        pair.initialize(
            token0,
            token1
        );

        vm.expectRevert();

        pair.initialize(
            token0,
            token1
        );
    }
}