# Aralys Frontend

React + Vite + Wagmi v2 + Viem. Talks to contracts on Arbitrum Sepolia and reads indexed data from The Graph.

> **OWNERSHIP:** Ayauzhan

## Required pages / sections

Per spec §3.4:

- [ ] **Wallet connect** (MetaMask + WalletConnect)
- [ ] **Dashboard** — read: ARLY balance, voting power, delegate address, vault shares, current pair reserves
- [ ] **Swap** — write: AMM swap (state-changing tx)
- [ ] **Liquidity** — write: addLiquidity (state-changing tx)
- [ ] **Vault** — write: deposit (state-changing tx)
- [ ] **Governance** — list of proposals from **subgraph** (this is the spec-required subgraph read)
   - states: Pending / Active / Succeeded / Defeated / Queued / Executed
   - vote button on Active proposals
- [ ] **Network detector** — if not on Arb Sepolia, prompt to switch
- [ ] **Error boundary** — readable messages: tx rejected, wrong network, insufficient balance

## Stack

- `vite` + `react` 18
- `wagmi` 2.x + `viem` 2.x
- `@rainbow-me/rainbowkit` (handles MetaMask + WalletConnect)
- `urql` for subgraph queries

## Scripts

```bash
pnpm install
pnpm dev       # local dev
pnpm build     # production build
pnpm lint      # eslint + prettier
```

## Environment

```
VITE_CHAIN_ID=421614
VITE_GOVERNOR_ADDRESS=0x...
VITE_AMM_FACTORY_ADDRESS=0x...
VITE_VAULT_ADDRESS=0x...
VITE_LENDING_ADDRESS=0x...
VITE_ARLY_ADDRESS=0x...
VITE_SUBGRAPH_URL=https://api.studio.thegraph.com/query/.../aralys-finance/v0.1.0
```
