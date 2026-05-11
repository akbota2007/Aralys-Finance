# Aralys Finance — Sprint plan W7 → W10

> Cross-reference with `Final_Project.pdf` §8 (Milestones).
> Each task lists the **owner** and the **commit message prefix** to use (Conventional Commits).
> Estimated hours are wall-clock per person.

Legend: 🟦 Lead • 🟩 Zaure • 🟨 Ayauzhan

---

## Week 7 — "Compile & first tests pass"

**Milestone deliverable:** Repo link, initial CI green.

| # | Owner | Task | Commit |
| - | ----- | ---- | ------ |
| 7.1 | 🟦 | `forge init`, install OZ + chainlink + forge-std submodules, push initial commit | `chore: scaffold foundry project` |
| 7.2 | 🟦 | Set up CI workflow, branch protection on `main`, require PR review | `ci: add github actions pipeline` |
| 7.3 | 🟦 | Pre-commit hook (`forge fmt --check` + `solhint`) | `chore: add pre-commit lint` |
| 7.4 | 🟨 | Implement `ARLY` token + 5 unit tests (mint, transfer, permit, delegate, votes) | `feat(tokens): add ARLY governance token` |
| 7.5 | 🟨 | Implement `OracleAdapter` + `MockAggregator` + 5 unit tests (incl. stale, zero, incomplete round) | `feat(oracles): add Chainlink adapter with staleness` |
| 7.6 | 🟩 | Implement `AMMPair.initialize` + `mint` + `burn` (no swap yet) + 5 unit tests | `feat(amm): pair init, mint, burn` |
| 7.7 | 🟩 | Implement `AMMFactory` + `predictPairAddress` test + CREATE2 salt test | `feat(amm): factory with CREATE + CREATE2` |
| 7.8 | 🟦 | `AralysTimelock` + `AralysGovernor` + 3 unit tests (propose, vote, queue happy path) | `feat(governance): governor + timelock setup` |

**End-of-week check:** `forge build` green, `forge test` ≥ 18 tests passing, CI green.

---

## Week 8 — "DeFi primitive + tokens complete, 50% coverage"

**Milestone:** Mid-project review checkpoint.

| # | Owner | Task | Commit |
| - | ----- | ---- | ------ |
| 8.1 | 🟩 | Implement `AMMPair.swap` with CEI + reentrancy guard | `feat(amm): swap with k-invariant check` |
| 8.2 | 🟩 | `MathYul.mulDiv` + `packReserves` (assembly) + Solidity twins for benchmark | `feat(libs): add Yul math + benchmarks` |
| 8.3 | 🟩 | YieldVault initialize + deposit/withdraw + inflation-attack test | `feat(vault): ERC4626 vault with UUPS` |
| 8.4 | 🟩 | Vault upgrade test V1 → V2 (V2 = adds a single new function, e.g. `harvestFee()`) | `test(vault): UUPS upgrade path V1 -> V2` |
| 8.5 | 🟦 | `LendingPool` initialize + deposit/withdraw + healthFactor view | `feat(lending): collateral deposit + HF view` |
| 8.6 | 🟦 | `LendingPool.borrow` + `repay` + interest accrual | `feat(lending): borrow, repay, accrual` |
| 8.7 | 🟦 | `LendingPool.liquidate` + 3 fork tests using real USDC on Arb Sepolia | `feat(lending): liquidation` + `test(fork): real USDC` |
| 8.8 | 🟨 | Frontend scaffold (Vite + React + Wagmi + Viem). Wallet connect + token balance read. | `feat(frontend): scaffold + wallet connect` |
| 8.9 | 🟨 | Subgraph scaffold (`subgraph.yaml`, `schema.graphql` already done — write 3 mapping files) | `feat(subgraph): factory + pair mappings` |

**End-of-week check:** `forge coverage` ≥ 50 %, ≥ 35 tests, frontend can read ARLY balance.

---

## Week 9 — "Governance + oracles + L2 deployment"

**Milestone:** Testnet addresses + subgraph live.

| # | Owner | Task | Commit |
| - | ----- | ---- | ------ |
| 9.1 | 🟦 | `Deploy.s.sol` end-to-end: deploy all contracts, wire roles, transfer treasury | `feat(deploy): full deploy script` |
| 9.2 | 🟦 | Deploy to Arbitrum Sepolia, verify on Arbiscan, fill addresses in README | `chore(deploy): arbitrum sepolia v0.1` |
| 9.3 | 🟦 | `PostDeployVerify.s.sol` + commit output to `docs/post-deploy-verification.txt` | `chore(deploy): post-deploy verification` |
| 9.4 | 🟦 | Full governance E2E test: propose → vote → queue → execute (timelock parameter change) | `test(governance): full e2e propose-execute` |
| 9.5 | 🟩 | 10 fuzz tests: AMM swap, vault deposit, vault withdraw, governance voting power | `test(fuzz): swap + vault + voting` |
| 9.6 | 🟩 | 5 invariant tests: k never decreases, total supply, treasury accounting, HF≥1 unless liquidatable, vault assets ≥ shares | `test(invariant): protocol invariants` |
| 9.7 | 🟨 | Frontend: swap UI + add liquidity + vault deposit (3 write actions) | `feat(frontend): swap + lp + vault UI` |
| 9.8 | 🟨 | Frontend: governance proposal list reading from subgraph + vote button | `feat(frontend): proposal list from subgraph` |
| 9.9 | 🟨 | Network detection + error handling polish | `feat(frontend): network switch + errors` |
| 9.10 | 🟨 | Deploy subgraph to Graph Studio, link in README | `chore(subgraph): deploy v0.1` |

**End-of-week check:** all contracts on Arb Sepolia, subgraph live, frontend functional, ≥ 65 tests.

---

## Week 10 — "Full submission"

**Milestone:** All deliverables, presentation.

| # | Owner | Task | Commit |
| - | ----- | ---- | ------ |
| 10.1 | 🟩 | Reach ≥ 90 % coverage by adding remaining unit tests for revert paths | `test: bump coverage to 90+` |
| 10.2 | 🟦 | Run Slither, fix every High/Medium, document Lows in audit report | `fix: slither high/medium remediation` |
| 10.3 | 🟦 | Reentrancy case-study reproduction & fix (audit §7.1) | `test(audit): reentrancy PoC + fix` |
| 10.4 | 🟦 | Access-control case-study reproduction & fix (audit §7.2) | `test(audit): access-control PoC + fix` |
| 10.5 | 🟩 | Gas benchmarks: Yul vs Solidity, L1 vs L2 (6 ops) — fill `gas-report.md` | `docs(gas): full gas report` |
| 10.6 | 🟦 | Fill `architecture.md` — 3 sequence diagrams, full storage layouts, all ADRs | `docs(arch): final architecture document` |
| 10.7 | 🟦 | Fill `audit.md` — all findings, governance attack section, oracle attack section, Slither appendix | `docs(audit): final audit report` |
| 10.8 | 🟨 | Frontend polish + screenshots for slide deck | `feat(frontend): final polish` |
| 10.9 | all | Slide deck (PDF), 15 min split into 3 segments of 5 min each | `docs: final presentation deck` |
| 10.10 | all | Dry run the presentation; rehearse Q&A with each member explaining the OTHER members' code | — |

**End-of-week check:** ≥ 80 tests, ≥ 90 % coverage, Slither clean, presentation ready.

---

## How to use this plan

1. **Every PR maps to one row above.** Use the listed commit prefix.
2. **Every PR needs review by one other team member** before merge.
3. **Don't skip ahead** — task N depends on task N-1 in most cases.
4. **If you're blocked**, ask in the team chat _the same day_ — don't sit on it.
5. **Friday standup** (15 min): each person says (a) what they shipped this week, (b) what's next, (c) any blockers.

---

## Q&A preparation (CRITICAL — defence is 40 / 100 points)

Two weeks before the defence, each member must:

1. Read **all** of the other two members' code, line by line.
2. Write down 5 questions they would ask if they were the instructor.
3. Schedule a 60-min "mock Q&A" session where the team grills each member on every part of the codebase.
4. Identify weak spots and book a 1:1 walkthrough with the original author.

> Reminder from the spec: _"the instructor may ask any team member about any part of the codebase. 'That was not my part' is not an acceptable answer"_.
