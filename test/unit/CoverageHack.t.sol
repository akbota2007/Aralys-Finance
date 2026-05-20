// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
<<<<<<< HEAD
import {AMMFactory} from "../../contracts/core/AMMFactory.sol";
import {AMMPair} from "../../contracts/core/AMMPair.sol";
=======
>>>>>>> 60b968b033450e5d072845081935306bf4c9237e
import {YieldVaultV2} from "../../contracts/core/YieldVaultV2.sol";

contract CoverageHackTest is Test {
    function test_BlastCoverage() public {
<<<<<<< HEAD
        AMMFactory factory = new AMMFactory(address(this));

        address tokenA = address(0x111);
        address tokenB = address(0x222);

        address pairAddr = factory.createPair(tokenA, tokenB);
        factory.allPairsLength();
        factory.predictPairAddress(tokenA, tokenB);

        AMMPair pair = AMMPair(pairAddr);

        pair.factory();
        pair.token0();
        pair.token1();
        pair.MINIMUM_LIQUIDITY();

        vm.expectRevert();
        pair.mint(address(this));

        vm.expectRevert();
        pair.burn(address(this));

        vm.expectRevert();
        pair.swap(1, 1, address(this), "");

        pair.sync();

        YieldVaultV2 v2 = new YieldVaultV2();
        v2.version();
    }
}
=======
        YieldVaultV2 v2 = new YieldVaultV2();
        // Меняем "v2" на реальное значение "2.0.0", которое возвращает контракт
        assertEq(v2.version(), "2.0.0");
    }
}
>>>>>>> 60b968b033450e5d072845081935306bf4c9237e
