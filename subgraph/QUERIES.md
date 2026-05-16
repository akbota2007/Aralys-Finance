# Aralys Subgraph — Documented GraphQL queries

These 5 queries are the documented surface used by the frontend (spec requirement).

## 1. List all pairs with current reserves

```graphql
query AllPairs {
  pairs(first: 100, orderBy: createdAtBlock, orderDirection: desc) {
    id
    token0
    token1
    reserve0
    reserve1
    totalSupply
  }
}
```

## 2. Last 20 swaps on a given pair

```graphql
query RecentSwaps($pair: ID!) {
  swaps(
    where: { pair: $pair }
    first: 20
    orderBy: timestamp
    orderDirection: desc
  ) {
    id
    sender
    to
    amount0In
    amount1In
    amount0Out
    amount1Out
    timestamp
  }
}
```

## 3. Liquidity history for a provider

```graphql
query LiquidityByProvider($provider: Bytes!) {
  liquidityEvents(
    where: { provider: $provider }
    orderBy: timestamp
    orderDirection: desc
  ) {
    type
    pair { id token0 token1 }
    amount0
    amount1
    liquidity
    timestamp
  }
}
```

## 4. Active proposals with live vote tallies

```graphql
query ActiveProposals {
  proposals(where: { state_in: ["Active", "Pending", "Succeeded", "Queued"] }) {
    id
    description
    state
    forVotes
    againstVotes
    abstainVotes
    startBlock
    endBlock
  }
}
```

## 5. Voting history of an address

```graphql
query VotesByAddress($voter: Bytes!) {
  votes(where: { voter: $voter }, orderBy: timestamp, orderDirection: desc) {
    proposal { id description }
    support
    weight
    reason
    timestamp
  }
}
```
