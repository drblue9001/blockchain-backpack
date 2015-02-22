
// An abstract recipee.
//
// TODO: This currently hard codes the idea of a single item as the argument
// so that we can get something working.
contract Recipee {
  function ExecuteRecipee(uint64 first_item_id,
                          uint64 second_item_id) returns (bool success) { }
}

contract SupplyCrateThree is Recipee {
  function ExecuteRecipee(uint64 this_item_id,
                          uint64 key_item_id) returns (bool success) {
    BackpackSystem backpack = BackpackSystem(msg.sender);

    // Make sure that the items are what they claim to be.
    if (backpack.GetItemDefindex(this_item_id) != 5045) return;
    if (backpack.GetItemDefindex(key_item_id) != 5021) return;

    // Why delete the previous items before granting the new item? Because
    // let's say that the users backpack is full at the time they execute the
    // recipee. We delete the previous two items to make room.
    backpack.DestroyItem(this_item_id);
    backpack.DestroyItem(key_item_id);

    // For now, we just hard grant "A Distinctive Lack of Hue"
    backpack.GrantNewItem(tx.origin, 5040, 5, 8);
  }
}

// Our simplified item system.
//
// A note on code organization: This contact should be kept to core, clean
// functionality. Any methods which cram multiple operations into a single
// message should go into BackpackSystemWithConvenienceMethods, which exists
// for those sorts of non-principled operations.
contract BackpackSystem {
  // A structure that keeps track of which items a user owns. Instead of
  // keeping the items on the user, it instead keeps track of the global item
  // ids.
  struct User {
    uint16 backpack_capacity;
    uint16 num_items;
    // TODO: This should be an array of 18 * 100, the maximum
    // capacity of a backpack in the first place.
    mapping (uint16 => uint64) item_ids;
  }

  function GetNumItems(address user) returns (uint16 count) {
    return user_backpacks[user].num_items;
  }

  function GetItemID(address user, uint16 position) returns (uint64 id) {
    return user_backpacks[user].item_ids[position];
  }

  // An individual item.
  //
  // Copying or modifying an item takes gas; to keep prices down, we diverge
  // from Valve's implementation in a few ways. First, frequently modifyed
  // state, such 'style' and 'inventory' are removed; they should be thought
  // of as local client state anyway. ('inventory' is documented to be
  // partially deprecated, and 'style' should be per loadout anyway so I can
  // have my Duck Journal set to each class' style.)
  //
  // Secondly, we only copy an item when transfering it from user to user; each
  // further application of a strange part, or a killstreak kit, or a name tag,
  // or whatnot becomes more costly, as it has to copy all previous state. We
  // replace the copying on own-user modification with a lock bit. Transactions
  // by a user are able to unlock an item, in which case other contracts are
  // able to then modify it. (If this is an important property, we could add
  // a redirection table, though.)
  struct ItemInstance {
    bool locked;

    // This item's current owner.
    address owner;

    // In addition to storing the owner, we also store the offset into the
    // owner's backpack which references this item.
    uint16 bp_position;

    uint64 item_id;
    uint64 original_id;
    uint32 defindex;
    uint16 level;
    uint16 quality;
    uint16 quantity;
    uint16 origin;

    // Might want to hoist marketability here. Also tradability, craftability, 
    // etc.

    // I want arrays. ;_;
    uint32 next_attribute_id;
    mapping (uint32 => uint64) int_attributes;
    // string attributes anyone?
  }

  // All items definitions are owned by the BackpackSystem.
  address owner;
  uint64 next_item_id;
  mapping (uint64 => ItemInstance) all_items;
  mapping (address => User) user_backpacks;

  // TODO: Figure out why function locals don't work here.
  SupplyCrateThree recipee;

  function BackpackSystem() {
    owner = msg.sender;
    // As a way of having items both on chain, and off chain, compromise and
    // say that the item ids are all off chain until item 4000000000, then all
    // even numbers are on chain, and all odd numbers are off chain.
    next_item_id = 4000000000;
    recipee = new SupplyCrateThree();
  }

  function CreateUser(address user) {
    if (msg.sender != owner) return;
    User u = user_backpacks[user];
    if (u.backpack_capacity == 0)
      u.backpack_capacity = 300;
  }

  function AddBackpackSpaceForUser(address user) {
    if (msg.sender != owner) return;
    User u = user_backpacks[user];
    if (u.backpack_capacity > 0 && u.backpack_capacity < 18000)
      u.backpack_capacity += 100;
  }

  // Creates an unlocked item
  function GrantNewItem(address user, uint32 defindex, uint16 quality,
                        uint16 origin) returns (uint64 item_id) {
    // TODO: Check a list of contracts that may grant items.
    uint16 level = 5; // TODO: Calculate this from defindex.

    User u = user_backpacks[user];
    if (u.backpack_capacity > 0 && u.num_items < u.backpack_capacity) {
      // Create a new item using the next item id.
      item_id = next_item_id;
      next_item_id += 2;
      ItemInstance i = all_items[item_id];
      i.owner = user;
      i.locked = false;
      i.item_id = item_id;
      i.original_id = item_id;
      i.defindex = defindex;
      i.level = level;
      i.quality = quality;
      i.quantity = 0;
      i.origin = origin;

      // Place a reference to this item in the users backpack.
      u.item_ids[u.num_items] = item_id;
      i.bp_position = u.num_items;
      u.num_items++;
    } else {
      item_id = 0;
    }
  }

  // Imports an item from off chain with |original_id| for |user|.
  function StartFullImportItem(address user, uint64 original_id,
                               uint32 defindex, uint16 level,
                               uint16 quality, uint16 origin)
           returns (uint64 item_id) {
    User u = user_backpacks[user];
    if (u.backpack_capacity > 0 && u.num_items < u.backpack_capacity) {
      // Create a new item using the next item id.
      item_id = next_item_id;
      next_item_id += 2;
      ItemInstance i = all_items[item_id];
      i.owner = user;
      i.locked = false;
      i.item_id = item_id;
      i.original_id = original_id;
      i.defindex = defindex;
      i.level = level;
      i.quality = quality;
      i.quantity = 0;
      i.origin = origin;

      // Place a reference to this item in the users backpack.
      u.item_ids[u.num_items] = item_id;
      i.bp_position = u.num_items;
      u.num_items++;
    } else {
      item_id = 0;
    }
  }

  function AddAttributeToUnlockedItem(uint64 item_id,
                                      uint32 attribute_id,
                                      uint64 value) {
    // TODO: Proper permissions here?
    if (all_items[item_id].locked == false) {
      // TODO: Need arrays to make the following iterable.
      all_items[item_id].int_attributes[attribute_id] = value;
    }
  }

  // Marks an item so that it will no longer be modifiable without first
  // unlocking it. (Can be performed by both the item owner, and the system
  // owner.)
  function LockItem(uint64 item_id) {
    if (all_items[item_id].item_id == item_id) {
      if (msg.sender != owner && tx.origin != all_items[item_id].owner)
        return;

      all_items[item_id].locked = true;
    }
  }

  // Unlocks an item for modification. Can only be initiated by the item owner.
  function UnlockItem(uint64 item_id) {
    if (IsInvalidUserActionForItem(item_id)) return;
    all_items[item_id].locked = false;
  }

  // Takes two item ids, assuming that the first is an item which has an
  // associated recipee, and the second is an item that will be consumed in the
  // process. We check to make sure the owner of each item is the sender first.
  // We then unlock each item, and then 
  //
  // TODO: Once we have arrays, we should turn this hard coded two item version
  // into a 200 slot version based on a per-user scratch space.
  function ExecuteItemRecipee(uint64 first_item_id, uint64 second_item_id) {
    if (IsInvalidUserActionForItem(first_item_id)) return;
    if (IsInvalidUserActionForItem(second_item_id)) return;

    all_items[first_item_id].locked = false;
    all_items[second_item_id].locked = false;

    // TODO: Look this up on the schema for |first_item_id|.
    recipee.ExecuteRecipee(first_item_id, second_item_id);

    // TODO: Tie locking/unlocking to the 200 slots and have a general relock
    // area command here. For now, we just assume that everything passed in is
    // consumed.
  }

  // Destroys an item. Can only be initiated by the item owner.
  function DestroyItem(uint64 item_id) {
    if (IsInvalidUserActionForItem(item_id)) return;
    address owner = all_items[item_id].owner;
    uint16 backpack_position = all_items[item_id].bp_position;
    delete all_items[item_id];

    // We also remove the reference to the now deleted item in the user's bp.
    User u = user_backpacks[owner];
    if (u.num_items > 1) {
      // Because we don't allow 'holes' in the bp to minimize scans, we take
      // the last item and move it to the deleted position.
      u.item_ids[backpack_position] = u.item_ids[u.num_items - 1];
      u.item_ids[u.num_items - 1] = 0;
    } else {
      u.item_ids[backpack_position] = 0;
    }

    u.num_items--;
  }

  function GetItemDefindex(uint64 item_id) returns (uint32 defindex) {
    return all_items[item_id].defindex;
  }

  // Checks if this is part of a transaction initiated by the owner.
  function IsInvalidUserActionForItem(uint64 item_id) private constant
      returns(bool invalid) {
    ItemInstance i = all_items[item_id];
    if (i.item_id == item_id) {
      invalid = tx.origin != i.owner;
    } else {
      invalid = false;
    }
  }
}

// This contract should only contain methods which combine multiple operations
// above into one method call to minimize gas price.
contract BackpackSystemWithConvenienceMethods is BackpackSystem {
  // Imports an item from off chain. Also locks the item.
  function QuickImportItem(address user, uint64 original_id, uint32 defindex,
                           uint16 level, uint16 quality, uint16 origin) {
    uint64 item_id = StartFullImportItem(user, original_id, defindex, level,
                                         quality, origin);
    LockItem(item_id);
  }

  function QuickImport2Items(address user,
                             uint64 one_original_id, uint32 one_defindex,
                             uint16 one_level, uint16 one_quality,
                             uint16 one_origin,
                             uint64 two_original_id, uint32 two_defindex,
                             uint16 two_level, uint16 two_quality,
                             uint16 two_origin) {
    uint64 item_id = StartFullImportItem(user, one_original_id, one_defindex,
                                         one_level, one_quality, one_origin);
    LockItem(item_id);

    item_id = StartFullImportItem(user, two_original_id, two_defindex,
                                  two_level, two_quality, two_origin);
    LockItem(item_id);
  }

  function QuickImportItemWith1Attribute(address user, uint64 original_id,
                                         uint32 defindex, uint16 level,
                                         uint16 quality, uint16 origin,
                                         uint32 attribute_id,
                                         uint64 attribute_value) {
    uint64 item_id = StartFullImportItem(user, original_id, defindex, level,
                                         quality, origin);
    AddAttributeToUnlockedItem(item_id, attribute_id, attribute_value);
    LockItem(item_id);
  }

  function QuickImportItemWith2Attributes(address user, uint64 original_id,
                                          uint32 defindex, uint16 level,
                                          uint16 quality, uint16 origin,
                                          uint32 one_attribute_id,
                                          uint64 one_attribute_value,
                                          uint32 two_attribute_id,
                                          uint64 two_attribute_value) {
    uint64 item_id = StartFullImportItem(user, original_id, defindex, level,
                                         quality, origin);
    AddAttributeToUnlockedItem(item_id, one_attribute_id, one_attribute_value);
    AddAttributeToUnlockedItem(item_id, two_attribute_id, two_attribute_value);
    LockItem(item_id);
  }

  function QuickImportItemWith3Attributes(address user, uint64 original_id,
                                          uint32 defindex, uint16 level,
                                          uint16 quality, uint16 origin,
                                          uint32 one_attribute_id,
                                          uint64 one_attribute_value,
                                          uint32 two_attribute_id,
                                          uint64 two_attribute_value,
                                          uint32 three_attribute_id,
                                          uint64 three_attribute_value) {
    uint64 item_id = StartFullImportItem(user, original_id, defindex, level,
                                         quality, origin);
    AddAttributeToUnlockedItem(item_id, one_attribute_id, one_attribute_value);
    AddAttributeToUnlockedItem(item_id, two_attribute_id, two_attribute_value);
    AddAttributeToUnlockedItem(item_id, three_attribute_id,
                               three_attribute_value);
    LockItem(item_id);
  }

  function StartFullImportItemWith3Attributes(address user, uint64 original_id,
                                              uint32 defindex, uint16 level,
                                              uint16 quality, uint16 origin,
                                              uint32 one_attribute_id,
                                              uint64 one_attribute_value,
                                              uint32 two_attribute_id,
                                              uint64 two_attribute_value,
                                              uint32 three_attribute_id,
                                              uint64 three_attribute_value)
           returns (uint64 item_id) {
    item_id = StartFullImportItem(user, original_id, defindex, level,
                                  quality, origin);
    AddAttributeToUnlockedItem(item_id, one_attribute_id, one_attribute_value);
    AddAttributeToUnlockedItem(item_id, two_attribute_id, two_attribute_value);
    AddAttributeToUnlockedItem(item_id, three_attribute_id,
                               three_attribute_value);
  }

  function Add2AttributesToUnlockedItem(uint64 item_id,
                                        uint32 one_attribute_id,
                                        uint64 one_value,
                                        uint32 two_attribute_id,
                                        uint64 two_value) {
    // TODO: Proper permissions here?
    if (all_items[item_id].locked == false) {
      // TODO: Need arrays to make the following iterable.
      all_items[item_id].int_attributes[one_attribute_id] = one_value;
      all_items[item_id].int_attributes[two_attribute_id] = two_value;
    }
  }

  function Add3AttributesToUnlockedItem(uint64 item_id,
                                        uint32 one_attribute_id,
                                        uint64 one_value,
                                        uint32 two_attribute_id,
                                        uint64 two_value,
                                        uint32 three_attribute_id,
                                        uint64 three_value) {
    // TODO: Proper permissions here?
    if (all_items[item_id].locked == false) {
      // TODO: Need arrays to make the following iterable.
      all_items[item_id].int_attributes[one_attribute_id] = one_value;
      all_items[item_id].int_attributes[two_attribute_id] = two_value;
      all_items[item_id].int_attributes[three_attribute_id] = three_value;
    }
  }

  function Add4AttributesToUnlockedItem(uint64 item_id,
                                        uint32 one_attribute_id,
                                        uint64 one_value,
                                        uint32 two_attribute_id,
                                        uint64 two_value,
                                        uint32 three_attribute_id,
                                        uint64 three_value,
                                        uint32 four_attribute_id,
                                        uint64 four_value) {
    // TODO: Proper permissions here?
    if (all_items[item_id].locked == false) {
      // TODO: Need arrays to make the following iterable.
      all_items[item_id].int_attributes[one_attribute_id] = one_value;
      all_items[item_id].int_attributes[two_attribute_id] = two_value;
      all_items[item_id].int_attributes[three_attribute_id] = three_value;
      all_items[item_id].int_attributes[four_attribute_id] = four_value;
    }
  }

  function Add5AttributesToUnlockedItem(uint64 item_id,
                                        uint32 one_attribute_id,
                                        uint64 one_value,
                                        uint32 two_attribute_id,
                                        uint64 two_value,
                                        uint32 three_attribute_id,
                                        uint64 three_value,
                                        uint32 four_attribute_id,
                                        uint64 four_value,
                                        uint32 five_attribute_id,
                                        uint64 five_value) {
    // TODO: Proper permissions here?
    if (all_items[item_id].locked == false) {
      // TODO: Need arrays to make the following iterable.
      all_items[item_id].int_attributes[one_attribute_id] = one_value;
      all_items[item_id].int_attributes[two_attribute_id] = two_value;
      all_items[item_id].int_attributes[three_attribute_id] = three_value;
      all_items[item_id].int_attributes[four_attribute_id] = four_value;
      all_items[item_id].int_attributes[five_attribute_id] = five_value;
    }
  }
}
