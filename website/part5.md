---
title: "Statistics and Stranges on the Blockchain"
layout: page
prev-page:
    title: "Trade-offs"
    url: part4.html
next-page:
    title: "Crates"
    url: part6.html
---

Statistics and Stranges on the Blockchain
-----------------------------------------

One component of the Valve item economy that we haven't addressed yet are items which record statistics about their own use. Hats that keep track of the number of points scored while wearing them. Guns that keep track of the number of players killed with them. In TF2, these items are called [Strange][]. Currently, these are handled with centralized infrastructure; there is a central item server that everyone talks to.

[Strange]: https://wiki.teamfortress.com/wiki/Strange

### _Can_ we decentralize it? ...

Yes! We can implement it many ways. We can implement it as part of the main Backpack contract (and that's how I've done so in the proof of concept):

```cpp
contract Backpack {
  // Adds |amount| to the current value of |attribute_defindex| on |item_id|.
  // |attribute_defindex| must have been set as a modifiable attribute at the
  // time the attribute was originally set on this object. The caller must have
  // Permissions.ModifiableAttribute, or this method does nothing.
  function AddToModifiable(uint64 item_id,
                           uint32 attribute_defindex,
                           uint32 amount);
}
```

We could also implement as an extension contract (as seen in part 2) and store mutable data outside the main item definition. Ethereum is Turing complete, there are a lot of options.

It's so boring, isn't it? Sure, there are a few things that the implementation needs to keep track of: We need to ensure that only attributes marked as modifiable can be changed, and that `GiveItemTo()` clears all modifiable attributes. (You can see tests for all of these situations in the python unit tests.)

### ...But _should_ we?

We should instead ask if this is a good idea. I've gone ahead and made this a part of the proof of concept because I'm going for as much decentralization as possible and the removal of all trusted third parties that go down from time to time. But I don't think it's the obviously correct thing to do in a real, production ready implementation of a blockchain backpack.

Would you pay a couple of cents per match to record that you killed players with a certain weapon X times, that you scored Y points while wearing this hat, etc? How would you go about building a system to do this? Does Valve host a centralized server which acts as a gateway and uses Steam Wallet funds to pay for transaction fees? (If so, what's the point of the exercise if we're still relying on a centralized piece of infrastructure?) Does each registered server have a keypair with the ModifiableAttribute permission? If so, how will the server pay the blockchain transaction fees? Do players have to send Ethereum to a server or the server won't record their statistics? Are players responsible for recording their own stats? If so, what's keeping them from manually crafting transactions which claim to have done thousands of kills?

All of these are questions that are entirely avoided by using centralized infrastructure for recording statistics. Unlike ownership, individual users don't (directly) mutate the statistics that their items keep track of.

Transfers and modifications of high value items are rare enough that blockchain transaction fees are ignorable. Modification of statistics happens whenever you use an item in a game. A few cents to record item ownership changes is fine. A few cents to record your kill count for every match probably isn't.

