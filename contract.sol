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

  function BackpackSystem() {
    owner = msg.sender;
    // As a way of having items both on chain, and off chain, compromise and
    // say that the item ids are all off chain until item 4000000000, then all
    // even numbers are on chain, and all odd numbers are off chain.
    next_item_id = 4000000000;
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

  // Imports an item from off chain. Also locks the item.
  function QuickImportItem(address user, uint64 original_id, uint32 defindex,
                           uint16 level, uint16 quality, uint16 origin) {
    uint64 item_id = StartFullImportItem(user, original_id, defindex, level,
                                         quality, origin);
    LockItem(item_id);
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

  function Add6AttributesToUnlockedItem(uint64 item_id,
                                        uint32 one_attribute_id,
                                        uint64 one_value,
                                        uint32 two_attribute_id,
                                        uint64 two_value,
                                        uint32 three_attribute_id,
                                        uint64 three_value,
                                        uint32 four_attribute_id,
                                        uint64 four_value,
                                        uint32 five_attribute_id,
                                        uint64 five_value,
                                        uint32 six_attribute_id,
                                        uint64 six_value) {
    // TODO: Proper permissions here?
    if (all_items[item_id].locked == false) {
      // TODO: Need arrays to make the following iterable.
      all_items[item_id].int_attributes[one_attribute_id] = one_value;
      all_items[item_id].int_attributes[two_attribute_id] = two_value;
      all_items[item_id].int_attributes[three_attribute_id] = three_value;
      all_items[item_id].int_attributes[four_attribute_id] = four_value;
      all_items[item_id].int_attributes[five_attribute_id] = five_value;
      all_items[item_id].int_attributes[six_attribute_id] = six_value;
    }
  }
}
