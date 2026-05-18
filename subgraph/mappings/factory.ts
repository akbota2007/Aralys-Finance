import { PairCreated } from "../generated/AMMFactory/AMMFactory"
import { AMMPair } from "../generated/templates"
import { Pair } from "../generated/schema"
import { BigInt } from "@graphprotocol/graph-ts"

export function handlePairCreated(event: PairCreated): void {
  let pair = new Pair(event.params.pair.toHex())
  pair.token0 = event.params.token0
  pair.token1 = event.params.token1
  pair.reserve0 = BigInt.fromI32(0)
  pair.reserve1 = BigInt.fromI32(0)
  pair.totalSupply = BigInt.fromI32(0)
  pair.createdAtBlock = event.block.number
  pair.save()
  AMMPair.create(event.params.pair)
}
