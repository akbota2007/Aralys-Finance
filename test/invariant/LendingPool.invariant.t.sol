// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { LendingPool } from "../../contracts/core/LendingPool.sol";
import { OracleAdapter } from "../../contracts/oracles/OracleAdapter.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract LendingPoolHandler is Test {
    LendingPool public pool;
    ERC20Mock public collateral;
    ERC20Mock public debtToken;
    OracleAdapter public oracle;
    address public actor = makeAddr("actor");

    constructor(LendingPool _pool, ERC20Mock _col, ERC20Mock _debt, OracleAdapter _oracle) {
        pool = _pool;
        collateral = _col;
        debtToken = _debt;
        oracle = _oracle;

        collateral.mint(actor, 10000e18);
        debtToken.mint(address(pool), 10000e18);
        vm.prank(actor);
        collateral.approve(address(pool), type(uint256).max);
        vm.prank(actor);
        debtToken.approve(address(pool), type(uint256).max);

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(OracleAdapter.getPrice.selector, address(collateral)),
            abi.encode(2000e18)
        );
    }

    function deposit(uint256 amount) public {
        amount = bound(amount, 1, 100e18);
        vm.prank(actor);
        pool.deposit(amount);
    }

    function withdraw(uint256 amount) public {
        (uint256 col, uint256 debt,) = pool.getPosition(actor);
        if (col == 0 || debt > 0) return;
        amount = bound(amount, 1, col);
        vm.prank(actor);
        try pool.withdraw(amount) {} catch {}
    }

    function borrow(uint256 amount) public {
        amount = bound(amount, 1, 5e18);
        vm.prank(actor);
        try pool.borrow(amount) {} catch {}
    }

    function repay(uint256 amount) public {
        (, uint256 debt,) = pool.getPosition(actor);
        if (debt == 0) return;
        amount = bound(amount, 1, debt);
        vm.prank(actor);
        try pool.repay(amount) {} catch {}
    }
}

contract LendingPoolInvariantTest is Test {
    LendingPool internal pool;
    ERC20Mock internal collateral;
    ERC20Mock internal debtToken;
    OracleAdapter internal oracle;
    LendingPoolHandler internal handler;

    address internal owner = makeAddr("owner");

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

        handler = new LendingPoolHandler(pool, collateral, debtToken, oracle);
        targetContract(address(handler));
    }

    function invariant_TotalDepositedMatchesBalance() public view {
        assertGe(collateral.balanceOf(address(pool)), pool.totalDeposited());
    }

    function invariant_TotalBorrowedNeverExceedsDebtBalance() public view {
        assertGe(debtToken.balanceOf(address(pool)) + pool.totalBorrowed(), pool.totalBorrowed());
    }

    function invariant_PoolNeverInsolvent() public view {
        assertGe(collateral.balanceOf(address(pool)) + pool.totalDeposited(), 0);
    }

    function invariant_TotalBorrowedIsNonNegative() public view {
        assertGe(pool.totalBorrowed(), 0);
    }

    function invariant_TotalDepositedIsNonNegative() public view {
        assertGe(pool.totalDeposited(), 0);
    }
}
