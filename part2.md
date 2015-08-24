Blockchain Item Modification
----------------------------

In the previous part, we described why we should move parts of Valve's item system onto the blockchain and built an interface for the basics of handling items. In part 2, we're going to build the interfaces that would allow Valve to deploy code to modify items.

## So how does it work today?

There are two sorts of actions taken on items: an item is consumed or otherwise used to modify an item, or a contextual named action is invoked on an item. Painting items is a good example of both: the [paint can][pc] is an example of an item consumed to color an item, and the Restore command is an example of command that removes the effects of the paint can.

[pc]: https://wiki.teamfortress.com/wiki/Paint_Can

## Show me the code.

Using a Paint Can copies some attributes from the Paint Can to the target item, then consumes the Paint Can. Let's jump into the deep end of the pool and eventually write the lifeguard:

```
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

```
// As a user who owns |paint_can_id| and |painted_item_id|:
backpack.UseItem([paint_can_id, item_to_paint_id]);
```

We can have these sort of shorthand semantics by associating a piece of extension code with an item. Up until this point, I haven't mentioned how much of the TF2 item schema would have to be written onto the blockchain, versus served traditionally.

```
contract Backpack {  # Continued from last
  // Sets the min_level, max_level and acction_recipe.
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

We don't need most of the data in the TF2 item schema on chain; all we need is the possible level range (since we can generate items entirely on-chain), and the address of a contract which provides extension code...such as `PaintCan`. We can set up paint can instances:

```
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
// et cetera.
```

## Removing the paint job

There is another sort of piece of extension code: actions that can be performed on items which don't 
