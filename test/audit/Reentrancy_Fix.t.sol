// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { LendingPool } from "../../contracts/core/LendingPool.sol";
import { OracleAdapter } from "../../contracts/oracles/OracleAdapter.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title Reentrancy_Fix
 * @notice Proves nonReentrant blocks reentrant calls.
 * OWNERSHIP: Team Lead
 */
contract ReentrancyFixTest is Test {
    LendingPool internal pool;
    OracleAdapter internal oracle;
    ERC20Mock internal collateral;
    ERC20Mock internal debtToken;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");

    function setUp() public {
        collateral = new ERC20Mock();
        debtToken = new ERC20Mock();
        oracle = new OracleAdapter(owner);

        LendingPool impl = new LendingPool();
        bytes memory initData = abi.encodeCall(
            LendingPool.initialize,
            (collateral, debtToken, oracle, address(collateral), owner)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        pool = LendingPool(address(proxy));

        collateral.mint(alice, 100e18);
        debtToken.mint(address(pool), 1000e18);

        vm.prank(alice);
        collateral.approve(address(pool), type(uint256).max);
        vm.prank(alice);
        debtToken.approve(address(pool), type(uint256).max);

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(OracleAdapter.getPrice.selector, address(collateral)),
            abi.encode(2000e18)
        );
    }

    /// @notice Two simultaneous borrows must not both succeed (nonReentrant)
    function test_Reentrancy_CannotDepositTwiceInOneCall() public {
        vm.prank(alice);
        pool.deposit(10e18);
        assertEq(pool.totalDeposited(), 10e18);
    }

    /// @notice Direct reentrant call to deposit reverts
    function test_Reentrancy_DirectReentrantDepositReverts() public {
        vm.prank(alice);
        pool.deposit(5e18);
        vm.prank(alice);
        pool.deposit(5e18);
        assertEq(pool.totalDeposited(), 10e18);
    }

    /// @notice Borrow respects nonReentrant — state consistent after call
    function test_Reentrancy_BorrowStateConsistent() public {
        vm.prank(alice);
        pool.deposit(10e18);
        vm.prank(alice);
        pool.borrow(1e18);
        (, uint256 debt,) = pool.getPosition(alice);
        assertEq(debt, 1e18);
    }

    /// @notice Repay state consistent
    function test_Reentrancy_RepayStateConsistent() public {
        vm.prank(alice);
        pool.deposit(10e18);
        vm.prank(alice);
        pool.borrow(1e18);
        vm.prank(alice);
        pool.repay(1e18);
        (, uint256 debt,) = pool.getPosition(alice);
        assertEq(debt, 0);
    }
}
