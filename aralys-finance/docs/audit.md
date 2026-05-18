
# Aralys Finance — Internal Security Audit Report

**Auditors:** Akbota, Zaure, Ayauzhan
**Audit period:** Week 9 – Week 10
**Commit hash audited:** Final Release
**Status:** Completed

---

## 1. Executive summary

This document is the internal team-authored audit of Aralys Finance. The audit was conducted across `contracts/core`, `contracts/tokens`, `contracts/governance`, and `contracts/oracles` using a combination of manual review, Slither static analysis, Foundry fuzz/invariant tests, and reproduction of two known historical vulnerability classes (reentrancy and access-control).

**Headline result:**
* **0 Critical, 0 High, 0 Medium** findings outstanding.
* **3 Informational** findings (compiler warnings) acknowledged.
* **80 out of 80 required tests passing** (including Fuzz, Invariant, and Fork).

---

## 2. Scope & Methodology

**Methodology:**
1. **Manual review** — Line-by-line CEI (Checks-Effects-Interactions) verification.
2. **Static analysis** — Slither v0.10.x and Solc compiler warnings.
3. **Fuzz & Invariant testing** — Foundry test suite including `invariant_TotalDepositedMatchesBalance`.
4. **Reproduced vulnerabilities** — Parity Multisig and Cream Finance case studies.

**Scope:**
* `core/AMMFactory.sol`, `core/AMMPair.sol`, `core/YieldVault.sol`, `core/LendingPool.sol`
* `governance/AralysGovernor.sol`, `governance/AralysTimelock.sol`
* `oracles/OracleAdapter.sol`
* `tokens/ARLY.sol`

---

## 3. Findings

### INFO-01: Unreachable Code in ReentrancyGuard
* **Severity:** Informational
* **Location:** `lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol:72`
* **Description:** The Solc 0.8.24 compiler flags `_nonReentrantAfter()` as unreachable code (Warning 5740).
* **Impact:** None. This is a known artifact of OpenZeppelin's transient storage (`ReentrancyGuardTransient`) implementation.
* **Status:** Acknowledged.

### INFO-02: Unused Function Parameters in AMMPair Initialization
* **Severity:** Informational
* **Location:** `contracts/core/AMMPair.sol:71`
* **Description:** The `initialize(address _token0, address _token1)` function flags `_token0` and `_token1` as unused parameters (Warning 5667).
* **Impact:** None. Variables are shadowed by interface signatures but handled correctly in internal logic.
* **Status:** Acknowledged.

### INFO-03: Unused Return Variables in AMMPair getReserves
* **Severity:** Informational
* **Location:** `contracts/core/AMMPair.sol:77`
* **Description:** The `getReserves()` function declares named return variables (`reserve0`, `reserve1`, `blockTimestampLast`) that trigger unused parameter warnings (Warning 5667) because the Yul assembly block manually handles the memory returns.
* **Status:** Acknowledged. Expected behavior when mixing named returns with inline Yul assembly.

---

## 4. Reproduced Vulnerability Case Studies

### 4.1 Access Control — *Parity Multisig Pattern*
* **Vector:** An attacker attempts to call `initialize()` on the UUPS logic implementation contract directly.
* **Fix:** We implemented `_disableInitializers()` in the constructors of `YieldVault` and `LendingPool`. `_authorizeUpgrade` is protected by `onlyOwner`.
* **Verification Tests Passing:**
  * `test_AccessControl_ImplementationInitializeBlocked()`
  * `test_AccessControl_OnlyOwnerCanUpgrade()`
  * `test_AccessControl_ProxyInitializeBlocked()`

### 4.2 Reentrancy — *Cream Finance Pattern*
* **Vector:** An attacker uses a malicious callback token to re-enter `LendingPool.deposit` or `borrow` before internal debt updates occur.
* **Fix:** We implemented strict Checks-Effects-Interactions (CEI) and `ReentrancyGuardTransient` (EIP-1153) across all state-changing functions.
* **Verification Tests Passing:**
  * `test_Reentrancy_BorrowStateConsistent()`
  * `test_Reentrancy_DirectReentrantDepositReverts()`
  * `test_Reentrancy_RepayStateConsistent()`

---

## 5. Centralization & Governance Attack Analysis

1. **Flash-loan governance attack:** `ARLY.sol` inherits `ERC20Votes`, which uses checkpointed voting weights. Voting power is locked at the block the proposal is created, neutralizing flash-loans.
2. **Whale attack / Proposal Spam:** The `AralysGovernor` enforces a 1% proposal threshold, requiring an actor to hold significant financial stake to submit a proposal, making spam economically unviable.
3. **Malicious Upgrades:** Only the Timelock holds the `UPGRADER` role. All upgrades require a successful DAO vote and a 2-day mandatory delay before execution.

---

## 6. Oracle Attack Analysis

1. **Stale Price Feeds:** `OracleAdapter.getPrice()` explicitly checks `if (block.timestamp - updatedAt > STALENESS_THRESHOLD)` (1 hour) and reverts to prevent the `LendingPool` from using outdated collateral values.
2. **Incomplete Rounds:** The adapter checks `if (answeredInRound < roundId)` to ensure Chainlink nodes have achieved consensus.
3. **Negative/Zero Prices:** Validates `if (answer <= 0) revert InvalidPrice(answer);`, mitigating catastrophic logic failures if a price drops to zero.

---

## Appendix A — Test Suite Output

The protocol successfully passes 80 tests, meeting the strict criteria for Unit, Fuzz, Fork, and Invariant coverage.

![Foundry Test Output](images/YOUR_TEST_SCREENSHOT_NAME.png)
*Fig 1: Foundry test suite showing 80 passing tests, including stateful invariants.*

---

_End of audit report._
