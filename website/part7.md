---
title: "Optimization and Minimizing Costs"
layout: page
---

Optimization and Minimizing Costs
---------------------------------

So throughout this series, I've mentioned transactions costs, but didn't go into detail. In blockchain systems, users pay miners small fees in the blockchain's native token to include their transaction in the blockchain, whether that be Bitcoin, Ether, or whatnot.

In Ethereum, each instruction in the Turing complete scripting language has an associated cost, along with additional costs for writes to blockchain memory. These costs are counted in _gas_. A user specifies the price per gas unit in Ether that they are willing to pay, and this layer of indirection creates a market for computation on the blockchain.

Writes to the blockchain dominate transaction costs; it takes 3 gas to perform an addition but 20,000 gas to allocate a single 256-bit integer to the blockchain. Further modifications to a previously allocated 256-bit integer cost an additional 5,000 gas. Since we're writing all information about an item to the blockchain along with meta-data about a user's backpack state, how much do transactions in this system actually cost?

For the rest of this article, we'll use a few simplifying assumptions. Ether is currently trading at $0.87 per 1 Ether, but we'll round this to a dollar. We'll then show the cost at different gas prices. For example: the code that makes up the Blockchain Backpack proof of concept is fairly large, and the one time deployment cost would be 2864931 gas. We'd display that like this:

| Gas       | @ 10 szabo | @ 1 szabo | @ 0.5 szabos |  @ 0.05 szabos |
|-----------|------------|-----------|--------------|---------------:|
| 2,864,931 |     $28.64 |     $2.86 |        $1.43 |          $0.14 |

Currently, the gas price is 0.05 szabos per unit of gas, however the Ethereum network doesn't see much traffic since it launched only a few months ago. To the best of my knowledge, there are no good estimations at what the gas price will be a year from now, so I'll give multiple estimates at orders of magnitude above the current price.

### The Naive Costs

In [Part 1][p1], we gave the following piece of example code which would give the Southie Shinobi with paint and Halloween Spells applied:

```cpp
// As a user who has the GrantItems and AddAttributesToItem permissions.
id = bp.ImportItem(30395, 6, 8, 69, xxxxxx, recipient_address);
bp.SetIntAttribute(id, 142, 1258303520);
bp.SetIntAttribute(id, 261, 1242936884);
bp.SetIntAttribute(id, 1004, 1077936128);
bp.FinalizeItem(id);
```

This snippet above costs:

| Gas     | @ 10 szabo | @ 1 szabo | @ 0.5 szabos |  @ 0.05 szabos |
|---------|------------|-----------|--------------|---------------:|
| 387,194 |      $3.78 |     $0.37 |        $0.18 |         $0.018 |

At first, a cent or two at current prices sounds good. Even fifteen to twenty cents sounds reasonable. But when we get up to higher orders of magnitude, it probably doesn't make sense for the vast majority of items.

And remember that items have to be imported at scale. Millions of items exist in the Valve item economy and need to be moved to the blockchain in bulk. Even improving the best case by less than order of magnitude would save everyone quite a bit of money.

### Removing Random Access to Attributes

Software Engineering is about trade-offs.

When a contract writes to its memory, that data is accessible to the contract in future transactions. In Part 2, we showed off a contract that read item schema data while executing the Paint contract. However, if we don't need the contract to be able to read back data while executing on the blockchain, there's a much cheaper option: the event log.

In Ethereum, contracts can also create "events" while executing which can be observed from outside...but which can't be read back by the contract. Events are an order of magnitude cheaper than writing to the contract memory.

(Why didn't the proof of concept originally use events? They didn't exist as a language feature while I was doing the early planning for this project.)

So let's modify `Backpack.ImportItem` so that all non-essential facts about an item like `quality` or `level` are written as an event when an item is created and replace `Backpack.SetIntAttribute` so that it wrote attribute data instead of maintaining its own list of attributes of an item on the blockchain. We'll still write all ownership information to determine access control. 

| Gas     | @ 10 szabo | @ 1 szabo | @ 0.5 szabos |  @ 0.05 szabos |
|---------|------------|-----------|--------------|---------------:|
| 235,399 |      $2.35 |     $0.23 |        $0.11 |         $0.011 |

OK, so that's a little better. We improved costs by a little more than a third. What do we give up?

Well, we can't look at the item state directly--now only ownership and a few pieces of metadata are stored in chain memory, while the rest is stored as event data with the transaction. This is all still cryptographically secure and authenticated but to recreate the state of the world, you would have to perform an O(n) walk across all transactions to this contract.

The trade off means that any server that wanted to query the state of the world wouldn't be able to do O(1) lookups directly onto blockchain data; they would process all transactions themselves to reconstruct item's state, or rely on another server to do so. This is still more distributed than the current system.

### Redo ID Mappings

Now that we've minimized the amount of data written per item, let's optimize the internal data structures.

Previously, the amount of data per item could be fairly high: the amount of storage grew linearly with the number of attributes. Therefore, to make the cost of giving an item from one account to another constant, I put in a mapping table from an items public id to an internal id. Modifying an item or giving it away just removed the old public id and replaced it with the new one.

This may have been a premature optimization, so now that the representation on chain is two 256-bit integers per item, let's remove the ID mapping.

| Gas     | @ 10 szabo | @ 1 szabo | @ 0.5 szabos | @ 0.05 szabos |
|---------|------------|-----------|--------------|--------------:|
| 218,701 |      $2.18 |     $0.21 |        $0.10 |         $0.01 |

This gain is relatively minor over the previous one, but it also simplifies the code by quite a bit: there's no more internal conversions from public ids to internal ones.

### Minimizing Per-Transaction Costs

Every transaction has a base cost of 21,000 gas. If we have a minimum of five transactions to create an item, the absolute theoretical minimum is a gas cost of 105,000 gas. This is roughly half of the current gas cost to deploy our test item.

If we were to deploy the super simple contract:

```cpp
contract Deployer {
  function ImportItem(uint32 defindex,
                      uint16 quality,
                      uint16 origin,
                      uint16 level,
                      uint64 original_id,
                      address recipient,
                      uint32[] keys,
                      uint64[] values) returns (uint64 id) {
    if (!bp.HasPermissionInt(msg.sender, 3))
      return 0;

    id = bp.ImportItem(defindex, quality, origin, level, original_id,
                       recipient);
    bp.SetIntAttributes(id, keys, values);
    bp.FinalizeItem(id);
  }

  // Constructor, etc. elided.
}
```

We give this contract permission to grant items and add attributes to them. I suspect that creating a central contract with a few primitives and then putting most of the routine work into helper contracts to reduce the cost of common cases would be be a common pattern in a deployed system. For example, we could write a deployer contract that would give an item with the same properties to a list of addresses in preparation for some sort of large giveaway.

We now have a helper contract that lets us deploy an item in one transaction:

| Gas     | @ 10 szabo | @ 1 szabo | @ 0.5 szabos |  @ 0.05 szabos |
|---------|------------|-----------|--------------|---------------:|
| 134,067 |      $1.34 |     $0.13 |        $0.06 |         $0.006 |

As we can see, deploying the above contract is cost effective. It would take a one time cost of 334,613 gas, and it will pay for itself in three items.

### Removing Item Lookup by Player

Backpack space is limited. In TF2, paid players start with 300 item slots, and must buy or trade for [Backpack Expanders][expander] to be able to own more items.

[expander]: https://wiki.teamfortress.com/wiki/Expander

The current proof of concept captures this requirement. However, not only did it keep track of the number of items a player owned, but it also kept track of which items, allowing contracts to go lookup what items are owned by an arbitrary keypair. This functionality was never used, removing it yields the following minor improvement:

| Gas     | @ 10 szabo | @ 1 szabo | @ 0.5 szabos |  @ 0.05 szabos |
|---------|------------|-----------|--------------|---------------:|
| 113,644 |      $1.13 |     $0.11 |        $0.05 |         $0.005 |

We could go further and remove the notion of limited backpack space from this system to remove one more write, but that would make this proof of concept diverge from the Valve item system as it exists today.
