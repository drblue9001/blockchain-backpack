---
title: "Optimization and Minimizing Costs"
layout: page
prev-page:
    title: "Crates"
    url: part6.html
---

Optimization and Minimizing Costs
---------------------------------

I've mentioned transaction costs, and now it's time to look at them in more detail. In blockchain systems, users pay small fees in the blockchain's native token (Bitcoin, Ether, etc.) to the miners who then include the user's transaction in the blockchain.

In Ethereum, each instruction in the Turing complete scripting language has an associated cost when executed, along with additional costs for writes to blockchain memory. These costs are counted in _gas_. A user specifies the price per gas unit in Ether that they are willing to pay, and this layer of indirection creates a market for computation on the blockchain.

Writes to the blockchain dominate transaction costs; it takes 3 gas to perform an addition but 20,000 gas to allocate a single 256-bit integer to the blockchain. Further modifications to a previously allocated 256-bit integer cost an additional 5,000 gas. Since we're writing all information about an item to the blockchain along with meta-data about a user's backpack state, how much do transactions in this system actually cost?

For this article, we'll use a few simplifying assumptions. Ether is currently trading at $0.95 per 1 Ether, but we'll round this to a dollar. We'll then show the cost of certain actions at different gas prices. For example: the code that makes up the Blockchain Backpack proof of concept is fairly large, and the one time deployment cost would be 2,864,931 gas. We'll display that like this:

|                   | Gas       | 10x Price | Current Price |  1/10x Price |
|-------------------|-----------|-----------|---------------|-------------:|
| Backpack Contract | 2,864,931 |     $1.43 |         $0.14 |        $0.01 |

Currently, the gas price is 0.00000005 ether per unit of gas, so deploying the contract would currently cost $0.14. The projections are that the cost of computation will come down by an order of magnitude as scalabilty improvements roll out on the network, but for comparison, we'll also list the cost if the price goes up by an order of magnitude.

### The Naive Costs

In [Part 1][p1], we gave the following piece of example code which would give a player the Southie Shinobi with paint and Halloween Spells applied:

```cpp
// As a user who has the GrantItems and AddAttributesToItem permissions.
id = bp.ImportItem(30395, 6, 8, 69, xxxxxx, recipient_address);
bp.SetIntAttribute(id, 142, 1258303520);
bp.SetIntAttribute(id, 261, 1242936884);
bp.SetIntAttribute(id, 1004, 1077936128);
bp.FinalizeItem(id);
```

Actually running this against a test harness gives the following gas usage:

|                 | Gas     |  10x Price | Current Price |  1/10x Price |
|-----------------|---------|------------|---------------|-------------:|
| Southie Shinobi | 387,194 |      $0.18 |        $0.018 |       $0.001 |

At first, a cent or two at current prices sounds good. Even fifteen to twenty cents sounds reasonable. But remember that items have to be imported at scale. Hundreds of millions of items exist in the Valve item economy and need to be moved to the blockchain in bulk. Any improvement would save everyone quite a bit of money.

For the rest of this article, we'll optimize the proof of concept. To not disrupt the previous articles, all work described here is done on the `optimize` branch in the git repository.

### Removing Random Access to Attributes

Software Engineering is about trade-offs.

When a contract writes to its memory, that data is accessible to the contract in future transactions. In [Part 2][p2], we showed off a contract that read item schema data while executing the Paint contract. However, if we don't need the contract to be able to read back data while executing on the blockchain, there's a much cheaper option: the event log.

In Ethereum, contracts can also create "events" while executing which can be observed from outside...but which can't be read back by the contract. Events are an order of magnitude cheaper than writing to the contract memory.

(Why didn't the proof of concept originally use events? They didn't exist as a language feature while I was doing the early planning for this project.)

So let's modify `Backpack.ImportItem` and `Backpack.SetIntAttribute`. Before, they wrote all their data directly to contract memory. Afterwards, they'll still write ownership information to contract memory for access control purposes, but they'll write non-essential facts about an item like `quality` or `level`, along with attribute data to the event log.

|                 | Gas     |  10x Price | Current Price |  1/10x Price |
|-----------------|---------|------------|---------------|-------------:|
| Southie Shinobi | 235,399 |      $0.11 |        $0.011 |       $0.001 |

That's a little better. We improved costs by a little more than a third. What do we give up?

We can't read back attribute data directly inside of our contracts--now only ownership and a few pieces of metadata are stored in contract accessible memory, while the rest is stored as event data with the transaction. From outside, the ownership data is always accessible from the current most recent block, but the data about the item is stored in the specific block where the item was created.

The trade off means that any server that wanted to query the state of the world wouldn't be able to do O(1) lookups directly onto the current contract state to find what an item is. They would have to know or be told about one or more specific blocks that have the item definition in them, either by processing all blocks themselves or by relying on another server to do so. This is still more distributed than the current system: clients could safely hand the blocks with their items in them to game servers and anyone could run indexing servers as you don't need to trust them since they would just be handing out cryptographic proofs.

But it is still a trade-off.

### Redo ID Mappings

Now that we've minimized the amount of data written per item, let's optimize the internal data structures.

Previously, the amount of data per item could be fairly high: the amount of storage grew linearly with the number of attributes. Therefore, to make the cost of transferring an item between accounts constant, I put in a mapping table from an items public id to an internal id. Modifying an item or giving it away just removed the old public id and replaced it with the new one.

This may have been a premature optimization, so now that the representation on chain is two 256-bit integers per item, let's remove the ID mapping.

|                 | Gas     | 10x Price | Current Price |  1/10x Price |
|-----------------|---------|-----------|---------------|-------------:|
| Southie Shinobi | 218,701 |     $0.10 |         $0.01 |       $0.001 |

This gain is relatively minor over the previous one, but it also simplifies the code by quite a bit: there's no more internal conversions from public ids to internal ones.

### Minimizing Per-Transaction Costs

Every transaction has a base cost of 21,000 gas. If we have a minimum of five transactions to create an item, the absolute theoretical minimum is a gas cost of 105,000 gas. This is roughly half of the current gas cost to deploy our test item.

Let's deploy a helper contract:

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

|                 | Gas     |  10x Price | Current Price |  1/10x Price |
|-----------------|---------|------------|---------------|-------------:|
| Deployer        | 334,613 |      $0.16 |        $0.016 |      $0.0016 |
| Southie Shinobi | 134,067 |      $0.06 |        $0.006 |      $0.0006 |

Deploying the helper contract is a one time cost of 334,613 gas, but this reduces the per item cost from a cent to a sixth of a cent. The Deployer contract will pay for itself in four items.

### Removing Item Lookup by Player

Backpack space is limited. In TF2, paid players start with 300 item slots, and must buy or trade for [Backpack Expanders][expander] to be able to own more items.

[expander]: https://wiki.teamfortress.com/wiki/Expander

The current proof of concept captures this requirement. However, not only did it keep track of the number of items a player owned, but it also kept track of which items, allowing contracts to go lookup what items are owned by an arbitrary keypair. This functionality was never used outside of tests, removing it yields the following minor improvement:

|                 | Gas     | 10x Price | Current Price |  1/10x Price |
|-----------------|---------|-----------|---------------|-------------:|
| Southie Shinobi | 113,644 |     $0.05 |        $0.005 |      $0.0005 |

We could go further and remove the notion of limited backpack space from this system to remove one more write, but that would make this proof of concept diverge from the Valve item system as it exists today.

### Current Performance Report

Writing a Southie Shinobi to the blockchain is now twenty eight percent of the original cost!

Now that we've optimized this thing, let's check how much it would take to load [my current backpack][bptf] onto chain. I currently have 280 items[^1], most of which have a way above average number of attributes, as I like painting and putting killstreak kits on items.

[bptf]: http://backpack.tf/profiles/76561197983511231?time=1449907200

For testing purposes, I've prepared a `load_backpack.py` script which takes two files: `raw_tf2_bp.json`, a JSON representation of a backpack taken from Valve's Steam API, and `tf2_schema.json`, a copy of the current TF2 Item Schema. The script will deploy all necessary contracts to a testing chain, write the item schemas for items that we're going to write, and then write all item data for all the items in my backpack, including string data. (To make this a semi-realistic exercise, I added string attribute setters which is easier now that we're using events.)

|                   | Gas        |  10x Price | Current Price | 1/10x Price |
|-------------------|------------|------------|---------------|------------:|
| Backpack Contract |  2,042,619 |      $1.02 |         $0.10 |       $0.01 |
| Deployer Contract |    931,607 |      $0.46 |         $0.04 |      $0.004 |
| Schema Deployment |  6,518,253 |      $3.25 |         $0.32 |       $0.03 |
| 280 Items         | 32,523,417 |     $16.26 |         $1.62 |       $0.16 |

The first two entries above are contract deployment--they are a one time fixed cost. The parts of the schema that we write to the blockchain change so rarely that schema information might as well be treated as a fixed cost. Above, we can see the fixed costs, which would probably be paid by Valve, are extremely reasonable.

$1.62 is a bargain to secure my backpack. Even if the price of computation were to rise by an order of magnitude from its current price, I would still pay $16.26 to cryptographically secure my backpack in a heartbeat.

[^1]: Technically, since starting the project, I've acquired two items which can't be currently represented. [Killstreak Kit Fabricators][fab] are the only item I've seen that use a recursive attributes.

[fab]: https://wiki.teamfortress.com/wiki/Killstreak_Kit_Fabricator
[p1]: part1.html
[p2]: part2.html
