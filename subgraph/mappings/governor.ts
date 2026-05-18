import { ProposalCreated, VoteCast, ProposalQueued, ProposalExecuted } from "../generated/AralysGovernor/AralysGovernor"
import { Proposal, Vote } from "../generated/schema"
import { BigInt } from "@graphprotocol/graph-ts"

export function handleProposalCreated(event: ProposalCreated): void {
  let proposal = new Proposal(event.params.proposalId.toString())
  proposal.proposer = event.params.proposer
  proposal.description = event.params.description
  proposal.state = "Pending"
  proposal.forVotes = BigInt.fromI32(0)
  proposal.againstVotes = BigInt.fromI32(0)
  proposal.abstainVotes = BigInt.fromI32(0)
  proposal.startBlock = event.params.voteStart
  proposal.endBlock = event.params.voteEnd
  proposal.save()
}

export function handleVoteCast(event: VoteCast): void {
  let proposal = Proposal.load(event.params.proposalId.toString())
  if (!proposal) return
  if (event.params.support == 1) {
    proposal.forVotes = proposal.forVotes.plus(event.params.weight)
  } else if (event.params.support == 0) {
    proposal.againstVotes = proposal.againstVotes.plus(event.params.weight)
  } else {
    proposal.abstainVotes = proposal.abstainVotes.plus(event.params.weight)
  }
  proposal.save()
  let vote = new Vote(event.transaction.hash.toHex() + "-" + event.logIndex.toString())
  vote.proposal = proposal.id
  vote.voter = event.params.voter
  vote.support = event.params.support
  vote.weight = event.params.weight
  vote.reason = event.params.reason
  vote.timestamp = event.block.timestamp
  vote.save()
}

export function handleProposalQueued(event: ProposalQueued): void {
  let proposal = Proposal.load(event.params.proposalId.toString())
  if (!proposal) return
  proposal.state = "Queued"
  proposal.save()
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let proposal = Proposal.load(event.params.proposalId.toString())
  if (!proposal) return
  proposal.state = "Executed"
  proposal.save()
}
