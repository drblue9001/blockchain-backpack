---
layout: page
next-page:
    title: "Item Modification"
    url: part2.html
---

Part 1: Introduction: The Blockchain Backpack
---------------------------------------------

### Introduction to Valve

Valve has one of the few free to play (F2P) monetization models which doesn't feel exploitive. In a F2P game like King.com's Candy Crush, the game is balanced around throwing up barriers to progressing, and then trying to sell one-time consumable items to remove these barriers. In contrast, Valve's Dota 2 and Team Fortress 2 are free to play games where all players are on an even footing. In [the terms of Ramin Shokrizade][topf2p], Candy Crush is a Money Game, while Valve's offerings are Skill Games.

Valve monitizes their F2P games by selling cosmetic items, versions of the free items which additionally track statistics, tickets to and [digital program books][compendium] about the e-sports matches of their games, et cetera. Valve's Kyle Davis did a talk, [In-Game Economies in Team Fortress 2 and Dota 2][davistalk], which is a good overview about how they think about creating player value.

The majority of these items are tradable between players. The value of an item is not just its cosmetic or utility valule, it also has secondary market resale value. Users created a vibrant trading market with [pricing guides][bptf]. And Valve has [its own official player to player marketplace][scm], which uses national fiat currency.

[topf2p]: http://www.gamasutra.com/blogs/RaminShokrizade/20130626/194933/The_Top_F2P_Monetization_Tricks.php
[compendium]: http://www.dota2.com/international/compendium/0/1/0/
[davistalk]: https://youtu.be/RHC-uGDbu7s
[bptf]: https://backpack.tf/
[scm]: http://steamcommunity.com/market

### Introduction to Ethereum

Most people have at least heard of [Bitcoin][bitcoin], and think it a currency. A better model would be to think of it as a secure, shared database that has hard coded rules for dealing with a specific currency. Ethereum is one of the many "Bitcoin 2.0" projects being developed to expand the use of authenticated, distributed databases to other purposes.

Instead of having hard coded rules for how to transact the bitcoin currency, Ethereum has a Turing complete scripting language describing how an individual transaction should mutate the ledger. A user, identified by a public/private keypair, can deploy a small program (called a contract) to the Ethereum blockchain, and let other users send message calls to it. This program then has an address, and will manage its own state as programmed when users send digitally signed messages to it. These transactions are considered to have "run" when they are committed to a block.

(For a more technical introduction to the system, please see the [Ethereum whitepaper][whitepaper], and their page on their [light client protocol][light]. Most of the code samples in this document are written in [Solidity][sol].)

During this year's April Fools day, the Ethereum folks put out an announcement [that they were merging with Valve][fools]. While this was meant as a joke...parts of it are actually a really good idea.

[bitcoin]: https://bitcoin.org/
[whitepaper]: https://github.com/ethereum/wiki/wiki/White-Paper
[light]: https://github.com/ethereum/wiki/wiki/Light-client-protocol
[sol]: https://github.com/ethereum/wiki/wiki/Solidity-Tutorial
[fool]: https://blog.ethereum.org/2015/04/01/ethereums-unexpected-future-direction/

### The Problem

Items in Valve's ecconomy are tied to your Steam account. So we have items of real monetary vaule with a fairly liquid market place protected only by passwords on Windows machines. Breaking into someone's account and clearing out their virtual items for resale has become an epidemic, with dedicated malware attempting to gain control of Steam accounts. Steam support has a extremely poor reputation, so good luck if your account is hijacked.

On top of that, Valve's infrastructure is sometimes unable to deal with the demands placed upon it. Every year, during the Steam Chirstmas and Summer sales, things go to hell. The Steam marketplace usually breaks under the transactional load. Trades between players tend to error out during these weeks. Strange weapons in TF2 (and I assume other games) intermittently stop recording their statistics.

I write this as a concerned citizen of the Badlands. I am worried about security, as [I own many rare items in TF2][myinv]; I have 15 unusuals, and 7 Australiums. I've tried to direct my worry productively, and thus I've written a series of articles that describe a proof of concept system I've built that decentralizes the Valve item system **in a way that wouldn't threaten Valve's monopoly on item generation**. In any proposed revamp of an existing system, we want to come as close to a [Pareto improvement][pareto] as possible: everyone should be at least as well off as they are under the current system. This is important because otherwise there is no incentive to change. Valve's item minting monopoly must not be impinged: it would destabalize the economy and would deny Valve further funds to development of their games. Besides, Valve would never intentionally sign on to a system that hurt them.

I propose moving a portion of TF2's backpack system onto a blockchain, and will use Ethereum as an example. A blockchain is really a decentralized database, solving the issue of intermittent outages of centralized infrastructure. (Which fixes being unable to verify item ownership when Valve's infrastructure fails.) All messages that get incorporated into blocks are digitally signed, often with hardware. (Which fixes many of the security problems around the economy.) The tradeoffs will be looked at in depth in Part 4.

[myinv]: http://steamcommunity.com/id/drblue9001/inventory/#440
[pareto]: http://en.wikipedia.org/wiki/Pareto_efficiency

## What is an item in this system anyway

If you were to sign up for a Steam API key and access the raw backpack data, you'd be left with an array of things like this (I've censored out ID numbers here):

```json
{
	"id": 1111111,
	"original_id": 1111111,
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
}
```

(The item above is a [Southie Shinobi][ss] (defindex:30395), painted with [The Value of Teamwork][vot] (defindex:142,261), and with [Spectral Spectrum][spectral] (defindex:1004) applied.)

An item is thus a few pieces of data: the `original_id` (the ID of this item at creation time), the `id` (the ID of the item currently; changes each time an item is traded or modified), the `defindex` (the type of item), the `level`, `quality` and `origin` (various metadata) and then a set of `attributes`.

All of this could be stored in a different medium. We could write an Ethereum contract that stored all of this data. While this specific item doesn't have any string attributes, those too can be easily represented.

[ss]: https://wiki.teamfortress.com/wiki/Southie_Shinobi
[vot]: https://wiki.teamfortress.com/wiki/Paint_Can
[spectral]: https://wiki.teamfortress.com/wiki/Spectral_Spectrum_(halloween_spell)

### A quick overview of what we want to build

If we were going to buid an idealized backpack, what properties should it have?

* Only Valve (or contracts authorized by Valve) should be able to create items,
  and to add code to the system which is able to modify items (paint,
  killstreak kits, strange parts, etc).
* Only the owner of an item should be able to make use of an item:
  * They should be able to trade it to another player.
  * They should be able to run Valve blessed modification code.

We can build an Ethereum contract that does the above (part 1), and add hooks so Valve can continue to deploy new features. The main contract will perform the core storage of items, authentication, and dispatch to extension contracts for item modification and futher expansion of the system. The entire prototype is [here on github][prototype]; the rest of this article will instead be a high level overview of the software interface.

<image style="float:right; width: 175px; margin: 10px;" src="trezor.jpg" />

Given that all interactions with this contract are done through digitally signed messages, people's backpack identity becomes a public/private keypair. This brings us to the one thing we won't prototype: dedicated hardware to protect the private key and perform signing of messages that get sent to the backpack system. Given the prevalence of remote access trojans as a way to bypass Valve's existing two-factor authentication, any system that relies on the security of a user's desktop is non-starter. I will instead hand-wave towards the Bitcoin communities hardware wallets which perform a similar function: [Trezor][trezor] (shown right), [Ledger Wallet][ledger], smart cards with secure elements, etc. Steam would prepare a transaction request and would send it to the signing hardware. The signing hardware would show the transaction to the user on an embedded screen. The user would have to physically press a button on the signing hardware to sign the proposed transaction.

[trezor]: https://www.bitcointrezor.com/
[ledger]: https://www.ledgerwallet.com/

[prototype]: FILL_ME_IN_LATER

### Representing permissions

All users will interact with the central backpack contract. In a system where different users interact with the same program, we need a way of keeping track of what users have which capabilities. For instance, a random person with a backpack should not be able to create items out of thin air. We should create a system of permissions to enforce the principle of least privilege.

```cpp
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
```

As written, the keypair which deployed the contract has full rights to do anything; if this system were ever to be deployed, revocable "admin" accounts should be created for routine use, granted the necessary permissions to do their jobs. (The original public/private key should sit in a safe somewhere in case of emergencies.)

When we write a contract representing a Paint Can (we will do so in part 2), we will want to grant it `AddAttributesToItem`. When we write a contrat representing a Crate (part 5), we will want to grant it `GrantItems`, too. The Backpack Expander would receive `BackpackCapacity`. Etc.

### The flow of Valve granting an item

Right now, there are _a lot_ of preexisting items in the TF2 universe which could be migrated off the centralized database and onto the decentralized blockchain. But what would the programmatic interface look like?

Let's start delving into the interface our contract exposes:

```cpp
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

  // When |item_id| exists, and the item is unlocked for the caller and the
  // caller has Permissions.AddAttributesToItem, create a new item number for
  // this item and return it. Otherwise returns 0.
  function OpenForModification(uint64 item_id) returns (uint64);
}
```

If we wanted to import the above item onto the blockchain backpack, assuming we had the correct permissions, we would issue:

```cpp
// As a user who has the GrantItems and AddAttributesToItem permissions.
id = bp.ImportItem(30395, 6, 8, 69, xxxxxx, recipient_address);
bp.SetIntAttribute(id, 142, 1258303520);
bp.SetIntAttribute(id, 261, 1242936884);
bp.SetIntAttribute(id, 1004, 1077936128);
bp.FinalizeItem(id);
```

The creator of an item builds the item, and then adds all the attributes to that item. They then finalize the item, and no longer have access to modifying it. It is now `recipient_address`'s item to do with as they please.

(Why do it this way? Because we want to minimize the number of parameters to a single function. This may have been due to me starting this project when the compiler was in pre-alpha, but I had some issues with overflowing the local variable stack when I passed too many parameters. This influenced the design of this prototype, and may not be necessary anymore.)

### User commands

So, what can a user do with their item themselves? Well, they could give it to another person or delete it:

```cpp
contract Backpack {
  // Give the item to recipient. This will generate a new |item_id|. Returns
  // the new |item_id|. (May only be called by the item's owner or
  // unlocked_for.)
  GiveItemTo(uint64 item_id, address recipient) returns (uint64);

  // Deletes the item. (May only be called by the item's owner or
  // unlocked_for.)
  function DeleteItem(uint64 item_id);
}
```

They can't modify it themselves as they don't have the `AddAttributesToItem` permission, so how would they apply paint (among other things) to their items? Every item has an owner, but it also has an `unlocked_for` user, a person or contract that can temporarily act as an item's owner:

```cpp
contract Backpack {
  // Temporarily grant |c| access to |item_id|.
  function UnlockItemFor(uint64 item_id, address c);

  // Revoke non-owner access to |item_id|.
  function LockItem(uint64 item_id)
}
```

Believe it or not, we now have everything needed to rebuild the entire economy!

### Users unlocking items for modification

In the Valve item system, whenever an item is modified, it gets a new item id. This seems like an important identity property to preserve, so the only way to modify a finalized item should be to give it a new item id:

```cpp
// As the owner of an item:
bp.UnlockItemFor(my_item_id, a_valve_contract);
a_valve_contract.call([my_item_id]);  // Not the real syntax

// Inside the implementation of a_valve_contract:
new_item = bp.OpenForModification(my_item_id);
bp.SetIntAttribute(new_item, xxx, yyyyyy);
bp.FinalizeItem(new_item)
```

So we have the entire lifecycle of an item here. We can import them / create them. And then the user can give access to the item to a valve published contract which will create a new item id, and modify the user's item.

But what would a contract that adds attributes to an item look like?. We'll explore that in Part 2...
