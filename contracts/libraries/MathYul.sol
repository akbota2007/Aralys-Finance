// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title MathYul
 * @notice Yul-optimized math primitives. Each function has a pure-Solidity twin in `MathSol`
 *         for the gas benchmark required by the spec.
 *
 *         OWNERSHIP: Zaure
 */
library MathYul {
    /// @notice Full-precision a·b/d with no overflow on the intermediate product.
    /// @dev Yul implementation of Remco Bloemen's mulDiv.
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        // TODO Zaure: implement full mulDiv in inline assembly.
        // Reference: https://xn--2-umb.com/21/muldiv/
        assembly {
            // placeholder so compilation works
            let prod := mul(a, b)
            result := div(prod, denominator)
        }
    }

    /// @notice Pack reserve0 (uint112) | reserve1 (uint112) | timestamp (uint32) into bytes32.
    function packReserves(uint112 r0, uint112 r1, uint32 ts) internal pure returns (bytes32 packed) {
        assembly {
            packed := or(or(r0, shl(112, r1)), shl(224, ts))
        }
    }

    function unpackReserves(bytes32 packed) internal pure returns (uint112 r0, uint112 r1, uint32 ts) {
        assembly {
            r0 := and(packed, 0xffffffffffffffffffffffffffff)
            r1 := and(shr(112, packed), 0xffffffffffffffffffffffffffff)
            ts := shr(224, packed)
        }
    }
}
