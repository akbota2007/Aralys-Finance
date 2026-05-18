// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC4626Upgradeable } from
    "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from
    "../libraries/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title YieldVault
 * @notice ERC-4626 tokenized vault. Users deposit LP tokens, earn yield from protocol fees.
 * @dev    UUPS upgradeable. Owner is the Aralys Timelock.
 *
 *         OWNERSHIP: Zaure
 *
 *         IMPLEMENTATION CHECKLIST:
 *           [ ] initialize(asset, owner) — disables initializers in constructor
 *           [ ] _authorizeUpgrade(newImpl) — onlyOwner
 *           [ ] performance fee logic (configurable, default 1000 bps = 10 %)
 *           [ ] inflation-attack mitigation (OZ v5 ERC4626 has _decimalsOffset = 0 by default;
 *               we override to 6 to make donation attack uneconomic)
 *
 *         INVARIANTS:
 *           1. totalAssets() ≥ totalSupply() rounded down (no inflation attack)
 *           2. previewDeposit(x) <= deposit(x).shares actually minted (rounding favors vault)
 *           3. previewRedeem(x) >= redeem(x).assets actually returned
 */
contract YieldVault is
    Initializable,
    ERC4626Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    /// @custom:storage-location erc7201:aralys.storage.YieldVault
    struct VaultStorage {
        address feeRecipient;
        uint96 performanceFeeBps;
    }

    // keccak256(abi.encode(uint256(keccak256("aralys.storage.YieldVault")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant VAULT_STORAGE_LOCATION =
        0x0000000000000000000000000000000000000000000000000000000000000000; // TODO Zaure: compute

    function _getVaultStorage() private pure returns (VaultStorage storage $) {
        bytes32 slot = VAULT_STORAGE_LOCATION;
        assembly {
            $.slot := slot
        }
    }

    error InvalidFee(uint96 bps);

    event FeeRecipientChanged(address indexed newRecipient);
    event PerformanceFeeChanged(uint96 newBps);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IERC20 asset_, address owner_, address feeRecipient_) external initializer {
        __ERC20_init("Aralys Yield Vault", "yARLY");
        __ERC4626_init(asset_);
        __Ownable_init(owner_);
        __ReentrancyGuard_init();
        __Pausable_init();
        

        VaultStorage storage $ = _getVaultStorage();
        $.feeRecipient = feeRecipient_;
        $.performanceFeeBps = 1000; // 10 % default
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @dev Inflation-attack mitigation: increase share decimals offset.
    function _decimalsOffset() internal pure override returns (uint8) {
        return 6;
    }

    function setFeeRecipient(address recipient) external onlyOwner {
        _getVaultStorage().feeRecipient = recipient;
        emit FeeRecipientChanged(recipient);
    }

    function setPerformanceFee(uint96 bps) external onlyOwner {
        if (bps > 2000) revert InvalidFee(bps); // cap at 20 %
        _getVaultStorage().performanceFeeBps = bps;
        emit PerformanceFeeChanged(bps);
    }

    function feeRecipient() external view returns (address) {
        return _getVaultStorage().feeRecipient;
    }

    function performanceFeeBps() external view returns (uint96) {
        return _getVaultStorage().performanceFeeBps;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // TODO Zaure: override `_deposit` and `_withdraw` to add `nonReentrant` and `whenNotPaused` modifiers
    //             via a wrapper; add fee-accrual logic.
}
