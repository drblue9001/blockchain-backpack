
// A contract which can have items unlocked for it. Contracts which have items
// unlocked for them should derive from this interface; you will receive
// these messages in response to events.
contract UnlockedItemHandler {
  function OnItemUnlocked(address backpack, uint64 item_id) {}
  function OnItemLocked(address backpack, uint64 item_id) {}
}


contract MutatingExtensionContract {
  function ExtensionFunction(bytes32 name, uint64[] item_id)
      external returns (bytes32 message) {}
}

// An extension contract whose entry point is constant (and therefore can run
// off blockchain).
contract ConstantExtensionContract {
  function ExtensionFunction(bytes32 name, uint64[] item_id) external constant
      returns (bytes32 message) {}
}


// Version 3 of the backpack system. This tries to make trading cheaper, and
contract NewBackpackSystem {
  // --------------------------------------------------------------------------
  // Part 1: Users and Permissions
  //
  // The User struct stores all data about an address. It stores a set of
  // permissions to actions that a contract might want to use, and stores the
  // IDs of items that the user owns.
  enum Permissions {
    SetPermission,
    BackpackCapacity,
    ModifySchema,
    GrantItems,
    AddAttributesToItem
  }
  uint constant kNumPermissions = 5;

  struct User {
    // Admin permissions (all default to false).
    bool[5] permissions;

    // Users might not want to receive items from other players.
    bool allow_items_received;

    // Items owned (backpack capcity defaults to false).
    uint16 backpack_capacity;
    uint16 num_items;
    uint64[1800] item_ids;
  }

  function SetPermission(address user, Permissions permission, bool value)
      constant returns (bytes32 message) {
    if (HasPermission(msg.sender, Permissions.SetPermission)) {
      user_data[user].permissions[uint256(permission)] = value;
      return "OK";
    } else {
      return "Permission Denied";
    }
  }

  function HasPermission(address user, Permissions permission)
      constant returns (bool value) {
    if (uint256(permission) >= kNumPermissions)
      return false;
    else if (user == owner)
      return true;
    else
      return user_data[user].permissions[uint256(permission)];
  }

  function SetAllowItemsReceived(bool value) {
    if (user_data[msg.sender].backpack_capacity > 0)
      user_data[msg.sender].allow_items_received = value;
  }

  function AllowsItemsReceived(address user) constant returns (bool value) {
    return user_data[user].allow_items_received;
  }

  // --------------------------------------------------------------------------
  // Part 2: Attributes
  //
  // ItemInstances and SchemaItems can have attributes. These attributes are
  // defined here.
  struct AttributeDefinition {
    // The attribute number. Nonzero if this attribute exists.
    uint32 defindex;

    // A mapping of strings in the system.
    mapping (bytes32 => bytes32) attribute_data;

    // TODO(drblue): Whether the value of this attribute can be set by someone
    // other than the owner.
  }

  function SetAttribute(uint32 defindex, bytes32 name, bytes32 value) {
    if (all_attributes[defindex].defindex == 0)
      all_attributes[defindex].defindex = defindex;
    all_attributes[defindex].attribute_data[name] = value;
  }

  // --------------------------------------------------------------------------
  // Part 3: Schema Items
  //
  // SchemaItem defines the shared characteristics of a group of items. You can
  // think of SchemaItems as classes to ItemInstance's objects.
  struct SchemaItem {
    uint8 min_level;
    uint8 max_level;
    MutatingExtensionContract recipee;

    mapping (uint32 => bytes32) str_attributes;
    mapping (uint32 => uint64) int_attributes;
  }

  function SetItemSchema(uint32 defindex, uint8 min_level, uint8 max_level,
                         address action_recipee)
      returns (bytes32 ret) {
    if (!HasPermission(msg.sender, Permissions.ModifySchema))
      return "Permission Denied";

    SchemaItem schema = item_schemas[defindex];
    schema.min_level = min_level;
    schema.max_level = max_level;
    schema.recipee = MutatingExtensionContract(action_recipee);
    return "OK";
  }

  // --------------------------------------------------------------------------
  // Part 3: Item Instances
  //
  // SchemaItem defines the shared characteristics of a group of items. You can
  // think of SchemaItems as classes to ItemInstance's objects.

  struct IntegerAttribute {
    // The attribute defindex that we're setting.
    uint32 defindex;

    // The new value.
    uint64 value;
  }

  struct StringAttribute {
    // The attribute defindex;
    uint32 defindex;

    // The new value.
    bytes32 value;
  }

  enum ItemState {
    // The default state; this item doesn't exist and the memory where this
    // item should be is zeroed out.
    DOEST_EXIST,
    // This item exists and is owned by someone.
    ITEM_EXISTS,
    // This item is currently being constructed and hasn't been finalized yet.
    UNDER_CONSTRUCTION
  }

  // This is take three at building an item database.
  //
  // We want to minimizes the data costs of making a new item, which can get
  // arbitrarily expensive once you start adding strange parts, custom text,
  // paints, strangifiers, killstream kits, Halloween spells, et cetera onto an
  // item. The longest method in the previous implementation was the one that
  // made a copy of an item.
  //
  // This new implementation instead keeps item history around and
  // accessible. This appears to be what Valve is doing (people who watch the
  // localization strings noticed that there's new strings describing an item's
  // history).
  //
  // The previous implementation also did not deal with support granted
  // duplicates of items. Item histories can really be a DAG instead of a
  // linked list, and this allows maintenence of the previous history.
  struct ItemInstance {
    // This is the owner of this item. This remains set even when the item
    // state is STATE_HISTORICAL, as an item's previous owners are part of its
    // history.
    address owner;

    // An address which may act on the owner's behalf. |unlocked_for| can only
    // be set by |owner|.
    address unlocked_for;

    // The current state of this item. For items which are currently owned by
    // someone, this is STATE_ITEM_EXISTS.
    ItemState state;

    // -- Why inline the next three uint16? To save space. All items have these
    // three properties and the world works on unprincipled excpetions and
    // hacks.

    // An item's level. This is (usually) a pseudorandom number between 1-100
    // as defined by the item schema. However, in Mann vs Machine, the item
    // level is set to a player's number of tours of duty, so it can be much
    // larger, hence a 16 bit integer.
    uint16 level;
    uint16 quality;
    uint16 origin;

    // -- End unprincipled exceptions.

    // The item type index.
    uint32 defindex;

    // 0 if this is the original instance of an item. If not, this is the
    // previous item id.
    uint64 original_id;

    // New values for this item.
    IntegerAttribute[] modified_int_attributes;
    StringAttribute[] modified_str_attributes;
  }

  function CreateNewItem(uint32 defindex, uint16 quality,
                         uint16 origin, address recipient) {
    if (HasPermission(msg.sender, Permissions.GrantItems)) {
      uint64 item_id = GetNextItemID();
      ItemInstance item = all_items[item_id];
      item.state = ItemState.UNDER_CONSTRUCTION;
      item.owner = recipient;
      item.unlocked_for = msg.sender;
      item.refcount = 1;
      item.level = 1; /* TODO(drblue): Do this. */
      item.quality = quality;
      item.origin = origin;
      item.defindex = defindex;
      item.original_id = item_id;

      // The item is left unfinalized and unlocked for the creator to possibly
      // add attributes and effects.
    }
  }

  function GiveItemTo(uint64 item_id, address recipient) {
    ItemInstance old_item = all_items[item_id];
    if (old_item.state == ItemState.ITEM_EXISTS &&
        (old_item.owner == msg.sender || old_item.unlocked_for == msg.sender)) {
      // This item must be locked if it is currently unlocked.
      EnsureLockedImpl(item_id);
      uint64 new_item_id = BuildNewItemCopyImpl(recipient, item_id);

      // The old item should be marked as historical.
      old_item.unlocked_for = 0;
      old_item.state = ItemState.HISTORICAL;

      // Giving an item to a recipient doesn't open it up for modification.
      FinalizeItem(new_item_id);

      // TODO(drblue): Finally, we remove |previous_item_id| from the previous
      // owner's backpack and add |new_item_id| to the recipient's backpack.
    }
  }

  function AddIntAttribute(uint64 item_id, uint32 attribute_id, uint64 value) {
    ItemInstance item = all_items[item_id];
    if (item.state == ItemState.UNDER_CONSTRUCTION &&
        item.unlocked_for == msg.sender &&
        HasPermission(msg.sender, Permissions.AddAttributesToItem)) {
      item.modified_int_attributes.length += 1;
      IntegerAttribute attr =
          item.modified_int_attributes[item.modified_int_attributes.length - 1];
      attr.defindex = attribute_id;
      attr.deleted = false;
      attr.value = value;
    }
  }

  function FinalizeItem(uint64 item_id) {
    ItemInstance item = all_items[item_id];
    if (item.state == ItemState.UNDER_CONSTRUCTION) {
      item.state = ItemState.ITEM_EXISTS;
      // Finalizing an item implicitly locks it.
      EnsureLockedImpl(item_id);
    }
  }

  function DeleteItem(uint64 item_id) {
    while (item_id != 0) {
      uint64 next_id = 0;
      ItemInstance item = all_items[item_id];
      if (item.refcount == 0) {
        // This should be impossible, but it satifies the static checker.
      } else if (item.refcount == 1) {
        next_id = item.previous_id;
        delete item.modified_int_attributes;
        delete item.modified_str_attributes;
        delete item;
      } else {
        // Multiple items refer to this historical item. Decrement the refcount
        // and take no further action.
        //
        // TODO(drblue): refcount overflow? If there are more than 255 references,
        // we shouldn't try to decrement this number; the history can no longer
        // be safely deleted.
        item.refcount--;
      }

      item_id = next_id;
    }
  }

  // Implementation detail which creates a new derived item owned by
  // |owner|. |previous_item_id| is the item id which we derive from. Caller is
  // responsible for changing the refcount of the old item.
  function BuildNewItemCopyImpl(address owner, uint64 previous_item_id) private
      returns(uint64 new_item_id) {
    new_item_id = GetNextItemID();

    ItemInstance new_item = all_items[new_item_id];
    ItemInstance old_item = all_items[previous_item_id];
    new_item.state = ItemState.UNDER_CONSTRUCTION;
    new_item.owner = old_item.owner;
    new_item.unlocked_for = old_item.unlocked_for;
    new_item.refcount = 1;
    new_item.level = old_item.level;
    new_item.quality = old_item.quality;
    new_item.origin = old_item.origin;
    new_item.defindex = old_item.defindex;
    new_item.previous_id = previous_item_id;

    return new_item_id;
  }

  function EnsureLockedImpl(uint64 item_id) private
      returns(address was_unlocked_for) {
    ItemInstance i = all_items[item_id];
    if (i.unlocked_for != 0) {
      was_unlocked_for = i.unlocked_for;
      i.unlocked_for = 0;
      UnlockedItemHandler(was_unlocked_for).OnItemLocked(this, item_id);
    } else {
      was_unlocked_for = 0;
    }
  }

  function GetNextItemID() private returns(uint64 new_item_id) {
    new_item_id = next_item_id;
    next_item_id += 2;
  }

  // --------------------------------------------------------------------------
  // Part 3: Contract extension functions
  //
  // The Backpack contract is the 

  // SchemaItem defines the shared characteristics of a group of items. You can
  // think of SchemaItems as classes to ItemInstance's objects.


// invariant:
  /// For every item which has a |previous_id|, items[previous_id].state should
  /// be STATE_HISTORICAL.

  /// For every item that .state == STATE_ITEM_EXISTS, it exists in only one
  /// backpack.

  /// Historical items should never be |unlocked_for| somebody. Items under
  /// construction should always be |unlocked_for| somebody.

  /// Ensure the corerspondance between item[].state and item[].refcount per
  /// the comments in the struct and enum.

// state:
  address private owner;
  uint64 private next_item_id;
  mapping (address => User) user_data;
  mapping (uint32 => AttributeDefinition) all_attributes;
  mapping (uint32 => SchemaItem) item_schemas;

  mapping (uint64 => ItemInstance) all_items;
}
