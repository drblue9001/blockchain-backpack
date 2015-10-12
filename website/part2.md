---
title: "Extension and Blockchain Item Modification"
layout: page
prev-page:
    title: "Introduction"
    url: part1.html
next-page:
    title: "Trading"
    url: part3.html
---

Extension and Blockchain Item Modification
------------------------------------------

In the previous part, we described why we should move parts of Valve's item system onto the blockchain and built an interface for the basics of handling items. In part 2, we're going to build the interfaces that would allow Valve to deploy code to modify items.

### More things to do!

These games have been built piece-wise over multiple years. In the case of Team Fortress 2, first the game launched. Then [the ability to have different weapons][goldrush] was added. Later, the [ability to paint items][mannconomy] was added. As time went on, they added new ways to modify items, and I expect that we'll see many more new ways to modify items in the future. We don't just need to support the current feature list, but need to build up a way to continue to extend the system. So let's make some general interfaces.

[goldrush]: https://wiki.teamfortress.com/wiki/Gold_Rush_Update
[mannconomy]: https://wiki.teamfortress.com/wiki/Mann-Conomy_Update

### Painting as an example

There are two sorts of actions taken on items: an item is consumed or otherwise used to modify/create an item, or a contextual named action is invoked on an item. Painting items is a good example of both: the [paint can][pc] is an example of an item consumed to change the color of an item, and the Restore command is an example of a command that removes the effects of the paint can.

[pc]: https://wiki.teamfortress.com/wiki/Paint_Can

### Show me the code.

Using a Paint Can copies some attributes from the Paint Can to the target item, then consumes the Paint Can. Let's jump into the deep end of the pool and eventually write the lifeguard:

```cpp
contract PaintCan is MutatingExtensionContract {
  function MutatingExtensionFunction(uint64[] item_ids)
      external returns (bytes32 message) {
    Backpack backpack = Backpack(msg.sender);

    if (item_ids.length != 2) return "Wrong number of arguments";

    // "set item tint RGB" is defindex 142.
    uint64 tint_rgb = backpack.GetItemIntAttribute(item_ids[0], 142);
    if (tint_rgb == 0)
      return "First item not a paint can.";

    // This here is a bit of a hack; the capabilities aren't actually
    // attributes in the json file; for demonstration purposes, we
    // just refer to '"capabilities": { "paintable" }' as 999999.
    uint64 is_paintable = backpack.GetItemIntAttribute(item_ids[1], 999999);
    if (is_paintable == 0)
      return "Second item not paintable";

    // Create a new item number since we're making modifications to the item.
    uint64 new_item = backpack.OpenForModification(item_ids[1]);
    if (new_item == 0)
      return "Failed to open for modification";

    // Sets the main primary color.
    backpack.SetIntAttribute(new_item, 142, tint_rgb);

    // Team dependent paints set a secondary color.
    // "set item tint RGB 2" is defindex 261.
    uint64 tint_rgb_2 = backpack.GetItemIntAttribute(item_ids[0], 261);
    if (tint_rgb_2 != 0)
      backpack.SetIntAttribute(new_item, 261, tint_rgb_2);

    // Finalize it.
    backpack.FinalizeItem(new_item);

    // Destroy the paint can.
    backpack.DeleteItem(item_ids[0]);
    return "OK";
  }
}
```

This is obviously an implementation of an interface. Ideally, how would a user invoke this contract?

```cpp
// As a user who owns |paint_can_id| and |painted_item_id|:
backpack.UseItem([paint_can_id, item_to_paint_id]);
```

We can have these sort of shorthand semantics by associating a piece of extension code with an item. Up until this point, I haven't mentioned how much of the TF2 item schema would have to be written onto the blockchain, versus served traditionally.

```cpp
contract Backpack {                     // Continued.
  // Sets the |min_level|, |max_level| and |use_contract|.
  function SetItemSchema(uint32 defindex, uint8 min_level, uint8 max_level,
                         address use_contract);

  // Sets an attribute for all instances of |item_defindex|.
  function AddIntAttributeToItemSchema(uint32 item_defindex,
                                       uint32 attribute_defindex,
                                       uint64 value) returns (bytes32);

  // Uses `item_ids[0]`, unlocking and passing the rest of the items
  // to the items use contract.
  function UseItem(uint64[] item_ids) returns (bytes32 message);
}
```

We don't need most of the data in the TF2 item schema on chain; all we need is the possible level range (since we can generate items entirely on-chain), and the address of a contract which provides extension code...such as `PaintCan`. We can set up the schema of the paint cans:

```cpp
// As a user with SetPermission and ModifySchema:
paint_can_contract = new PaintCan;
bp.SetPermission(paint_can_contract, Permissions.AddAttributesToItem);

// Everyone's favorite color: Pink as Hell
bp.SetItemSchema(5051, 5, 5, paint_can_contract);
bp.AddIntAttributeToItemSchema(5051, 142, 16738740);

// Everyone's other favorite color: The Bitter Taste of Defeat and Lime.
bp.SetItemSchema(5054, 5, 5, paint_can_contract);
bp.AddIntAttributeToItemSchema(5054, 142, 3329330);

// Team Spirit
bp.SetItemSchema(5046, 5, 5, paint_can_contract);
bp.AddIntAtributeToItemSchema(5046, 142, 12073019);
bp.AddIntAtributeToItemSchema(5046, 261, 5801378);

// ...
// etc.
```

Now that we have the schema of paint cans set so we can instantiate them and use them, let's describe what `UseItem()` does. It looks at the schema of the first item in the list of incoming ids. If all those items exists, and the first item's type has a `use_contract` set by `SetItemSchema()`, it unlocks all the incoming items for that contract so that contract can modify those items. Then it calls the `use_contract` with the item_ids. Then it locks any still existing items after the call.

This lets a user modify their items using code blessed by Valve, only when they wish. As each transaction needs a separate button press on the theoretical signing hardware, we want this user request to be a single signed transaction.

### Removing the paint job

There is another sort of piece of extension code: actions that can be performed on items which aren't associated with a tool item. Let's look at the mirror of the Paint Can: the restore paint job command:

```cpp
contract RestorePaintJob is MutatingExtensionContract {
  function MutatingExtensionFunction(uint64[] item_ids)
      external returns (bytes32 message) {
    Backpack backpack = Backpack(msg.sender);

    if (item_ids.length != 1) return "Wrong number of arguments";

    // "set item tint RGB" is defindex 142.
    uint64 tint_rgb = backpack.GetItemIntAttribute(item_ids[0], 142);
    if (tint_rgb == 0)
      return "Item isn't painted";

    uint64 new_item = backpack.OpenForModification(item_ids[0]);
    if (new_item == 0)
      return "Failed to open for modification";

    backpack.RemoveIntAttribute(new_item, 142);
    backpack.RemoveIntAttribute(new_item, 261);
    backpack.FinalizeItem(new_item);

    return "OK";
  }
}
```

The implementation of this is once again straightforward: Check validity, open for modifications, remove attributes, finalize.

We want to invoke it similarly to painting the item, in a single transaction. Ideally:

```cpp
// As the owner of |painted_item_id|.
backpack.DoAction("RestorePaintJob", [painted_item_id]);
```

This is straight-forward to do; we just need to add a registry which associates a static length string with a contract:

```cpp
// As a user with SetPermission and ModifySchema:
restore_paint_job_contract = new RestorePaintJob;
bp.SetPermission(restore_paint_job_contract, Permissions.AddAttributesToItem);
bp.SetAction("RestorePaintJob", restore_paint_job_contract);
```

And we can call `SetItemSchema()` / `SetAction()` on the same item schema / action string as many times as necessary to update what code should be run in case we accidentally deploy a contract with a bug in it.

So we now have a way of modifying an item only when the user requests it, and only with code blessed by Valve. These primitives should be able to implement strangifiers, killstreak kits, chemistry sets, custom name and description tags, Halloween spells, and anything else that modifies items in the game. We have made the system extensible.
