Trading with the Blockchain backpack
------------------------------------

In part 1, we gave a general overview of the system. In part 2, we showed off how to allow the modification of items. In part 3, we'll talk about trading.

## The insecure primitive

At the bottom, we built one primitive for moving items around and described it briefly in Part 1:

```
// As the owner of |item_id|.
bp.GiveItemTo(item_id, other_player_address);
```

This is obviously not very useful unless you unconditionally trust your trading partner, and remember that we are building this system to _enhance_ security of our items! However, we can use this basic primitive to implement secure trading by building another contract as a trade coordinator.

##

So far, we've only made contracts that are called directly by the main backpack contract, but the system is flexible enough that we can 


