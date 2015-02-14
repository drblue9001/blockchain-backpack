// Our simplified item system.
//
// TODO: There's a lot of places in this contract where we should make
// nonprincipled optimizations to make execution cheaper. Lots of users will
// already have a backpack size that should be imported, lots of items have
// no attributes (or only one), etc.
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
  // able to then modify it.
  struct ItemInstance {
    address owner;
    bool locked;

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

  // Imports an item from off chain with |original_id| for |user|.
  function FullImportItem(address user, uint64 original_id, uint32 defindex,
                          uint16 level, uint16 quality, uint16 origin)
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

  // Unlocks an item for modification. This can only be called from a
  // transaction initiated by the owner of the item.
  function UnlockItem(uint64 item_id) {
    if (all_items[item_id].item_id == item_id) {
      if (tx.origin != all_items[item_id].owner)
        return;

      all_items[item_id].locked = false;
    }
  }
}
