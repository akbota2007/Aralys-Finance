# Aralys Finance

**A modular DeFi super-app: AMM + Lending + Tokenized Yield Vault, governed on-chain, deployed on Arbitrum Sepolia.**

> Final project — Blockchain Technologies 2 (BChT2). Team of 3.
> Scenario: **Option A — DeFi Super-App**.

---

## Team & Ownership

| Member       | Domain                                                      | Primary contracts / files |
| ------------ | ----------------------------------------------------------- | ------------------------- |
| **Akbota** | Governance, L2 deployment, DevOps                           | `governance/*`, `script/*`, `.github/workflows/*` |
| **Zaure**    | Core DeFi primitives (AMM, ERC-4626 vault, Yul opt.)        | `core/AMMPair.sol`, `core/AMMFactory.sol`, `core/YieldVault.sol`, `libraries/MathYul.sol` |
| **Ayauzhan** | Tokens, Oracles, Frontend, Subgraph                         | `tokens/*`, `oracles/*`, `frontend/*`, `subgraph/*` |



---

## What it does

Aralys Finance combines three DeFi primitives behind one governance layer:

1. **AMM** — constant-product (x·y=k) DEX with 0.3% fee, written from scratch (not a Uniswap V2 fork).
2. **Yield Vault** — ERC-4626 vault that auto-deposits idle LP tokens to earn protocol fees.
3. **Lending Pool (lite)** — collateralized borrowing against LP shares with health factor and liquidation.
4. **Governance** — `ARLY` (ERC20Votes + ERC20Permit) token governs all parameters via OpenZeppelin Governor + 2-day Timelock.
5. **Oracles** — Chainlink price feeds with staleness checks for collateral pricing.
6. **L2 deployment** — Arbitrum Sepolia, all contracts verified.

---

## Repository layout

```
aralys-finance/
├── contracts/
│   ├── core/          # AMM, Vault, Lending — heart of the protocol
│   ├── tokens/        # ARLY governance token, LP tokens
│   ├── governance/    # Governor, Timelock setup
│   ├── oracles/       # Chainlink wrappers + mock aggregators
│   ├── interfaces/    # External-facing interfaces
│   └── libraries/     # MathYul, SafeCast, etc.
├── script/            # Foundry deploy + verify scripts
├── test/
│   ├── unit/          # ≥50 tests
│   ├── fuzz/          # ≥10 tests
│   ├── invariant/     # ≥5 invariants
│   └── fork/          # ≥3 fork tests
├── frontend/          # React + Wagmi + Viem dApp
├── subgraph/          # The Graph manifest, schema, mappings
├── docs/
│   ├── architecture.md      
│   ├── audit.md             
│   ├── gas-report.md       
│   ├── coverage.md          # forge coverage output
│   └── diagrams/            # C4, sequence diagrams (PNG/SVG)
└── .github/workflows/ # CI: build, test, coverage, slither
```

---

## Quick start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (latest)
- Node.js 20+ and pnpm (for frontend & subgraph)
- [Slither](https://github.com/crytic/slither) (`pip install slither-analyzer`)
- An RPC URL for Arbitrum Sepolia (Alchemy / Infura / public)

### Build & test

```bash
forge install
forge build
forge test -vv
forge coverage --report summary
```

### Deploy to Arbitrum Sepolia

```bash
cp .env.example .env
# fill PRIVATE_KEY, ARBITRUM_SEPOLIA_RPC, ARBISCAN_API_KEY
forge script script/Deploy.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC --broadcast --verify
```

### Frontend

```bash
cd frontend
pnpm install
pnpm dev
```

### Subgraph

```bash
cd subgraph
pnpm install
pnpm codegen && pnpm build
pnpm deploy  # to Graph Studio
```

---

## Deployed addresses (Arbitrum Sepolia)

| Contract            | Address                                      | Verified |
| ------------------- | -------------------------------------------- | -------- |
| ARLY token          | `0x51E523A3De774028C5df2a92a08906963BB232DE` | ✅       |
| Timelock            | `0xbD2B44F698fB47648fB07f43399b24ba665328Bf` | ✅       |
| Governor            | `0x3446D07d6d9c6D80EDcbAE7F0e3D65bDF2473456` | ✅       |
| AMM Factory         | `0x0EbC1580A77519B91564f20815B17f2A309D5b38` | ✅       |
| Yield Vault         | `0x1928CDe07f493cfA502c3325608b6E99fB45eD44` | ✅       |
| Lending Pool        | `0xbBa1F670494dfB5C43DE40a76a5e01b333469145` | ✅       |
| Chainlink Adapter   | `0xB5cDF2e85e1b9bDe031666eA4A2ED42F02082260` | ✅       |

> Subgraph: `https://api.studio.thegraph.com/query/<id>/aralys-finance/v0.1.0`

---

## Documentation

- **[Architecture](docs/architecture.md)** — system design, C4 diagrams, sequence diagrams, ADRs.
- **[Security Audit](docs/audit.md)** — internal audit report, findings, mitigations.
- **[Gas Report](docs/gas-report.md)** — Yul vs Solidity benchmarks, L1 vs L2 cost table.
- **[Coverage Report](docs/coverage.md)** — line coverage per contract.

---

## Tech stack

- **Solidity** 0.8.24 (via_ir enabled for AMM math)
- **Foundry** for build, test, fuzz, invariant
- **OpenZeppelin Contracts** v5 (Upgradeable + Governance)
- **Chainlink** AggregatorV3Interface
- **The Graph** — hosted subgraph
- **React + Vite + Wagmi v2 + Viem** — frontend
- **Slither + Solhint + forge fmt** — linting & static analysis

---

## License

MIT
