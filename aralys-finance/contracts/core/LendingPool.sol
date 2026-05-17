// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import { PausableUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OracleAdapter } from "../oracles/OracleAdapter.sol";

/**
 * @title LendingPool
 * @notice Single-asset collateralized lending. Users deposit LP shares, borrow stablecoin.
 *         Health factor < 1e18 → liquidatable. 5% liquidation bonus.
 * @dev    UUPS upgradeable. Owner = Aralys Timelock.
 *
 *         OWNERSHIP: Team Lead
 *
 *         PARAMETERS (governable):
 *           LTV          = 75 %  (max borrow = collateral * price * 0.75)
 *           liquidation  = 80 %  (HF computed against this; gap = safety buffer)
 *           liqBonus     = 5 %   (liquidator profit)
 *           interestRate = linear, configurable
 *
 *         INVARIANTS:
 *           1. sum(userDebt) ≤ totalBorrowed
 *           2. for every user: HF >= 1 OR position is liquidatable
 *           3. totalBorrowed ≤ totalDeposited (no over-lending)
 */
contract LendingPool is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardTransient,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    IERC20 public collateralToken;
    IERC20 public debtToken;
    OracleAdapter public oracle;

    uint256 public constant LTV_BPS = 7500;            // 75 %
    uint256 public constant LIQ_THRESHOLD_BPS = 8000;  // 80 %
    uint256 public constant LIQ_BONUS_BPS = 500;       // 5 %
    uint256 public constant BPS = 10_000;
    uint256 public constant WAD = 1e18;

    struct Position {
        uint256 collateral; // amount of LP shares deposited
        uint256 debt;       // amount of debtToken borrowed
        uint256 lastAccrued;
    }

    mapping(address user => Position) public positions;

    uint256 public totalDeposited;
    uint256 public totalBorrowed;
    uint256 public interestRatePerSecond; // 1e18 scale, set by governance

    error InsufficientCollateral();
    error Unhealthy();
    error Healthy(); // for liquidate
    error ZeroAmount();

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed user, uint256 seized, uint256 repaid);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 collateralToken_,
        IERC20 debtToken_,
        OracleAdapter oracle_,
        address owner_
    ) external initializer {
        __Ownable_init(owner_);
        __Pausable_init();

        collateralToken = collateralToken_;
        debtToken = debtToken_;
        oracle = oracle_;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setInterestRate(uint256 ratePerSecond) external onlyOwner {
        interestRatePerSecond = ratePerSecond;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function deposit(uint256 amount)
        external
        nonReentrant
        whenNotPaused
    {
        // CHECKS
        if (amount == 0) revert ZeroAmount();

        Position storage position =
            positions[msg.sender];

        // EFFECTS
        position.collateral += amount;
        totalDeposited += amount;

        // INTERACTIONS
        collateralToken.safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        emit Deposit(
            msg.sender,
            amount
        );
    }

    function healthFactor(address user)
        public
        view
        returns (uint256)
    {
        Position memory position =
            positions[user];

        if (position.debt == 0) {
            return type(uint256).max;
        }

        uint256 price =
            oracle.getPrice(
                address(
                    collateralToken
                )
            );

        uint256 collateralValue =
            (
                position.collateral *
                price *
                LIQ_THRESHOLD_BPS
            ) / BPS;

        return
            (
                collateralValue *
                WAD
            ) / position.debt;
    }

    function withdraw(uint256 amount)
        external
        nonReentrant
        whenNotPaused
    {
        if (amount == 0) revert ZeroAmount();

        Position storage position =
            positions[msg.sender];

        if (position.collateral < amount) {
            revert InsufficientCollateral();
        }

        // EFFECTS
        position.collateral -= amount;
        totalDeposited -= amount;

        // HEALTH CHECK
        if (
            healthFactor(msg.sender)
                < WAD
        ) {
            revert Unhealthy();
        }

        // INTERACTIONS
        collateralToken.safeTransfer(
            msg.sender,
            amount
        );

        emit Withdraw(
            msg.sender,
            amount
        );
    }

    function borrow(uint256 amount)
        external
        nonReentrant
        whenNotPaused
    {
        if (amount == 0) revert ZeroAmount();

        Position storage position =
            positions[msg.sender];

        // EFFECTS
        position.debt += amount;
        totalBorrowed += amount;

        // HEALTH CHECK
        if (
            healthFactor(msg.sender)
                < WAD
        ) {
            revert Unhealthy();
        }

        // INTERACTIONS
        debtToken.safeTransfer(
            msg.sender,
            amount
        );

        emit Borrow(
            msg.sender,
            amount
        );
    }
    // -- core actions --
    // TODO Team Lead:
    //   [ ] deposit(amount)   — pull collateralToken with SafeERC20, update Position, emit
    //   [ ] withdraw(amount)  — check HF stays ≥ 1 after withdrawal, push collateralToken
    //   [ ] borrow(amount)    — accrue interest, check HF, transfer debtToken
    //   [ ] repay(amount)     — accrue interest, reduce debt, pull debtToken
    //   [ ] liquidate(user)   — assert HF < 1, seize (collateral * (1+bonus)), repay debt
    //   [ ] healthFactor(user) view — = (collateral * price * LIQ_THRESHOLD) / debt, scaled 1e18
    //   [ ] _accrueInterest(user) internal — linear: debt += debt * rate * dt
    //
    // ALL must use:
    //   - nonReentrant
    //   - whenNotPaused
    //   - SafeERC20
    //   - Checks-Effects-Interactions
    //   - oracle.getPrice() with staleness handled by adapter
    
}
