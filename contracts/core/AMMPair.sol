// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AMMPair
 * @notice Constant-product (x·y=k) AMM pair with 0.3% fee, written from scratch.
 * @dev    Cloned by AMMFactory via EIP-1167. Uses Yul-packed reserves for gas savings.
 *
 *         OWNERSHIP: Zaure
 *
 *         IMPLEMENTATION CHECKLIST (TODO before W8):
 *           [ ] initialize(token0, token1) — settable once, only by factory
 *           [ ] mint(address to)         — adds liquidity, mints LP tokens (sqrt(x*y) for first deposit)
 *           [ ] burn(address to)         — removes liquidity, burns LP tokens
 *           [ ] swap(amount0Out, amount1Out, to, data) — CEI pattern, reentrancy-guarded
 *           [ ] _update(balance0, balance1) — Yul-optimized reserves packing
 *           [ ] getReserves() public view — returns unpacked reserves
 *           [ ] sync() / skim() — UniV2-style edge-case helpers
 *           [ ] k-invariant assert in swap: balance0Adj * balance1Adj >= reserve0 * reserve1 * 1e6
 *
 *         INVARIANTS (must hold after every external call):
 *           1. totalSupply == sum(LP balances)
 *           2. token0.balanceOf(address(this)) >= reserve0
 *           3. token1.balanceOf(address(this)) >= reserve1
 *           4. After swap: reserve0 * reserve1 >= k_before (after fee adjustment)
 */
contract AMMPair is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public factory;
    address public token0;
    address public token1;

    /// @dev packed: reserve0 (uint112) | reserve1 (uint112) | blockTimestampLast (uint32)
    bytes32 private _packedReserves;

    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    error AlreadyInitialized();
    error OnlyFactory();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InsufficientOutputAmount();
    error InsufficientInputAmount();
    error KInvariantViolated();
    error InvalidTo();

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() ERC20("Aralys LP", "ARLY-LP") {
        factory = msg.sender; // factory at construction; replaced if cloned
    }

    function initialize(address _token0, address _token1) external {
        // TODO Zaure: implement — guard with `if (token0 != address(0)) revert AlreadyInitialized();`
        // and `if (msg.sender != factory) revert OnlyFactory();`
        revert("not implemented");
    }

    function getReserves() public view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        // TODO Zaure: unpack `_packedReserves` via Yul.
        revert("not implemented");
    }

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        // TODO Zaure: see Uniswap V2 for the algorithm, but write from scratch.
        revert("not implemented");
    }

    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        // TODO Zaure
        revert("not implemented");
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data)
        external
        nonReentrant
    {
        // TODO Zaure:
        //   1. Checks: amount0Out > 0 || amount1Out > 0; reserves sufficient; to != token0 && to != token1.
        //   2. Effects: optimistically transfer out (CEI — only after we read reserves).
        //   3. Interactions: callback if `data.length > 0` (flash-swap support).
        //   4. K-invariant assertion using FEE_NUMERATOR.
        //   5. _update().
        revert("not implemented");
    }

    /**
     * @dev Yul-optimized reserves packing. Single SSTORE for all three values.
     *      MUST be benchmarked against a Solidity-only equivalent in `gas-report.md`.
     */
    function _update(uint256 balance0, uint256 balance1) internal {
        // TODO Zaure: implement in inline assembly.
        // Pack: reserve0 (low 112 bits) | reserve1 (next 112 bits) | timestamp (top 32 bits).
        revert("not implemented");
    }
}
