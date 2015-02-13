
// 
contract BackpackSystem {
  // User 
  struct User {
    uint16 backpack_capacity;
    uint16 num_items;
    // TODO: This should be an array of 18 * 100, the maximum
    // capacity of a backpack in the first place.
    mapping (uint16 => uint64) item_ids;
  }

  struct ItemInstance {
    // All items start off unlocked. This allows for modification by
    // the backpack system. Items are built up and then locked.
    bool locked;

    uint64 item_id;
    uint64 original_id;
    uint32 defindex;
    uint16 level;
    uint16 quality;
    uint16 quantity;
    uint16 origin;

    // Ignoring 'style' and 'inventory', which aren't part of the item, but
    // are client state.

    // Might want to hoist marketability here.

    // I want arrays. ;_;
    uint32 next_attribute_id;
    mapping (uint32 => uint64) int_attributes;
    // string attributes anyone?
    // attributes
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

  function ImportItem(address user, uint64 original_id, uint32 defindex,
                      uint16 level, uint16 quality, uint16 origin)
           returns (uint64 item_id) {
    User u = user_backpacks[user];
    if (u.backpack_capacity > 0 && u.num_items < u.backpack_capacity) {
      // Create a new item using the next item id.
      item_id = next_item_id;
      next_item_id += 2;
      ItemInstance i = all_items[item_id];
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
  
  function LockItem(uint64 item_id) {
    // Wait, I don't think we can safely use tx.origin here. (Think throught
    // the implications here.)
    if (msg.sender != owner) return;

    if (all_items[item_id].item_id == item_id)
      all_items[item_id].locked = true;
  }
}
