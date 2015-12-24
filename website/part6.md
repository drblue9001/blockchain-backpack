---
title: "Crates and the Quality of Randomness"
layout: page
prev-page:
    title: "Statistics"
    url: part5.html
next-page:
    title: "Cost"
    url: part7.html
---

Crates and the Quality of Randomness
------------------------------------

Most of the money made in the Valve item ecosystem comes from crates. Crates are items that, when opened with a key, give a random item from a loot table. Crates are random drops in-game, but keys are purchasable for $2.50. However, there's a real variance in the value of the objects that come out of crates. Of the nine items in [Crate Series #1][], two of the items are worth five dollars, one of them is worth one dollar, and the other six are worth a cent.

[Crate #1]: https://wiki.teamfortress.com/wiki/Mann_Co._Supply_Crate/Retired_series#Series_.231

We need a way to get _unpredictable_ psuedorandom numbers out of this system so users can't manipulate it to always get the high value items.

### Low Quality Randomness

Let's start with low quality randomness. In a deterministic system like Ethereum, how do we get some entropy at all? There's one point in the `Backpack.CreateNewItem()` where it may need a piece of randomness to generate the item's level. Here's the excerpt:

```cpp
uint16 level = schema.min_level;
if (schema.min_level != schema.max_level) {
  uint256 range = schema.max_level - schema.min_level + 1;
  level += uint16(uint256(block.blockhash(block.number - 1)) % range);
}
```

Programmers will immediately recognize that somehow `block.blockhash(block.number - 1)` is analogous to `rand()` in C.

Up to this point, I've tried to not talk about how blockchains work. Every block in a blockchain has a number. Block 2 comes after Block 1. Block 3 comes after Block 2. Miners on the network are competing to create the next block--if the last block that everyone knows about is Block 3, everyone is now competing to generate Block 4. `block.number` refers to the number of the block that this transaction is a part of.

Every block also has a hash of the transactions it contains. Ethereum lets you access the last 255 block hashes from within your program. For example, if everyone in the network is working to generate Block 4, you can access the hash of Block 3 and earlier. (You can't access the hash of Block 4 as it hasn't been generated yet.) So we can use the hash of the previous block as a piece of entropy.

We can now describe the attack against this low quality RNG: the user can time when they submit their transaction. If an attacker wants an item with a specific level, they could prepare a transaction, and then wait until a blockhash exists that would give them that item number.

For something like [level numbers][], this probably doesn't matter. For something like crates with loot tables, it does.

[level numbers]: https://wiki.teamfortress.com/wiki/Level

### Better Living Through Precommitment

We can build from this low quality RNG and make a high quality RNG by adding time. An adversary can subvert the previous RNG by timing when they submit their transaction to the system. We can prevent this by precommitting to using a blockhash in the future:

```cpp
contract Crate {                      // Partial
  // Calling the crating contract through the UseItem interface will destroy
  // the key and the crate, and put a precommitment to roll two blocks into the
  // future.
  function MutatingExtensionFunction(uint64[] item_ids)
      external returns (bytes32 message) {
    if (msg.sender != address(backpack))
      return "Invalid caller";

    // Verify that we were given a crate and key.
    if (item_ids.length != 2)
      return "Wrong number of arguments";
    if ((backpack.GetItemDefindex(item_ids[0]) != 5022) ||
        (backpack.GetItemDefindex(item_ids[1]) != 5021))
      return "Incorrect items passed";

    uint blockheight = block.number + 2;
    uint[] precommitments = precommitments_per_block_number[blockheight];

    uint roll_id = open_rolls.length++;
    RollID r = open_rolls[roll_id];
    r.offset = precommitments.length;
    r.blockheight = blockheight;
    r.user = backpack.GetItemOwner(item_ids[0]);

    // Add to the list of precommitments.
    uint i = precommitments.length++;
    precommitments[i] = roll_id;

    backpack.DeleteItem(item_ids[0]);
    backpack.DeleteItem(item_ids[1]);

    return "OK";
  }
}
```

In this contract, calling it through the normal `backpack.UseItem([crate_id, key_id])` system doesn't actually grant the user their uncrated item. Rather, it records a precommitment that in two blocks time, that they can come back and use the two previous block hashes and a per-block monotonically increasing index as a seed, and commits them to this by deleting their crate and key.

```cpp
contract Crate {                      // Continued
  function GetRandom(uint blockheight, uint offset)
      internal returns (uint random) {
    return uint(sha256(block.blockhash(blockheight - 1), block.blockhash(blockheight), offset));
  }
}
```

Miner collusion is required to successfully attack this system, and even then, it is unlikely to be economically feasible. Assume an attacker makes a precommitment to open a crate; they must generate at least the second block of the next two blocks _and_ find a hash which is a valid under the Ethereum consensus rules _and_ also satisfies the additional constraint of getting a wanted random number out of the system. The target block generation time in Ethereum is 12 seconds--they must find a hash that meets their additional constraints while everyone else in the network is merely playing by the normal consensus rules.

Mining is computationally intensive; for an attacker to have any remote chance of success, they would need to have many multiples of the entire network's current hashrate.

### Does This Even Make Sense to Do?

It makes more sense to give people the option of uncrating on the blockchain than recording statistics. Uncrating is an opt-in activity. However, doing so comes at the cost of multiple transactions. Would people pay for multiple transactions to uncrate? Perhaps. But would they pay the additional time? They would have to wait for the first block to be mined for the precommitment, wait for the second and third blocks for the hashes, and then would have to wait for a fourth block for executing the precommitment. At an average 12 second block time, would people wait 48 seconds to see the result of their uncrating? Especially when uncrating in a centralized manor takes 5 seconds.

Something like uncrating should be included for completeness, but it may not see use in practice.
