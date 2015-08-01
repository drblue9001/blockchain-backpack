The Blockchain Backpack
-----------------------

## Introduction to Valve

Valve has one of the few free to play (F2P) monetization models which doesn't feel exploitive. In a F2P game like King.com's Candy Crush, the game is balanced around throwing up barriers to progressing, and then trying to sell one-time consumable items to remove these barriers. In contrast, Valve's Dota 2 and Team Fortress 2 are free to play games where all players are on an even footing. In [the terms of Ramin Shokrizade][topf2p], Candy Crush is a Money Game, while Valve's offerings are Skill Games.

Valve monitizes their F2P games by selling cosmetic items, versions of the free items which additionally track statistics, tickets to and [digital program book][compendium] about the e-sports matches of their games, et cetera. Valve's Kyle Davis did a talk, [In-Game Economies in Team Fortress 2 and Dota 2][davistalk], which is a good overview about how they think about creating player value.

The majority of these items are tradable between players. The value of an item is not just its cosmetic or utility valule, it also has secondary market resale value. Users created a vibrant trading market with [pricing guides][bptf]. And Valve has [its own official player to player marketplace][scm], which uses real currency.

[topf2p]: http://www.gamasutra.com/blogs/RaminShokrizade/20130626/194933/The_Top_F2P_Monetization_Tricks.php
[compendium]: http://www.dota2.com/international/compendium/0/1/0/
[davistalk]: https://youtu.be/RHC-uGDbu7s
[bptf]: https://backpack.tf/
[scm]: http://steamcommunity.com/market

## Introduction to Ethereum

Most people have at least heard of [Bitcoin][bitcoin], and think it a currency. A better model would be to think of it as a secure, shared ledger that has hard coded rules for dealing with a specific currency. Ethereum is one of the many "Bitcoin 2.0" projects being developed to expand the use of secure, distributed ledgers to other purposes. Instead of having hard coded rules for how to transact the bitcoin currency, Ethereum has a Turing complete scripting language describing how an individuas transactions shoud change the ledger, often described as a "Smart Contract".

(For a more technical introduction to the system, please see the [Ethereuem whitepaper][whitepaper]. Most of the code samples in this document are written in [Solidity][sol].)

During this year's April Fools day, the Ethereuem folks put out an announcement [that they were merging with Valve][fools]. While this was meant as a joke...parts of it are actually a really good idea.

[bitcoin]: https://bitcoin.org/
[whitepaper]: https://github.com/ethereum/wiki/wiki/White-Paper
[sol]: https://github.com/ethereum/wiki/wiki/Solidity-Tutorial
[fool]: https://blog.ethereum.org/2015/04/01/ethereums-unexpected-future-direction/

## The Problem

Items in Valve's ecconomy are tied to your Steam account. So we have items of real monetary vaule protected only by passwords on Windows machines. Breaking into someone's account and clearing out their virtual items for resale has become an epidemic. (Maybe describe how the fraud works and some of Valve's attempts to deal.)

On top of that, Valve's infrastructure is sometimes unable to deal with the demands placed upon it. Every year, during the Steam Chirstmas sale, things go to hell. The Steam marketplace usually breaks under the transactional load. Trades between players tend to error out during these weeks. Strange weapons in TF2 (and I assume other games) intermittently stop recording their statistics.

This series of articles describe a proof of concept system I've built that decentralizes their item system **in a way that wouldn't threaten Valve's monopoly on item generation**. I propose moving a portion of TF2's backpack system onto the Ethereum blockchain.

## A quick overview of what we want to buid

In any proposed revamp of an existing system, we want to come as close to a [Pareto improvement][pareto]: everyone should be at least as well off as they are under the current system. This is important because otherwise there is no incentive to change. Valve's item minting monopoly must not be impinged, since this funds further development of their games.

If we were going to buid an idealized backpack, what properties should it have?

* Only Valve (or programs authorized by Valve) should be able to create items,
  and to add code to the system which is able to modify items (paint,
  killstreak kits, strange parts, etc).
* An item, given to a user, should only be modifiable by that user:
  * Only modification code blessed by Valve should be run, but only when the
    user says so.
  * Only the user should be able to send an item to another player.
  * A user should be able to subcontract any of these rights.

We can build a small program (a contract) that does the above, and that is deployed on the Ethereum blockchain. We'll want a main contract for performing storage of items, along with extension interfaces which will allow item modification and futher expansion of the system.

Given that all interactions with this contract are done through digitally signed messages, people's backpack identity becomes a public/private keypair. This brings us to the one thing we won't prototype: dedicated hardware to protect the private key and perform signing of messages that get sent to the backpack system. I will instead hand-wave towards the bitcoin communities hardware wallets which perform a similar function: Trezor, Ledger Wallet, etc.

[pareto]: http://en.wikipedia.org/wiki/Pareto_efficiency

## The actual prototype

I've created a prototype 
