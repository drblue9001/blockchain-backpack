---
title: "Trading with the Blockchain backpack"
layout: page
prev-page:
    title: "Item Modification"
    url: part2.html
next-page:
    title: "Trade-offs"
    url: part4.html
---

Trading with the Blockchain backpack
------------------------------------

In part 1, we gave a general overview of the system. In part 2, we showed off how to allow the modification of items. In part 3, we'll talk about trading.

### The insecure primitive

At the bottom, we built one primitive for moving items around and described it briefly in Part 1:

```cpp
// As the owner of |item_id|.
bp.GiveItemTo(item_id, other_player_address);
```

This is obviously not very useful unless you unconditionally trust your trading partner, and remember that we are building this system to _enhance_ security of our items! However, we can use this basic primitive to implement secure trading by building another contract as a trade coordinator.

### A more realistic trading system.

So far, we've only made contracts that are called directly by the main backpack contract, but the system is flexible enough that we can make contracts that aren't trusted by the system at all.

```cpp
contract TradeCoordinator {
  struct Trade {
    address user_one;
    address user_two;
    uint64[] user_one_items;
    uint64[] user_two_items;
  }

  function ProposeTrade(uint64[] my_items,
                        address user_two,
                        uint64[] their_items)
      returns (uint trade_id) {
    uint i;
    for (i = 0; i < my_items.length; ++i) {
      // Verify this item belongs to the sender.
      if (backpack.GetItemOwner(my_items[i]) != msg.sender)
        return 0;
      // Verify this item is in a state where we can give it away.
      if (backpack.CanGiveItem(my_items[i]) != true)
        return 0;
    }

    // Verify that all |their_items| belong to |user_two|.
    for (i = 0; i < their_items.length; ++i) {
      if (backpack.GetItemOwner(their_items[i]) != user_two)
        return 0;
    }

    // Get the next trade number
    trade_id = trades.length;
    trades.length++;
    Trade t = trades[trade_id];
    t.user_one = msg.sender;
    t.user_two = user_two;
    t.user_one_items = my_items;
    t.user_two_items = their_items;
  }

  function AcceptTrade(uint256 trade_id) {
    Trade t = trades[trade_id];
    if (msg.sender != t.user_two)
      return;

    // WARNING: There's a whole lot of validity checking stuff that needs to be
    // done here for a real implementation. For brevity, I've removed the
    // validity checking that I did write from the website version, such as
    // making sure all items are unlocked, that a user can receive items, etc.

    uint length = t.user_one_items.length;
    if (t.user_two_items.length > length)
      length = t.user_two_items.length;
    for (i = 0; i < length; ++i) {
      if (i < t.user_one_items.length)
        backpack.GiveItemTo(t.user_one_items[i], t.user_two);
      if (i < t.user_two_items.length)
        backpack.GiveItemTo(t.user_two_items[i], t.user_one);
    }

    DeleteTradeImpl(trade_id);
  }

  function RejectTrade(uint256 trade_id) {
    Trade t = trades[trade_id];
    if (msg.sender != t.user_two)
      return;

    DeleteTradeImpl(trade_id);
  }

  function TradeCoordinator(Backpack system) {
    backpack = system;
    trades.length = 1;
  }

  function DeleteTradeImpl(uint256 trade_id) private {
    Trade t = trades[trade_id];
    delete t.user_one_items;
    delete t.user_two_items;
    delete trades[trade_id];
  }

  Backpack backpack;
  Trade[] trades;
}
```

A user would be able to propose a trade:

```cpp
// As user 1:
bp.UnlockItemFor(my_bison_id, trade_coordinator)
trade_coordinator.ProposeTrade([my_bison_id], user_2, [his_black_box_id])
```

User 2 could accept this offer:

```cpp
// As user 2:
bp.UnlockItemFor(has_black_box_id, trade_coordinator)
trade_coordinator.AcceptTrade(trade_id);
```

`AcceptTrade()`, checking that both items are unlocked for it, actually performs the trade in a safe and atomic matter. And it's built out of primitives that anyone can write.

In the case of a bad offer, User 2 could also do nothing. User 1, who proposed the trade, paid a few cents to do so. As the contract is written above, there's no reason for User 2 to pay a few cents to do the cleanup. (There are fancy tricks to use cleanup to pay for other computation in Ethereum, but I've left them out of this proof of concept for brevity.)

### Some notes on implementation

In a real implementation that Valve would write, the concept of trading would preferably be done through the `DoAction()` command as introduced in part 2 because you want the user to only reach for their signing hardware once when using official contracts.

Rather, I've written it this way to make the point that building a robust, trustless trading system doesn't actually need any blessings from Valve, and that the `UnlockItemFor()` system gives us that flexibility if we want it.

At the beginning of this series, I said that the system should be as close to a Pareto improvement as possible; that all parties in the ecosystem should be at least as well off as they were previously. Users and Valve are not the only participants in the item ecosystem though.

[TF2WH][] is an old site that lets users trade their TF2 items for a site internal credit. They were the first site that I traded with when I was new to the TF2 trading scene. They too are a stakeholder in the economy, as are many 3rd party websites. And their site has a simple analog on the blockchain: a contract that manages a backpack, and that buys and sells for its own internal credit. (Both user keypairs and contracts have addresses in the same namespace in Ethereum; assuming it would be allowed, the contract could be given a backpack to manage.)

And that's just one site. The TF2 item trading ecosystem is huge. You could have a contract for backpack.tf style classifieds. Marketplace.tf style item purchasing. All these sites are stakeholders and they too should be as well off under the new system as the old.

[TF2WH]: https://www.tf2wh.com/
