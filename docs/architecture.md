# Aralys Finance — Architecture & Design Document

**Version:** 0.1 (skeleton — fill before W10)
**Authors:** \<Team Lead\>, Zaure, Ayauzhan
**Last updated:** _date_

---

## 1. Executive summary

Aralys Finance is a modular DeFi super-app composed of three on-chain primitives — a constant-product AMM, an ERC-4626 yield vault, and a collateralized lending pool — coordinated by an OpenZeppelin Governor + Timelock governance stack and priced via Chainlink oracles. The system is deployed on Arbitrum Sepolia (L2) and indexed via The Graph for off-chain reads.

This document covers: system context, container/component view, data model, trust assumptions, and a log of architectural decisions (ADRs).

---

## 2. System context (C4 Level 1)

> **TODO** _Insert C4 Level-1 diagram here as `diagrams/c4-l1.png`._

External actors:

- **Liquidity provider (LP)** — deposits ERC-20 pairs, receives LP tokens, optionally stakes them in the YieldVault.
- **Trader** — performs swaps on the AMM, pays 0.3% fee.
- **Borrower** — locks LP shares as collateral, draws stablecoin debt.
- **ARLY holder / voter** — holds the governance token, delegates voting power, votes on proposals.
- **Governance executor** — anyone can `execute()` a queued proposal once the Timelock delay passes.
- **Chainlink oracle network** — pushes price updates to AggregatorV3 feeds.
- **The Graph indexer node** — ingests protocol events.

Boundaries:

- On-chain: everything in `contracts/`.
- Off-chain (read-only): subgraph, frontend.
- Off-chain (trusted): Chainlink price feeds (mitigation: staleness check).

---

## 3. Container / component diagram (C4 Level 2)

> **TODO** _Insert component diagram here as `diagrams/c4-l2.png`. Show: AMMFactory → AMMPair, LendingPool ← OracleAdapter, YieldVault → AMMPair (LP token), Governor ⇄ Timelock ⇄ all ownable contracts._

### 3.1 Contracts and their relationships

| Contract           | Type            | Owner / admin    | Key dependencies               |
| ------------------ | --------------- | ---------------- | ------------------------------ |
| `ARLY`             | ERC20Votes + ERC20Permit | none (immutable supply) | — |
| `AralysTimelock`   | TimelockController | Governor (PROPOSER), anyone (EXECUTOR) | — |
| `AralysGovernor`   | Governor (full OZ stack) | — | ARLY, Timelock |
| `AMMFactory`       | Factory (CREATE2) | Timelock | — |
| `AMMPair`          | Pool (cloned)   | Factory          | ERC20 token pair |
| `YieldVault`       | ERC-4626 (UUPS) | Timelock         | AMMPair LP token |
| `YieldVaultV2`     | UUPS upgrade target | Timelock     | (added in W9 to demonstrate upgrade) |
| `LendingPool`      | Custom (UUPS)   | Timelock         | YieldVault, OracleAdapter, ARLY |
| `OracleAdapter`    | Adapter         | Timelock (set feed) | Chainlink AggregatorV3 |
| `MockAggregator`   | Test only       | Test wallet      | — |

### 3.2 Proxy layout

- `YieldVault` and `LendingPool` use the **UUPS proxy pattern**.
- `AMMPair` instances use **EIP-1167 minimal proxies** (clones), deployed by `AMMFactory` via `CREATE2` with `keccak256(abi.encode(token0, token1))` as salt — making pair addresses deterministic.

> **TODO** _Insert proxy layout diagram. Show the storage slot collision risk — ERC1967 implementation slot is `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`. Demonstrate that storage gap of 50 slots is preserved in UUPS contracts._

---

## 4. Sequence diagrams (3 critical flows)

### 4.1 Swap flow

> **TODO** _Insert sequence diagram `diagrams/seq-swap.png`._

```
Trader → AMMPair.swap(amountOut, to, data)
  AMMPair → ERC20.transfer(to, amountOut)         [Effects before external calls — CEI]
  AMMPair → balance check on token0, token1
  AMMPair: assert(reserve0 * reserve1 >= k_before)  [invariant]
  AMMPair → emit Swap(...)
```

### 4.2 Governance lifecycle (propose → vote → queue → execute)

> **TODO** _Insert sequence diagram `diagrams/seq-governance.png`._

```
Proposer (≥1% supply) → Governor.propose(targets, values, calldatas, description)
  Governor: state = Pending (1 day delay)
  state = Active (1 week voting period)
Voters → Governor.castVote(proposalId, support)
  state = Succeeded (if quorum 4% met and majority for)
Anyone → Governor.queue(...)
  Timelock: schedule(hash, delay = 2 days)
  state = Queued
[2 days pass]
Anyone → Governor.execute(...)
  Timelock → target.call(payload)
  state = Executed
```

### 4.3 Borrow & liquidation flow

> **TODO** _Insert sequence diagram `diagrams/seq-borrow.png`._

```
Borrower → LendingPool.deposit(LP_shares)
Borrower → LendingPool.borrow(amount)
  LendingPool → OracleAdapter.getPrice(collateralAsset)
  OracleAdapter → Chainlink.latestRoundData()
  OracleAdapter: revert if updatedAt < block.timestamp - STALENESS
  LendingPool: healthFactor = (collateral * price * LTV) / debt
  require(healthFactor >= 1e18)
[time passes, price drops]
Liquidator → LendingPool.liquidate(borrower)
  LendingPool: recompute HF, must be < 1e18
  LendingPool → seize(collateral) + repay(debt)
```

---

## 5. Data model — storage layouts

> **CRITICAL** for upgradeable contracts: we must prove storage collisions are impossible across upgrade paths.

### 5.1 `YieldVault` (UUPS)

| Slot | Variable                | Type     |
| ---- | ----------------------- | -------- |
| 0    | `_initialized`          | uint8 (OZ Initializable) |
| 1–50 | OZ ERC4626Upgradeable storage | reserved |
| 51   | `feeRecipient`          | address  |
| 52   | `performanceFeeBps`     | uint96   |
| 53–102 | `__gap`               | uint256[50] |

> **TODO** _Run `forge inspect YieldVault storageLayout` and paste full output here. Repeat for `YieldVaultV2` and prove no slot is reused for a different type._

### 5.2 `LendingPool` (UUPS)

> **TODO** _Same — paste `forge inspect` output. Document `__gap` and explain why 50 slots is enough._

### 5.3 `AMMPair`

Non-upgradeable. Uses packed `Reserves` struct (uint112, uint112, uint32 timestamp) at slot 0 — same trick as Uniswap V2 to fit one SSTORE.

> **TODO** _Document Yul-optimized `_update()` and explain the storage packing._

---

## 6. Trust assumptions

| Role                 | Held by              | Powers                                    | Risk if compromised                  | Mitigation |
| -------------------- | -------------------- | ----------------------------------------- | ------------------------------------ | ---------- |
| `DEFAULT_ADMIN_ROLE` on Timelock | Timelock itself (post-deploy renounce) | nothing — renounced after setup | — | Verified via `script/PostDeployVerify.s.sol` |
| `PROPOSER_ROLE` on Timelock | Governor          | Schedule any tx                           | Could schedule malicious upgrade — but 2-day delay gives community time to react | Timelock delay + GUARDIAN can cancel |
| `EXECUTOR_ROLE` on Timelock | `address(0)` (open) | Anyone can execute after delay            | None — execution is permissionless   | — |
| `CANCELLER_ROLE`     | Multisig (2-of-3 — Team) | Cancel queued proposal               | Could censor governance              | Renounced before final submission |
| `UPGRADER` on UUPS contracts | Timelock        | Upgrade implementation                    | Same as malicious upgrade            | 2-day Timelock delay |
| `feeRecipient` on Vault | Timelock          | Receive performance fee                   | None (pull-only)                     | — |

### Trust matrix summary

- **No EOA has any privileged power after deployment.** All admin functions point to Timelock.
- **Timelock has a 2-day delay** on every action — sufficient for community response.
- **Governor parameters** (delay, period, quorum, threshold) can only be changed by governance itself.

> **TODO** _Add: "what if multisig is compromised before renounce" scenario — what's our recovery path?_

---

## 7. Architectural Decision Records (ADRs)

### ADR-001: Use UUPS over Transparent Proxy

- **Context.** We need upgradeable Vault and LendingPool to demonstrate the V1 → V2 path required by the spec.
- **Options considered.** Transparent proxy (admin in separate slot, more bytecode), UUPS (`_authorizeUpgrade` in implementation), Beacon proxy.
- **Decision.** UUPS.
- **Consequences.** Smaller proxy bytecode, but upgrade logic lives in implementation — must be explicitly preserved across upgrades. Mitigated by storage gaps and an upgrade test.

### ADR-002: Build AMM from scratch (not fork Uniswap V2)

- **Context.** Spec requires "one of these must be built from scratch."
- **Options.** Fork V2 / fork V3 / write our own x·y=k.
- **Decision.** Write our own constant-product AMM in `core/AMMPair.sol`, with a Yul-optimized `_update()` reserves-packing function for the gas benchmark.
- **Consequences.** More code to audit, but satisfies the spec and gives us a clean Yul comparison.

### ADR-003: CREATE2 for pair deployment, EIP-1167 clones for the implementation

- **Context.** Factory must use both CREATE and CREATE2.
- **Decision.** `AMMFactory.deployImplementation()` uses plain `CREATE` once at construction; `AMMFactory.createPair()` uses `CREATE2 + clone` so pair addresses are predictable from the token pair.
- **Consequences.** Satisfies spec; predictable addresses simplify subgraph tracking and frontend.

### ADR-004: Chainlink staleness threshold = 1 hour

- **Context.** Need to revert stale prices.
- **Decision.** `if (block.timestamp - updatedAt > 3600) revert StalePrice();`
- **Consequences.** ETH/USD on Arb Sepolia heartbeat is well under 1 hour, so false positives are unlikely. Documented in audit §Oracle Attack Analysis.

### ADR-005: Governor quorum = 4%, threshold = 1%, voting period = 1 week

- **Context.** Spec mandates these exact values.
- **Decision.** Hardcoded in deploy script, sourced from `.env` for parameterization.
- **Consequences.** Identical to OZ Bravo defaults.

> **TODO** _Add ADRs for: 0.3% AMM fee, LTV = 75%, liquidation bonus = 5%, why Arbitrum Sepolia over Optimism Sepolia._

---

## 8. Design patterns used

The protocol consciously implements the following patterns (each justified):

1. **Factory** — `AMMFactory` deploys `AMMPair` clones via CREATE2.
2. **UUPS Proxy** — `YieldVault`, `LendingPool` for upgradeability.
3. **Checks-Effects-Interactions** — applied throughout, esp. in `AMMPair.swap`, `LendingPool.liquidate`.
4. **Pull-over-push** — `feeRecipient` pulls accrued fees instead of being pushed on every action.
5. **Access Control / Role-based** — `AccessControl` on `OracleAdapter` for feed configuration; `Ownable` (= Timelock) elsewhere.
6. **Pausable / Circuit Breaker** — `LendingPool` and `YieldVault` are `Pausable`, paused only by Timelock.
7. **Oracle adapter / interface abstraction** — `IPriceOracle` lets us swap Chainlink for a mock in tests.
8. **Timelock** — 2-day delay on all governance actions.
9. **Reentrancy Guard** — `nonReentrant` on `AMMPair.swap`, `LendingPool.borrow/repay/liquidate`, `YieldVault.deposit/withdraw`.

> **TODO** _Confirm at least 5 (we have 9 — well above the minimum). Make sure each is referenced from `audit.md` §Findings._

---

## 9. Open issues / future work

- ARLY token has fixed supply; no inflation mechanism.
- Lending pool supports only one collateral type (LP shares of the canonical USDC/ETH pair) for v1. Multi-collateral added by upgrade in v2.
- No flash-loan facility (intentional — out of scope).

---

_End of document._
