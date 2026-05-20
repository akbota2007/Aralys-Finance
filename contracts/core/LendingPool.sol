// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "../libraries/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OracleAdapter } from "../oracles/OracleAdapter.sol";

contract LendingPool is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    IERC20 public collateralToken;
    IERC20 public debtToken;
    OracleAdapter public oracle;
    address public collateralAsset;

    uint256 public constant LTV_BPS = 7500;
    uint256 public constant LIQ_THRESHOLD_BPS = 8000;
    uint256 public constant LIQ_BONUS_BPS = 500;
    uint256 public constant BPS = 10_000;
    uint256 public constant WAD = 1e18;

    uint256 public annualInterestRate;

    struct Position {
        uint128 collateral;
        uint128 debt;
        uint256 lastAccrued;
    }

    mapping(address user => Position) public positions;

    uint256 public totalDeposited;
    uint256 public totalBorrowed;

    error ZeroAmount();
    error InsufficientCollateral(uint256 healthFactor);
    error PositionIsHealthy(uint256 healthFactor);
    error ExceedsDeposit(uint256 requested, uint256 available);
    error ExceedsDebt(uint256 requested, uint256 debt);

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(
        address indexed liquidator,
        address indexed user,
        uint256 debtRepaid,
        uint256 collateralSeized
    );
    event InterestRateUpdated(uint256 newRate);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 collateralToken_,
        IERC20 debtToken_,
        OracleAdapter oracle_,
        address collateralAsset_,
        address owner_
    ) external initializer {
        __Ownable_init(owner_);
        __ReentrancyGuard_init();
        __Pausable_init();

        collateralToken = collateralToken_;
        debtToken = debtToken_;
        oracle = oracle_;
        collateralAsset = collateralAsset_;
        annualInterestRate = 5e16;
    }

    function setInterestRate(uint256 newRate) external onlyOwner {
        annualInterestRate = newRate;
        emit InterestRateUpdated(newRate);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);
        positions[msg.sender].collateral += uint128(amount);
        totalDeposited += amount;

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        Position storage pos = positions[msg.sender];
        if (amount > pos.collateral) revert ExceedsDeposit(amount, pos.collateral);

        _accrueInterest(msg.sender);
        pos.collateral -= uint128(amount);
        totalDeposited -= amount;

        if (pos.debt > 0) {
            uint256 hf = _healthFactor(msg.sender);
            if (hf < WAD) revert InsufficientCollateral(hf);
        }

        collateralToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);
        positions[msg.sender].debt += uint128(amount);
        totalBorrowed += amount;

        uint256 hf = _healthFactor(msg.sender);
        if (hf < WAD) revert InsufficientCollateral(hf);

        debtToken.safeTransfer(msg.sender, amount);
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        _accrueInterest(msg.sender);
        Position storage pos = positions[msg.sender];

        uint256 repayAmount = amount > pos.debt ? pos.debt : amount;
        pos.debt -= uint128(repayAmount);
        totalBorrowed -= repayAmount;

        debtToken.safeTransferFrom(msg.sender, address(this), repayAmount);
        emit Repaid(msg.sender, repayAmount);
    }

    function liquidate(address user, uint256 debtAmount) external nonReentrant whenNotPaused {
        if (debtAmount == 0) revert ZeroAmount();

        _accrueInterest(user);
        uint256 hf = _healthFactor(user);
        if (hf >= WAD) revert PositionIsHealthy(hf);

        Position storage pos = positions[user];
        uint256 actualDebt = debtAmount > pos.debt ? pos.debt : debtAmount;

        uint256 price = oracle.getPrice(collateralAsset);
        uint256 collateralSeized = (actualDebt * (BPS + LIQ_BONUS_BPS) * WAD) / (BPS * price);
        if (collateralSeized > pos.collateral) collateralSeized = pos.collateral;

        pos.debt -= uint128(actualDebt);
        pos.collateral -= uint128(collateralSeized);
        totalBorrowed -= actualDebt;
        totalDeposited -= collateralSeized;

        debtToken.safeTransferFrom(msg.sender, address(this), actualDebt);
        collateralToken.safeTransfer(msg.sender, collateralSeized);

        emit Liquidated(msg.sender, user, actualDebt, collateralSeized);
    }

    function healthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getPosition(address user)
        external
        view
        returns (uint256 collateral, uint256 debt, uint256 hf)
    {
        Position storage pos = positions[user];
        collateral = pos.collateral;
        debt = pos.debt;
        hf = debt == 0 ? type(uint256).max : _healthFactor(user);
    }

    function _accrueInterest(address user) internal {
        Position storage pos = positions[user];
        if (pos.debt == 0 || pos.lastAccrued == 0) {
            pos.lastAccrued = block.timestamp;
            return;
        }
        uint256 dt = block.timestamp - pos.lastAccrued;
        if (dt == 0) return;

        uint256 interest = (uint256(pos.debt) * annualInterestRate * dt) / (365 days * WAD);
        pos.debt += uint128(interest);
        totalBorrowed += interest;
        pos.lastAccrued = block.timestamp;
    }

    function _healthFactor(address user) internal view returns (uint256) {
        Position storage pos = positions[user];
        if (pos.debt == 0) return type(uint256).max;

        uint256 price = oracle.getPrice(collateralAsset);
        uint256 collateralValue = (uint256(pos.collateral) * price * LIQ_THRESHOLD_BPS) / BPS;
        uint256 debtValue = uint256(pos.debt) * WAD;
        return collateralValue / (debtValue / WAD);
    }
}
