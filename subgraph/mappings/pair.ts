import { Swap, Mint, Burn, Sync } from "../generated/templates/AMMPair/AMMPair"
import { Pair, Swap as SwapEntity, LiquidityEvent } from "../generated/schema"
import { BigInt } from "@graphprotocol/graph-ts"

export function handleSwap(event: Swap): void {
  let pair = Pair.load(event.address.toHex())
  if (!pair) return
  let swap = new SwapEntity(event.transaction.hash.toHex() + "-" + event.logIndex.toString())
  swap.pair = pair.id
  swap.sender = event.params.sender
  swap.to = event.params.to
  swap.amount0In = event.params.amount0In
  swap.amount1In = event.params.amount1In
  swap.amount0Out = event.params.amount0Out
  swap.amount1Out = event.params.amount1Out
  swap.blockNumber = event.block.number
  swap.timestamp = event.block.timestamp
  swap.save()
}

export function handleMint(event: Mint): void {
  let pair = Pair.load(event.address.toHex())
  if (!pair) return
  let lp = new LiquidityEvent(event.transaction.hash.toHex() + "-" + event.logIndex.toString())
  lp.pair = pair.id
  lp.provider = event.params.sender
  lp.type = "MINT"
  lp.amount0 = event.params.amount0
  lp.amount1 = event.params.amount1
  lp.liquidity = BigInt.fromI32(0)
  lp.blockNumber = event.block.number
  lp.timestamp = event.block.timestamp
  lp.save()
}

export function handleBurn(event: Burn): void {
  let pair = Pair.load(event.address.toHex())
  if (!pair) return
  let lp = new LiquidityEvent(event.transaction.hash.toHex() + "-" + event.logIndex.toString())
  lp.pair = pair.id
  lp.provider = event.params.sender
  lp.type = "BURN"
  lp.amount0 = event.params.amount0
  lp.amount1 = event.params.amount1
  lp.liquidity = BigInt.fromI32(0)
  lp.blockNumber = event.block.number
  lp.timestamp = event.block.timestamp
  lp.save()
}

export function handleSync(event: Sync): void {
  let pair = Pair.load(event.address.toHex())
  if (!pair) return
  pair.reserve0 = event.params.reserve0
  pair.reserve1 = event.params.reserve1
  pair.save()
}
