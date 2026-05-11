# Aralys Finance — Gas Optimization Report

**Status:** Skeleton — fill after benchmarks in W9.

---

## 1. Methodology

All measurements taken via `forge test --gas-report` on commit `<hash>`, Solidity 0.8.24, optimizer runs = 200, `via_ir = true`.

L2 measurements taken on Arbitrum Sepolia at block `<block>`. L1 baseline is Foundry's local EVM (Cancun).

---

## 2. Yul-optimized vs pure-Solidity comparison

The `MathYul` library implements two functions in inline assembly:

1. `mulDiv(uint256 a, uint256 b, uint256 d)` — full-precision a·b/d.
2. `packReserves(uint112, uint112, uint32)` — pack three values into one `bytes32` for a single SSTORE.

| Function          | Pure Solidity (gas) | Yul (gas) | Δ          |
| ----------------- | ------------------- | --------- | ---------- |
| `mulDiv`          | TBD                 | TBD       | TBD %      |
| `packReserves`    | TBD                 | TBD       | TBD %      |

> **TODO** _Run `forge test --match-test testGas_* --gas-report` and fill in._

---

## 3. L1 vs L2 gas comparison

Six core operations measured on Ethereum mainnet (simulated) and Arbitrum Sepolia:

| Operation                   | L1 gas   | L2 gas   | L2 USD cost | Notes                |
| --------------------------- | -------- | -------- | ----------- | -------------------- |
| AMM `swap` (single hop)     | TBD      | TBD      | TBD         |                      |
| AMM `addLiquidity`          | TBD      | TBD      | TBD         |                      |
| Vault `deposit`             | TBD      | TBD      | TBD         |                      |
| Vault `withdraw`            | TBD      | TBD      | TBD         |                      |
| LendingPool `borrow`        | TBD      | TBD      | TBD         |                      |
| Governor `castVote`         | TBD      | TBD      | TBD         |                      |

> **TODO** _Use `cast` against deployed Arb Sepolia contracts. USD cost = gas × gas_price × ETH_price._

---

## 4. Optimizations applied

1. **Packed reserves struct** in `AMMPair` — one SSTORE instead of three. Saves ~15k gas per swap.
2. **Custom errors** instead of `require` strings — saves ~50 bytes per error site.
3. **Unchecked arithmetic** in invariant-safe loops (`for` counters).
4. **`immutable` over `constant`** for deploy-time-known values (token addresses).
5. **`calldata` over `memory`** for read-only function arguments.

> **TODO** _Add before/after benchmarks for each optimization._

---

_End of report._
