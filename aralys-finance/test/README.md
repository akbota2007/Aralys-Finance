# Test directory layout

```
test/
├── unit/         # ≥50 tests — every external function, every revert path
│   ├── ARLY.t.sol
│   ├── OracleAdapter.t.sol
│   ├── AMMPair.t.sol
│   ├── AMMFactory.t.sol
│   ├── YieldVault.t.sol
│   ├── LendingPool.t.sol
│   ├── AralysGovernor.t.sol
│   └── AralysTimelock.t.sol
├── fuzz/         # ≥10 tests — property-based, 1000+ runs
│   ├── AMMPair.fuzz.t.sol         (swap, mint, burn)
│   ├── YieldVault.fuzz.t.sol      (deposit/withdraw rounding)
│   └── Governor.fuzz.t.sol         (voting power)
├── invariant/    # ≥5 tests — stateful, k-invariant, supply, treasury
│   ├── AMMPair.invariant.t.sol     (k never decreases)
│   ├── YieldVault.invariant.t.sol  (assets >= shares)
│   ├── LendingPool.invariant.t.sol (HF or liquidatable)
│   ├── ARLY.invariant.t.sol        (totalSupply conservation)
│   └── Treasury.invariant.t.sol    (treasury accounting)
├── fork/         # ≥3 tests — real mainnet/testnet protocols
│   ├── RealUSDC.fork.t.sol         (Arb Sepolia USDC)
│   ├── RealChainlink.fork.t.sol    (Arb Sepolia ETH/USD feed)
│   └── UniswapRouter.fork.t.sol    (mainnet fork — interacts with Uni V2 router)
└── audit/        # vulnerability case studies
    ├── Reentrancy_PoC.t.sol
    ├── Reentrancy_Fix.t.sol
    ├── AccessControl_PoC.t.sol
    └── AccessControl_Fix.t.sol
```

## Test count target (for spec §3.3)

| Category   | Min required | Our plan |
| ---------- | ------------ | -------- |
| Unit       | 50           | 55       |
| Fuzz       | 10           | 12       |
| Invariant  | 5            | 5        |
| Fork       | 3            | 3        |
| Audit case | 0 (counted in unit) | 4 |
| **Total**  | **80**       | **79+ hard floor; reach for 90** |

## Coverage target

`forge coverage --report summary` must show **≥ 90 %** lines on `contracts/` directory.
Output committed to `docs/coverage.md` at submission.

## Naming convention

- `test_<Function>_<Condition>` — happy path
- `test_<Function>_Reverts_<Reason>` — revert path
- `testFuzz_<Function>_<Property>` — fuzz
- `invariant_<Property>` — invariant
- `testFork_<Function>` — fork
