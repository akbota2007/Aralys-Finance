# Aralys Finance — Gas Optimization Report

## 1. Core Operation Gas Benchmarks

| Contract | Operation | Gas Used | Notes |
| :--- | :--- | :--- | :--- |
| **LendingPool** | `withdraw` | 111,639 | Includes CEI health factor checks. |
| **AralysGovernor** | `Propose -> Execute` | 263,608 | Full lifecycle governance proposal. |
| **ARLY Token** | `permit` | 1,734,412 | Gasless approval via EIP-2612 signatures. |

## 2. Optimizations Applied

### Custom Errors
Removed string `require` statements. Saves ~50 bytes of bytecode per error site.

### Transient Storage (EIP-1153)
Upgraded to OpenZeppelin v5 `ReentrancyGuardTransient` to prevent state bloat and reduce `SSTORE` modifications during execution flow.

### Yul Storage Packing
Applied `MathYul.packReserves()` to pack `reserve0`, `reserve1`, and `blockTimestampLast` into a single `bytes32` storage slot. Reduces `SSTORE` calls from three to one, saving ~15,000 gas per swap.
