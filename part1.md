The Blockchain Backpack
-----------------------

## Introduction to Valve

Valve has one of the few free to play (F2P) monetization models which doesn't feel exploitive. In a F2P game like King.com's Candy Crush, the game is balanced around throwing up barriers to progressing, and then trying to sell one-time consumable items to remove these barriers. In contrast, Valve's Dota 2 and Team Fortress 2 are free to play games where all players are on an even footing. In [the terms of Ramin Shokrizade][topf2p], Candy Crush is a Money Game, while Valve's offerings are Skill Games.

Valve monitizes their F2P games by selling cosmetic items, versions of the free items which additionally track statistics, tickets to and [digital program books][compendium] about the e-sports matches of their games, et cetera. Valve's Kyle Davis did a talk, [In-Game Economies in Team Fortress 2 and Dota 2][davistalk], which is a good overview about how they think about creating player value.

The majority of these items are tradable between players. The value of an item is not just its cosmetic or utility valule, it also has secondary market resale value. Users created a vibrant trading market with [pricing guides][bptf]. And Valve has [its own official player to player marketplace][scm], which uses real currency.

[topf2p]: http://www.gamasutra.com/blogs/RaminShokrizade/20130626/194933/The_Top_F2P_Monetization_Tricks.php
[compendium]: http://www.dota2.com/international/compendium/0/1/0/
[davistalk]: https://youtu.be/RHC-uGDbu7s
[bptf]: https://backpack.tf/
[scm]: http://steamcommunity.com/market

## Introduction to Ethereum

Most people have at least heard of [Bitcoin][bitcoin], and think it a currency. A better model would be to think of it as a secure, shared ledger that has hard coded rules for dealing with a specific currency. Ethereum is one of the many "Bitcoin 2.0" projects being developed to expand the use of secure, distributed ledgers to other purposes.

Instead of having hard coded rules for how to transact the bitcoin currency, Ethereum has a Turing complete scripting language describing how an individuas transactions shoud change the ledger, often described as a "Smart Contract". A user, identified by a public/private keypair, can deploy a contract (a small program) to the Ethereum blockchain. The contract then has an address, and will manage its own state as programmed when users send digitally signed messages to it.

(For a more technical introduction to the system, please see the [Ethereuem whitepaper][whitepaper]. Most of the code samples in this document are written in [Solidity][sol].)

During this year's April Fools day, the Ethereuem folks put out an announcement [that they were merging with Valve][fools]. While this was meant as a joke...parts of it are actually a really good idea.

[bitcoin]: https://bitcoin.org/
[whitepaper]: https://github.com/ethereum/wiki/wiki/White-Paper
[sol]: https://github.com/ethereum/wiki/wiki/Solidity-Tutorial
[fool]: https://blog.ethereum.org/2015/04/01/ethereums-unexpected-future-direction/

## The Problem

Items in Valve's ecconomy are tied to your Steam account. So we have items of real monetary vaule protected only by passwords on Windows machines. Breaking into someone's account and clearing out their virtual items for resale has become an epidemic. (Maybe describe how the fraud works and some of Valve's attempts to deal.)

On top of that, Valve's infrastructure is sometimes unable to deal with the demands placed upon it. Every year, during the Steam Chirstmas and Summer sales, things go to hell. The Steam marketplace usually breaks under the transactional load. Trades between players tend to error out during these weeks. Strange weapons in TF2 (and I assume other games) intermittently stop recording their statistics.

This series of articles describe a proof of concept system I've built that decentralizes their item system **in a way that wouldn't threaten Valve's monopoly on item generation**. I propose moving a portion of TF2's backpack system onto the Ethereum blockchain.

A blockchain is really a decentralized database, solving the issue of intermittent outages of centralized infrastructure. (Which fixes being unable to verify item ownership when Valve's infrastructure fails.) All messages that get incorporated into blocks are digitally signed, often with hardware. (Which fixes many of the security problems around the economy.)

## A quick overview of what we want to build

In any proposed revamp of an existing system, we want to come as close to a [Pareto improvement][pareto] as possible: everyone should be at least as well off as they are under the current system. This is important because otherwise there is no incentive to change. Valve's item minting monopoly must not be impinged, since this funds further development of their games, and they would have no reason to sign on to a system that hurt them.

If we were going to buid an idealized backpack, what properties should it have?

* Only Valve (or contracts authorized by Valve) should be able to create items,
  and to add code to the system which is able to modify items (paint,
  killstreak kits, strange parts, etc).
* An item, given to a user, should only be modifiable by that user:
  * Only modification code blessed by Valve should be run, but only when the
    user says so.
  * Only the user should be able to send an item to another player.
  * A user should be able to subcontract any of these rights.

We can build a small program (a contract) that does the above, and that is deployed on the Ethereum blockchain. We'll want a main contract for performing storage of items, along with extension interfaces which will allow item modification and futher expansion of the system. The entire prototype is [here on github][prototype]; the rest of this article will instead be a high level overview.

Given that all interactions with this contract are done through digitally signed messages, people's backpack identity becomes a public/private keypair. This brings us to the one thing we won't prototype: dedicated hardware to protect the private key and perform signing of messages that get sent to the backpack system. I will instead hand-wave towards the Bitcoin communities hardware wallets which perform a similar function: [Trezor][trezor], [Ledger Wallet][ledger], etc.

[pareto]: http://en.wikipedia.org/wiki/Pareto_efficiency
[trezor]: https://www.bitcointrezor.com/
[ledger]: https://www.ledgerwallet.com/

[prototype]: FILL_ME_IN_LATER

## Representing permissions

Different users must have different capabilities. For instance, a random person with a backpack should not be able to create items out of thin air. We should create a system of permissions to enforce the principle of least privilege.

{% highlight solidity %}
enum Permissions {
  SetPermission,
  BackpackCapacity,
  ModifySchema,
  GrantItems,
  AddAttributesToItem,
  ModifiableAttribute
}

function SetPermission(address user, Permissions permission, bool value)
  returns (bytes32);
function HasPermission(address user, Permissions permission)
  constant returns (bool);
{% endhighlight %}

When we write a contract representing a Paint Can (we will do so in part 2), we will want to grant it `AddAttributesToItem`. When we write a contrat representing a Crate (part 3), we will want to grant it `GrantItems`, too. The Backpack Expander would receive `BackpackCapacity`. Etc.

## Representing items

If you were to sign up for a Steam API key and access the raw backpack data, you'd be left with an array of things like this (I've censored out ID numbers here):

```
{
	"id": XXXXXXXXXX,
	"original_id": XXXXXXXXXX,
	"defindex": 30395,
	"level": 69,
	"quality": 6,
	"inventory": 2147483903,
	"quantity": 1,
	"origin": 8,
	"attributes": [
		{
			"defindex": 142,
			"value": 1258303520,
			"float_value": 8400928
		},
		{
			"defindex": 261,
			"value": 1242936884,
			"float_value": 2452877
		},
		{
			"defindex": 1004,
			"value": 1077936128,
			"float_value": 3
		},
		{
			"defindex": 292,
			"value": 1115684864,
			"float_value": 64
		},
		{
			"defindex": 388,
			"value": 1115684864,
			"float_value": 64
		}
	]
	
},
```

An item is thus a few pieces of data: the `original_id` (the ID of this item at creation time), the `id` (the ID of the item currently; changes each time an item is traded or modified), the `defindex` (the type of item), the `level`, `quality` and `origin` (various metadata) and then a set of `attributes`.

(The item above is a [Southie Shinobi][ss] (defindex:30395), painted with [The Value of Teamwork][vot] (defindex:142,261), and with [Spectral Spectrum][spectral] (defindex:1004) applied.)

[ss]: https://wiki.teamfortress.com/wiki/Southie_Shinobi
[vot]: https://wiki.teamfortress.com/wiki/Paint_Can
[spectral]: https://wiki.teamfortress.com/wiki/Spectral_Spectrum_(halloween_spell)

So when building an item on our representation, we'll want a few things:

* The ability to create a new item / import an existing one.
* The ability to add attributes to it.
* The ability to close it for modification.

```
contract Backpack {
  // Used to create new items. If the caller has permission to make new items,
  // create one with the following properties and keep it in the construction
  // state. (Requires Permissions.GrantItems.)
  function CreateNewItem(uint32 defindex, uint16 quality,
                         uint16 origin, address recipient) returns (uint64);

  // Used to import an existing item, which already has a |level| and an
  // |original_id|. (Requires Permissions.GrantItems.)
  function ImportItem(uint32 defindex, uint16 quality, uint16 origin,
                      uint16 level, uint64 original_id, address recipient)
      returns (uint64);

  // Used for contracts to add an attribute to an item that we just started
  // building. (Requires Permissions.AddAttributesToItem.)
  function SetIntAttribute(uint64 item_id, uint32 attribute_defindex,
                           uint64 value);

  // Marks an item created with CreateNewItem() or ImportItem() as finalized
  // and ready to be used. No further modifications can be made to this item.
  function FinalizeItem(uint64 item_id);

  // (There is one more method that 'creates' a new item_id, but we'll wait
  // until part 2 to describe it.)
}
```

If we wanted to import the above item onto the blockchain backpack, assuming we had the correct permissions, we would issue:

```
// As a user who has the GrantItems and AddAttributesToItem permissions.
id = bp.ImportItem(30395, 6, 8, 69, xxxxxx, recipient_address);
bp.SetIntAttribute(id, 142, 1258303520);
bp.SetIntAttribute(id, 261, 1242936884);
bp.SetIntAttribute(id, 1004, 1077936128);
bp.FinalizeItem(id);
```

The creator of an item builds the item, and then adds all the attributes to that item. They then finalize the item, and no longer have access to modifying it. It is now `recipient_address`'s item to do with as they please.

## User commands

So, what can a user do with their item themselves? Well, they could give it to another person or delete it:

```
// Give the item to recipient. This will generate a new |item_id|. Returns the
// new |item_id|. (May only be called by the item's owner or unlocked_for.)
GiveItemTo(uint64 item_id, address recipient) returns (uint64);

// Deletes the item. (May only be called by the item's owner or unlocked_for.)
function DeleteItem(uint64 item_id);
```

They can't modify it themselves as they don't have the `AddAttributesToItem` permission, so how would they apply paint (among other things) to their items? Every item has an owner, but it also has an `unlocked_for` user, a person or contract that can act as an item's owner:

```
// Temporarily grant |c| access to |item_id|.
function UnlockItemFor(uint64 item_id, address c);

// Revoke non-owner access to |item_id|.
function LockItem(uint64 item_id)
```

Believe it or not, we now have everything needed to rebuild the entire economy!
