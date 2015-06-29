
contract PaintCan is ExtensionContract {
  function ExtensionFunction(bytes32 name, uint64[] item_ids)
      returns (bytes32 message) {
    BackpackSystem backpack = BackpackSystem(msg.sender);

    if (item_ids.length != 2) return "Wrong number of arguments";

    // "set item tint RGB" is defindex 142.
    int tint_rgb = backpack.GetItemAttribute(item_ids[0], 142);
    if (tint_rgb == 0)
      return "First item not a paint can.";

    // TODO(drblue): Get a real attribute number for
    // "capabilities": { "paintable" }
    int is_paintable = backpack.GetItemAttribute(item_ids[1], 999999);
    if (crate_series == 0)
      return "Second item not paintable";

    backpack.SetItemAttribute(item_ids[1], 142, tint_rgb);

    // Team dependent paints set a second attribute.
    // ""set item tint RGB 2" is defindex 261.
    int tint_rgb_2 = backpack.GetItemAttribute(item_ids[0], 261);
    if (tint_rgb_2 != 0)
      backpack.SetItemAttribute(item_ids[1], 261, tint_rgb_2);

    // Destroy the paint can.
    backpack.DestroyItem(item_ids[0]);
  }
}

