/* When publishing this part, if done in a series, there should be a discussion
 * about how uncrating is probably uneconomical on the block chain, but that
 * we're putting together uncrating as an example anyway because it is
 * interesting.
 *
 * Contributing parts: Crates are going to have at least two attributes. Lots
 * of messages between the Uncrate contract and the Backpack to check
 * attributes. Unknown how expenseive the whole thing will be. Uncrating
 * already having a negative return.
 */

contract ExtensionContract {
  function ExtensionFunction(bytes32 name, uint64[] item_ids)
      returns (bytes32 message) {}
}

contract Crate is ExtensionContract {
  function ExtensionFunction(bytes32 name, uint64[] item_ids)
      returns (bytes32 message) {
    BackpackSystem backpack = BackpackSystem(msg.sender);

    if (item_ids.length != 2) return "Wrong number of argumetns";

    // TODO: It's more complex than this. The attributes "set supply crate
    // series" (187) and "decoded by itemdefindex" (528) are what really
    // control this, so we need fetching attributes working before we really
    // touch this.
    int crate_series = backpack.GetItemAttribute(item_ids[0], 187);
    if (crate_series == 0)
      return "Not a crate.";

    int key_defindex = backpack.GetItemAttribute(item_ids[0], 528);
    if (key_defindex == 0)
      return "Crate unopenable.";

    if (key_defindex != backpack.GetItemDefindex(key_item_id))
      return "Wrong key used.";

    // Why delete the previous items before granting the new item? Because
    // let's say that the users backpack is full at the time they execute the
    // recipee. We delete the previous two items to make room.
    backpack.DestroyItem(item_ids[0]);
    backpack.DestroyItem(item_ids[1]);

    int32 r = backpack.GetRandom(0, 150);
    if (r == 0) {
      // Handle the unusual case.
    } else if (r < 12) {
      // For now, we just hard grant "A Distinctive Lack of Hue"
      backpack.GrantNewItem(tx.origin, 5040, 5, 8);
    }
  }
}
