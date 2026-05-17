// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IAMMFlashCallee {
    function aralysCall(
        address sender,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata data
    ) external;
}

contract AMMPair is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public factory;
    address public token0;
    address public token1;

    bytes32 private _packedReserves;

    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    error AlreadyInitialized();
    error OnlyFactory();
    error InvalidToken();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InsufficientOutputAmount();
    error InsufficientInputAmount();
    error InsufficientLiquidity();
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
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        if (token0 != address(0)) revert AlreadyInitialized();

        if (factory == address(0)) {
            factory = msg.sender;
        } else if (msg.sender != factory) {
            revert OnlyFactory();
        }

        if (
            _token0 == address(0) ||
            _token1 == address(0)
        ) {
            revert InvalidToken();
        }

        token0 = _token0;
        token1 = _token1;
    }

    function getReserves()
        public
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        )
    {
        bytes32 packed = _packedReserves;

        assembly {
            reserve0 := and(packed, 0xffffffffffffffffffffffffffff)
            reserve1 := and(shr(112, packed), 0xffffffffffffffffffffffffffff)
            blockTimestampLast := shr(224, packed)
        }
    }

    function mint(address to)
        external
        nonReentrant
        returns (uint256 liquidity)
    {
        (uint112 reserve0, uint112 reserve1,) = getReserves();

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;

        uint256 supply = totalSupply();

        if (supply == 0) {
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0xdead), MINIMUM_LIQUIDITY);
        } else {
            liquidity = _min(
                (amount0 * supply) / reserve0,
                (amount1 * supply) / reserve1
            );
        }

        if (liquidity == 0) revert InsufficientLiquidityMinted();

        _mint(to, liquidity);
        _update(balance0, balance1);

        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {

        address _token0 = token0;
        address _token1 = token1;

        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));

        uint256 liquidity = balanceOf(address(this));
        uint256 supply = totalSupply();

        amount0 = (liquidity * balance0) / supply;
        amount1 = (liquidity * balance1) / supply;

        if (amount0 == 0 || amount1 == 0) {
            revert InsufficientLiquidityBurned();
        }

        _burn(address(this), liquidity);

        IERC20(_token0).safeTransfer(to, amount0);
        IERC20(_token1).safeTransfer(to, amount1);

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1);

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    )
        external
        nonReentrant
    {
        if (amount0Out == 0 && amount1Out == 0) {
            revert InsufficientOutputAmount();
        }

        (uint112 reserve0, uint112 reserve1,) = getReserves();

        if (amount0Out >= reserve0 || amount1Out >= reserve1) {
            revert InsufficientLiquidity();
        }

        address _token0 = token0;
        address _token1 = token1;

        if (to == _token0 || to == _token1) revert InvalidTo();

        if (amount0Out > 0) {
            IERC20(_token0).safeTransfer(to, amount0Out);
        }

        if (amount1Out > 0) {
            IERC20(_token1).safeTransfer(to, amount1Out);
        }

        if (data.length > 0) {
            IAMMFlashCallee(to).aralysCall(
                msg.sender,
                amount0Out,
                amount1Out,
                data
            );
        }

        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));

        uint256 amount0In =
            balance0 > reserve0 - amount0Out
                ? balance0 - (reserve0 - amount0Out)
                : 0;

        uint256 amount1In =
            balance1 > reserve1 - amount1Out
                ? balance1 - (reserve1 - amount1Out)
                : 0;

        if (amount0In == 0 && amount1In == 0) {
            revert InsufficientInputAmount();
        }

        uint256 balance0Adjusted =
            (balance0 * FEE_DENOMINATOR) -
            (amount0In * (FEE_DENOMINATOR - FEE_NUMERATOR));

        uint256 balance1Adjusted =
            (balance1 * FEE_DENOMINATOR) -
            (amount1In * (FEE_DENOMINATOR - FEE_NUMERATOR));

        if (
            balance0Adjusted * balance1Adjusted <
            uint256(reserve0) *
                uint256(reserve1) *
                FEE_DENOMINATOR *
                FEE_DENOMINATOR
        ) {
            revert KInvariantViolated();
        }

        _update(balance0, balance1);

        emit Swap(
            msg.sender,
            amount0In,
            amount1In,
            amount0Out,
            amount1Out,
            to
        );
    }

    function skim(address to) external nonReentrant {
        address _token0 = token0;
        address _token1 = token1;

        (uint112 reserve0, uint112 reserve1,) = getReserves();

        IERC20(_token0).safeTransfer(
            to,
            IERC20(_token0).balanceOf(address(this)) - reserve0
        );

        IERC20(_token1).safeTransfer(
            to,
            IERC20(_token1).balanceOf(address(this)) - reserve1
        );
    }

    function sync() external nonReentrant {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }

    function _update(uint256 balance0, uint256 balance1) internal {
        if (
            balance0 > type(uint112).max ||
            balance1 > type(uint112).max
        ) {
            revert InsufficientLiquidity();
        }

        uint32 blockTimestampLast =
            uint32(block.timestamp % 2 ** 32);

        bytes32 packed;

        assembly {
            packed := or(
                or(balance0, shl(112, balance1)),
                shl(224, blockTimestampLast)
            )
        }

        _packedReserves = packed;

        emit Sync(
            uint112(balance0),
            uint112(balance1)
        );
    }

    function _sqrt(uint256 y)
        private
        pure
        returns (uint256 z)
    {
        if (y > 3) {
            z = y;
            uint256 x = (y / 2) + 1;

            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 x, uint256 y)
        private
        pure
        returns (uint256)
    {
        return x < y ? x : y;
    }
}