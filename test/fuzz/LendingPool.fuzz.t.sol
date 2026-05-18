// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { LendingPool } from "../../contracts/core/LendingPool.sol";
import { OracleAdapter } from "../../contracts/oracles/OracleAdapter.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract LendingPoolFuzzTest is Test {
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

        collateral.mint(alice, type(uint128).max);
        debtToken.mint(address(pool), type(uint128).max);

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

    function testFuzz_Deposit_UpdatesBalance(uint128 amount) public {
        vm.assume(amount > 0 && amount <= 1000e18);
        vm.prank(alice);
        pool.deposit(amount);
        (uint256 col,,) = pool.getPosition(alice);
        assertEq(col, amount);
    }

    function testFuzz_Deposit_TotalDepositedIncreases(uint128 amount) public {
        vm.assume(amount > 0 && amount <= 1000e18);
        vm.prank(alice);
        pool.deposit(amount);
        assertEq(pool.totalDeposited(), amount);
    }

    function testFuzz_Withdraw_CannotExceedDeposit(uint128 deposit, uint128 withdraw) public {
        vm.assume(deposit > 0 && deposit <= 1000e18);
        vm.assume(withdraw > deposit);
        vm.prank(alice);
        pool.deposit(deposit);
        vm.prank(alice);
        vm.expectRevert();
        pool.withdraw(withdraw);
    }

    function testFuzz_Borrow_ZeroReverts(uint128 amount) public {
        vm.assume(amount == 0);
        vm.prank(alice);
        vm.expectRevert();
        pool.borrow(amount);
    }

    function testFuzz_Repay_NeverExceedsDebt(uint128 amount) public {
        vm.assume(amount > 0 && amount <= 10e18);
        vm.prank(alice);
        pool.deposit(100e18);
        vm.prank(alice);
        pool.borrow(amount);
        vm.prank(alice);
        pool.repay(uint256(amount) * 2);
        (, uint256 debt,) = pool.getPosition(alice);
        assertEq(debt, 0);
    }

    function testFuzz_HealthFactor_MaxWhenNoDebt(address user) public view {
        vm.assume(user != address(0));
        assertEq(pool.healthFactor(user), type(uint256).max);
    }
}



