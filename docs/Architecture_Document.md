# Aralys Finance: Architecture, System Design & Technical Specification

**Date:** May 2026  
**Authors:** Aralys Finance Engineering Core  
**Version:** 2.0.0 (Post-Upgrade Audit Alignment)  
**Target Architecture:** Layer 2 (L2) EVM-Compatible Rollup Networks  

---

## 1. System Context Diagram (C4 Level 1)

The system context diagram establishes the boundaries of the Aralys Finance ecosystem, highlighting interactions between external entities, infrastructure nodes, and the core protocol smart contracts.
+-----------------------------------------------------------------------+
|                         ARALYS FINANCE SYSTEM                         |
|                                                                       |
|   +------------------+         REST API         +-----------------+   |
|   |   End User /     | -----------------------> |  The Graph      |   |
|   |   Liquidation Bot| <----------------------- |  Indexing Node  |   |
|   +------------------+     Historical Events    +-----------------+   |
|            |                                             ^            |
|            | Web3 RPC provider                           |            |
|            v                                             | GraphQL /  |
|   +-----------------------------------------------+      | Logs Poll  |
|   |   Frontend dApp Framework                     |      |            |
|   |   (React / Wagmi / Viem)                      |      |            |
|   +-----------------------------------------------+      |            |
|            |                                             |            |
|            | JSON-RPC Transactions                       |            |
|            v                                             |            |
|   +------------------------------------------------------+---------+  |
|   |   Layer 2 EVM Execution Environment (Testnet Engine)          |  |
|   |                                                               |  |
|   |   [ Core Lending Engine ]    <--->    [ UUPS Yield Vault ]    |  |
|   |             |                                                 |  |
|   |             v Data Feeds                                      |  |
|   |   [ Chainlink Oracle Nodes Aggregators Layer ]                |  |
|   +---------------------------------------------------------------+  |
+-----------------------------------------------------------------------+
### 1.1 Structural Actor Descriptions
* **End User / Liquidation Bot:** Regular market participants who execute actions such as deposits, borrowing, and swaps. Automated arbitrageurs or liquidation bots query the chain state to trigger risk-clearance operations (`liquidate()`).
* **Frontend dApp Framework:** A web application compiled using React, Wagmi, and Viem. It parses raw client requests into standard Ethereum transaction fields and signs payloads via injected provider interfaces (e.g., MetaMask, WalletConnect).
* **The Graph Indexing Node:** A critical off-chain data assembly infrastructure. It monitors deployed contract addresses for operational event logs (`Deposit`, `Borrow`, `Liquidate`), processes the data via custom mappings, and exposes a high-performance GraphQL interface to power the frontend UI.
* **Chainlink Oracle Layer:** Independent node operators that publish tamper-resistant financial metrics directly to L2 data registries, protecting the money market from price manipulation vectors.

---

## 2. Container & Component Diagram (Proxy & Contract Relationships)

This component overview outlines how contract inheritance, ownership proxies, token standards, and algorithmic control engines work together under the strict security model of Aralys Finance.
+-------------------------------------------------------+
   |             Governance & Governance Multi-Sig         |
   |                   [ AralysGovernor ]                  |
   +-------------------------------------------------------+
                               |
                               | Proposes & Votes Action
                               v
   +-------------------------------------------------------+
   |                Administrative Lock                    |
   |                   [ AralysTimelock ]                  |
   +-------------------------------------------------------+
                               |
             +-----------------+-----------------+
             | Controls & Rules                  | Upgrades Implementation
             v                                   v
+----------------------------------+       +----------------------------------+
|      [ LendingPool.sol ]         |       |    [ ERC1967Proxy (Vault) ]      |
|                                  |       |    Storage Identity Context      |
|  - Role Management (Access)      |       +----------------------------------+
|  - Health Calculations (Math)    |                         |
|  - Risk Bounds Configurations    |                         | DELEGATECALL
+----------------------------------+                         v
|                         +----------------------------------+
| Queries Rates           |    [ YieldVaultV2.sol ]          |
v                         |    Active Logic Implementation   |
+----------------------------------+       +----------------------------------+
|      [ OracleAdapter.sol ]       |
|   Chainlink Consumer Interfaces  |
+----------------------------------+


### 2.1 Component Specifications
* **AralysTimelock:** Functions as the primary owner of both the `LendingPool` and the UUPS `ERC1967Proxy`. It enforces a minimum execution delay of 2 days on all configuration updates, preventing unilateral admin exploits.
* **LendingPool:** Coordinates deposit accounting, calculates interest rates dynamically, checks position liquidation margins, and controls lending rules via an un-upgradeable, static contract setup.
* **ERC1967Proxy:** A lightweight proxy instance that maintains the state variables and asset balances of the yield vault. It routes runtime execution commands to the current logic implementation contract using `DELEGATECALL`.
* **YieldVaultV2:** Holds the execution logic for interest distribution, fee handling, and asset rebalancing. It can be securely replaced through authorized governance upgrade proposals.

---

## 3. Sequence Diagrams for Critical User Flows

### 3.1 Flow A: Core Asset Lending (Deposit-Borrow Loop)
This flow tracks the step-by-step process of a user depositing capital to establish a collateral balance, followed by an immediate debt allocation request.

User               LendingPool         OracleAdapter         CollateralERC20
|                      |                    |                      |
|--- deposit(10e18) -->|                    |                      |
|                      |--- safeTransferFrom(user, pool) --------->|
|                      |                    |                      |
|                      |<-- Transfer OK ---------------------------|
|                      |                    |                      |
|                      |                    |                      |
|--- borrow(4e18) ---->|                    |                      |
|                      |--- getPrice(asset) ------->|              |
|                      |                    |       |              |
|                      |<-- returns $3000 ----------|              |
|                      |                    |                      |
|                      |--[Verify HF > 1.0]-|                      |
|                      |                    |                      |
|                      |---------------- safeTransfer(pool, user) ------------> DebtERC20
|                      |                                                            |
|                      |<------------------------- Transfer OK ---------------------|
|<-- Execution OK -----|                                                            |


### 3.2 Flow B: The Governance Lifecycle (Propose-Vote-Execute)
This sequence traces the technical lifecycle of an upgrade or system parameter alteration proposal from initialization through implementation.

Proposer             AralysGovernor         AralysTimelock         TargetContract
|                       |                       |                      |
|--- propose(target) -->|                       |                      |
|    [Snapshot Taken]   |                       |                      |
|                       |                       |                      |
|==== [VOTING PERIOD ELAPSED: Proposal Passes] ========================|
|                       |                       |                      |
|--- queue() ---------->|                       |                      |
|                       |--- queueTransaction ->|                      |
|                       |                    [Starts Timelock Clock]   |
|                       |                       |                      |
|==== [TIMELOCK EXECUTION DELAY ELAPSED: 2 Days] ======================|
|                       |                       |                      |
|--- execute() -------->|                       |                      |
|                       |--- executeTransaction>|                      |
|                       |                       |--- upgrade/call ---->|


### 3.3 Flow C: Decentralized Liquidation Clearance
This process coordinates bad debt liquidation when market movements push an account's health factor below safety thresholds.

Liquidator            LendingPool          OracleAdapter          Collateral/Debt
|                      |                     |                       |
|--- liquidate(alice)->|                     |                       |
|                      |--- getPrice() ----->|                       |
|                      |<-- returns $500 ----|                       |
|                      |                     |                       |
|                      |--[HF check: 0.405]--|                       |
|                      |  (Below Threshold)  |                       |
|                      |                     |                       |
|                      |--- burnDebt(liquidator) --------------->|   |
|                      |--- transferBonusCollateral(liquidator) ---->|
|<-- Success Event ----|                                             |


---

## 4. Data Model & Upgradeable Storage Layout

To prevent storage collisions during proxy upgrades, upgradeable contracts use strict variable ordering. The following charts demonstrate how memory alignment is preserved from `YieldVault` (V1) to `YieldVaultV2` (V2).

### 4.1 Storage Layout Mapping

#### YieldVault (V1 Framework)
| Slot Index | Variable Identifier | Data Type | Byte Length | Operational Context |
| :--- | :--- | :--- | :--- | :--- |
| `0` | `_initialized` / `_initializing` | `uint8` / `bool` | 1 / 1 byte | OpenZeppelin Initializer State |
| `1` | `_owner` | `address` | 20 bytes | Access Control Owner Pointer |
| `2` | `_asset` | `address` | 20 bytes | Target Depositable Asset Address |
| `3` | `_totalShares` | `uint256` | 32 bytes | Tracking metric for issued shares |

#### YieldVaultV2 (V2 Framework)
| Slot Index | Variable Identifier | Data Type | Byte Length | Operational Context |
| :--- | :--- | :--- | :--- | :--- |
| `0` | `_initialized` / `_initializing` | `uint8` / `bool` | 1 / 1 byte | Inherited State Variable |
| `1` | `_owner` | `address` | 20 bytes | Inherited State Variable |
| `2` | `_asset` | `address` | 20 bytes | Inherited State Variable |
| `3` | `_totalShares` | `uint256` | 32 bytes | Inherited State Variable |
| **`4`** | **`version`** | **`string`** | **32 bytes** | **Newly added upgrade variable slot** |

### 4.2 Storage Collision Proof
Because Solidity allocates storage layout slots sequentially based on contract inheritance trees, appending the `version` variable *after* all inherited fields guarantees that slots `0` through `3` remain unaltered. 

Our integration suite confirms this layout stability via `test_V2_Owner_Preserved_After_Upgrade`, which verifies that the `_owner` variable in slot `1` remains unchanged after the proxy points to the V2 implementation.

---

## 5. Trust Assumptions & Administrative Boundaries

Aralys Finance operates under a tiered access-control matrix, separating immediate day-to-day operational adjustments from critical system changes.

   [ High-Level Privileges ]                   [ Day-to-Day Operations ]
         AralysTimelock                             FeedManagerRole
               |                                           |
 +-------------+-------------+                             +-------+
 |                           |                                     |
 v                           v                                     v
Upgrades Code Logic       Adjusts LTV Parameters              Updates Feed Mappings
(YieldVault -> V2)      (LendingPool Variables)              (OracleAdapter Config)


### 5.1 Protocol Privilege Matrix
1. **AralysTimelock (System Owner):** Holds top-level administrative privileges. It is the only entity authorized to trigger contract upgrades via `upgradeToAndCall()` or adjust core lending parameters like risk margins and loan-to-value (LTV) limits.
2. **FeedManagerRole:** An isolated, low-privilege role assigned to automated maintenance scripts or dev multi-sigs. It allows the holder to update or recalibrate feed endpoints within `OracleAdapter.sol` if an underlying oracle asset degrades, but grants no authority over user deposits or logic modifications.

### 5.2 Compromise Recovery & Safeguards
* **Multisig Compromise:** If an administrative credential is leaked or compromised, the mandatory **2-day timelock delay** ensures that community trackers and liquidation keepers have a 48-hour window to pause active user operations or exit the protocol safely before any malicious proposal can execute.
* **Implementation Safety:** The `_disableInitializers()` guard in the implementation contract's constructor ensures that even if the logic layer is compromised, the live user state managed by the proxy remains insulated.

---

## 6. Architecture Decision Records Log (ADR)

### 6.1 ADR 001: Integration of UUPS Upgrade Pattern over Transparent Alternatives
* **Context:** The protocol requires an upgradeability pattern to implement yield strategies over time without forcing users to migrate to new contract deployments.
* **Options Considered:** 1. *Transparent Proxy Pattern:* High safety, but incurs significant gas overhead due to identity checks on every transaction.
  2. *UUPS Proxy Pattern (ERC-1967):* Places the upgrade logic within the implementation layer, minimizing proxy gas overhead.
* **Decision:** Selected the **UUPS Proxy Pattern**.
* **Consequences:** Users benefit from lower gas fees across all day-to-day transaction pathways. However, this pattern shifts responsibility to the development team to ensure that all future logic upgrades continue to implement the necessary UUPS upgrade interfaces to prevent permanent freeze risks.

### 6.2 ADR 002: Reentrancy Interception Model Selection
* **Context:** The money market engine requires absolute isolation from multi-invocation call vectors during token transfer operations.
* **Options Considered:**
  1. *Pure Checks-Effects-Interactions (CEI) Compliance:* Costs zero additional gas but relies entirely on manual development diligence during refactoring.
  2. *ReentrancyGuard OpenZeppelin Inheritance:* Incurs a minor gas premium per transaction to set and clear invocation flags in storage slots.
* **Decision:** Implemented a **Hybrid Model** enforcing strict CEI code organization alongside active `nonReentrant` modifiers on all critical deposit/withdrawal methods.
* **Consequences:** Provides a multi-layered defense mechanism against reentrancy attacks, providing absolute protection even when handling complex or unconventional token mechanics.