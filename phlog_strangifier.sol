// An abstract recipee.
//
// TODO: This currently hard codes the idea of a single item as the argument
// so that we can get something working.
contract Recipee {
  function ExecuteRecipee(uint64 first_item_id,
                          uint64 second_item_id) returns (bool success) { }
}

// Forward declaration of the BackpackSystem.
contract BackpackSystem {
  function GetItemDefindex(uint64 item_id) returns (uint32 defindex) {}
  function DestroyItem(uint64 item_id) {}
  function GrantNewItem(address user, uint32 defindex, uint16 quality,
                        uint16 origin) returns (uint64 item_id) { return 0; }
  function AddAttributeToUnlockedItem(uint64 item_id,
                                      uint32 attribute_id,
                                      uint64 value) {}
  function LockItem(uint64 item_id) {}
}

contract PhlogStrangifier is Recipee {
  function ExecuteRecipee(uint64 this_item_id,
                          uint64 phlog_id) returns (bool success) {
    BackpackSystem backpack = BackpackSystem(msg.sender);

    // Make sure that the items are what they claim to be.
    if (backpack.GetItemDefindex(this_item_id) != 5722) return;
    if (backpack.GetItemDefindex(phlog_id) != 594) return;

    // Why delete the previous items before granting the new item? Because
    // let's say that the users backpack is full at the time they execute the
    // recipee. We delete the previous two items to make room.
    backpack.DestroyItem(this_item_id);

    // The phlog is unlocked, so we can add a property to it. For the record,
    // '214' is 'kill eater', the implementation of 
    backpack.AddAttributeToUnlockedItem(phlog_id, 214, 0);

    // TODO: Eventually, this will go in our caller, when the per-user scratch
    // space exists.
    backpack.LockItem(phlog_id);
  }
}
