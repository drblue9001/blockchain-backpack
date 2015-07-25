// TODOs:
// - Look at changing permissions into a set of method modifiers.

// A contract which can have items unlocked for it. Contracts which have items
// unlocked for them should derive from this interface; you will receive
// these messages in response to events.
//
// Implementations of this must be very careful to not spend more than {10000}
// gas.
//
// TODO(drblue): Consider reasonable gas limits here.
contract UnlockedItemHandler {
  function OnItemUnlocked(address backpack, uint64 item_id) {}
  function OnItemLocked(address backpack, uint64 item_id) {}
}

// An extension contract which takes a list of item ids and 
contract MutatingExtensionContract {
  function MutatingExtensionFunction(uint64[] item_id)
      external returns (bytes32 message);
}

// Version 3 of the backpack system. This tries to make the cost of trading not
// depend on the number of attributes on an item.
contract Backpack {
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
    AddAttributesToItem,
    ModifiableAttribute
  }
  uint constant kNumPermissions = 6;

  struct User {
    // Admin permissions (all default to false).
    bool[6] permissions;

    // Users might not want to receive items from other players.
    bool allow_items_received;

    // The theoretical capacity of the backpack. This is aspirational instead
    // of a strict limit. Creating new items will always succeed, but items
    // won't be able to be transferred to a over capacity backpack. This is
    // important due to how we uncrate.
    uint32 backpack_capacity;

    // TODO(drblue): Switch this from being a statically sized array to an
    // unlimited array once either solc or pyethereum stop crapping out on
    // the following code:

    uint32 backpack_length;

    // An array of item ids. This can theorecitcally grow up to UINT32_MAX, but
    // will usually be significantly smaller.
    uint64[3200] item_ids;
  }

  function SetPermission(address user, Permissions permission, bool value)
      constant returns (bytes32) {
    if (HasPermission(msg.sender, Permissions.SetPermission)) {
      user_data[user].permissions[uint256(permission)] = value;
      return "OK";
    } else {
      return "Permission Denied";
    }
  }

  function HasPermission(address user, Permissions permission)
      constant returns (bool) {
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

  function AllowsItemsReceived(address user) constant returns (bool) {
    return user_data[user].allow_items_received;
  }

  function CreateUser(address user) returns (bytes32) {
    if (!HasPermission(msg.sender, Permissions.BackpackCapacity))
      return "Permission Denied";

    User u = user_data[user];
    if (u.backpack_capacity == 0) {
      u.allow_items_received = true;
      u.backpack_capacity = 300;
      return "OK";
    }

    return "User already exists";
  }

  function AddBackpackCapacityFor(address user) returns (bytes32) {
    if (!HasPermission(msg.sender, Permissions.BackpackCapacity))
      return "Permission Denied";

    User u = user_data[user];
    if (u.backpack_capacity > 0) {
      u.backpack_capacity += 100;
      return "OK";
    }

    return "User not found.";
  }

  function GetBackpackCapacityFor(address user) constant
      returns (uint32 capacity) {
    return user_data[user].backpack_capacity;
  }

  function GetNumberOfItemsOwnedFor(address user) constant returns (uint) {
    return user_data[user].backpack_length;
  }

  function GetItemIdFromBackpack(address user, uint32 i) constant
      returns (uint64) {
    return user_data[user].item_ids[i];
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

    // Whether users with Permissions.ModifiableAttribute can modify this
    // attribute. For security reasons, this is a default value and is stored
    // per attribute on items which receive this attribute. modifiable
    // attributes may not be placed on schema items.
    bool modifiable;
  }

  function SetAttribute(uint32 defindex, bytes32 name, bytes32 value)
      returns (bytes32) {
    if (!HasPermission(msg.sender, Permissions.ModifySchema))
      return "Permission Denied";
    if (defindex == 0)
      return "Invalid Attribute";
    if (all_attributes[defindex].defindex == 0)
      all_attributes[defindex].defindex = defindex;
    all_attributes[defindex].attribute_data[name] = value;
    return "OK";
  }

  function SetAttributeModifiable(uint32 defindex, bool modifiable)
      returns (bytes32) {
    if (!HasPermission(msg.sender, Permissions.ModifySchema))
      return "Permission Denied";
    if (defindex == 0)
      return "Invalid Attribute";
    if (all_attributes[defindex].defindex == 0)
      all_attributes[defindex].defindex = defindex;
    all_attributes[defindex].modifiable = modifiable;
    return "OK";
  }

  function GetAttribute(uint32 defindex, bytes32 name) returns (bytes32) {
    return all_attributes[defindex].attribute_data[name];
  }

  // Storage for an IntegerAttribute on a SchemaItem or an ItemInstance.
  struct IntegerAttribute {
    // The attribute defindex that we're setting.
    uint32 defindex;

    // The new value.
    uint64 value;

    // Whether this attribute is modifiable. This value is copied from the
    // attribute definition at the time the attribute is set on an item
    // instance. These values are not settable on ItemSchemas.
    bool modifiable;
  }

  struct StringAttribute {
    // The attribute defindex;
    uint32 defindex;

    // The new value.
    bytes32 value;
  }

  // --------------------------------------------------------------------------
  // Part 3: Schema Items
  //
  // SchemaItem defines the shared characteristics of a group of items. You can
  // think of SchemaItems as classes to ItemInstance's objects.
  struct SchemaItem {
    uint8 min_level;
    uint8 max_level;
    MutatingExtensionContract recipe;

    // New values for this item.
    IntegerAttribute[] int_attributes;
    StringAttribute[] str_attributes;
  }

  function SetItemSchema(uint32 defindex, uint8 min_level, uint8 max_level,
                         address action_recipe)
      returns (bytes32 ret) {
    if (!HasPermission(msg.sender, Permissions.ModifySchema))
      return "Permission Denied";

    SchemaItem schema = item_schemas[defindex];
    schema.min_level = min_level;
    schema.max_level = max_level;
    schema.recipe = MutatingExtensionContract(action_recipe);
    return "OK";
  }

  function GetItemLevelRange(uint32 defindex) returns (uint8 min, uint8 max) {
    SchemaItem schema = item_schemas[defindex];
    min = schema.min_level;
    max = schema.max_level;
  }

  function AddIntAttributeToItemSchema(uint32 item_defindex,
                                       uint32 attribute_defindex,
                                       uint64 value) returns (bytes32) {
    if (!HasPermission(msg.sender, Permissions.ModifySchema))
      return "Permission Denied";
    if (all_attributes[attribute_defindex].defindex == 0)
      return "Invalid Attribute";

    SchemaItem schema = item_schemas[item_defindex];
    SetIntAttributeImpl(schema.int_attributes, attribute_defindex, value);
    return "OK";
  }

  // --------------------------------------------------------------------------
  // Part 3: Item Instances
  //
  // SchemaItem defines the shared characteristics of a group of items. You can
  // think of SchemaItems as classes to ItemInstance's objects.
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
  // Items have both a private internal id 0 based, and the id referred to
  // externally, which should be in the same numeric namespace as the rest of
  // Valve's item servers.
  struct ItemInstance {
    // The current item id. This changes each time the item is modified or
    // changes hands.
    uint64 id;

    // This is the owner of this item.
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

    // The original id this item was created with.
    uint64 original_id;

    // New values for this item.
    IntegerAttribute[] int_attributes;
    StringAttribute[] str_attributes;
  }

  // This is the main method which is used to make new items. As long as the
  // caller has permission, it always succeeds regardless if the user's
  // backpack is over capacity or not. This function returns the item id of the
  // created item or 0 is there was an error.
  function CreateNewItem(uint32 defindex, uint16 quality,
                         uint16 origin, address recipient) returns (uint64) {
    if (!HasPermission(msg.sender, Permissions.GrantItems))
      return 0;

    // The item defindex is not defined!
    SchemaItem schema = item_schemas[defindex];
    if (schema.min_level == 0)
      return 0;

    // TODO(drblue): Calculate level.
    return CreateItemImpl(defindex, quality, origin, recipient,
                          msg.sender /* unlocked_for */,
                          schema.min_level /* level */,
                          0 /* original_id */);
  }

  // The lower level item creation function and is optimized for creation of
  // items which already exist off chain, though it can be used for any fine
  // tune building of an item. If |attribute_key| is non zero, we optimize a
  // call to 
  function ImportItem(address recipient,
                      uint32 defindex,
                      uint16 quality,
                      uint16 origin,
                      uint16 level,
                      uint64 original_id) external
      returns (uint64) {
    // calculate items
    if (!HasPermission(msg.sender, Permissions.GrantItems))
      return 0;

    // The item defindex is not defined!
    SchemaItem schema = item_schemas[defindex];
    if (schema.min_level == 0)
      return 0;

    return CreateItemImpl(defindex, quality, origin, recipient,
                          msg.sender, level, original_id);
  }

  // When |item_id| exists, and the item is unlocked for the caller and the
  // caller has Permissions.AddAttributesToItem, create a new item number for
  // this item and return it. Otherwise returns 0.
  function OpenForModification(uint64 item_id) returns (uint64) {
    if (!HasPermission(msg.sender, Permissions.AddAttributesToItem))
      return 1;

    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return 2;

    ItemInstance item = item_storage[internal_id];
    if (item.state == ItemState.ITEM_EXISTS &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      EnsureLockedImpl(internal_id, item_id);

      delete all_items[item_id];

      uint64 new_item_id = GetNextItemID();
      item.id = new_item_id;
      item.state = ItemState.UNDER_CONSTRUCTION;
      all_items[new_item_id] = internal_id;

      User u = user_data[item.owner];
      for (uint32 i = 0; i < u.backpack_length; ++i) {
        if (u.item_ids[i] == item_id) {
          u.item_ids[i] = new_item_id;
          break;
        }
      }

      // Because we locked the item before, we now unlock the new item for the
      // sender.
      EnsureUnlockedImpl(internal_id, new_item_id, msg.sender);

      return new_item_id;
    }

    return 3;
  }

  function GiveItemTo(uint64 item_id, address recipient) returns (uint64) {
    // Ensure the recipient has space.
    User u = user_data[recipient];
    if (u.backpack_length >= u.backpack_capacity)
      return 0;

    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return 0;

    ItemInstance item = item_storage[internal_id];
    if (item.state == ItemState.ITEM_EXISTS &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      EnsureLockedImpl(internal_id, item_id);

      // Clean up references to the previous |item_id|.
      RemoveItemIdFromBackpackImpl(item_id, item.owner);
      delete all_items[item_id];

      uint64 new_item_id = GetNextItemID();
      item.id = new_item_id;
      item.owner = recipient;
      all_items[new_item_id] = internal_id;
      AddItemIdToBackpackImpl(new_item_id, recipient);
      return new_item_id;
    }

    return 0;
  }

  function SetIntAttribute(uint64 item_id,
                           uint32 attribute_defindex,
                           uint64 value) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    ItemInstance item = item_storage[internal_id];
    if (item.state == ItemState.UNDER_CONSTRUCTION &&
        HasPermission(msg.sender, Permissions.AddAttributesToItem) &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      SetIntAttributeImpl(item.int_attributes, attribute_defindex, value);
    }
  }

  function SetIntAttributes(uint64 item_id,
                            uint32[] keys,
                            uint64[] values) external {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    if (keys.length != values.length)
      return;

    ItemInstance item = item_storage[internal_id];
    if (item.state == ItemState.UNDER_CONSTRUCTION &&
        HasPermission(msg.sender, Permissions.AddAttributesToItem) &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      for (uint i = 0; i < keys.length; ++i) {
        SetIntAttributeImpl(item.int_attributes, keys[i], values[i]);
      }
    }
  }

  /// @notice If `item_id` is currently under construction, this switches the
  /// item to exists.
  function FinalizeItem(uint64 item_id) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    ItemInstance item = item_storage[internal_id];
    if (item.state == ItemState.UNDER_CONSTRUCTION &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      EnsureLockedImpl(internal_id, item_id);
      item.state = ItemState.ITEM_EXISTS;
    }
  }

  /// @notice Unlocks `item_id` for the address `c`.
  function UnlockItemFor(uint64 item_id, address c) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    ItemInstance item = item_storage[internal_id];
    if (item.state == ItemState.ITEM_EXISTS &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      EnsureUnlockedImpl(internal_id, item_id, c);
    }
  }

  /// @notice If `item_id` is unlocked, this relocks it.
  function LockItem(uint64 item_id) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    ItemInstance item = item_storage[internal_id];
    if (item.owner == msg.sender || item.unlocked_for == msg.sender)
      EnsureLockedImpl(internal_id, item_id);
  }

  function DeleteItem(uint64 item_id) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    ItemInstance item = item_storage[internal_id];
    if (item.owner == msg.sender || item.unlocked_for == msg.sender) {
      EnsureLockedImpl(internal_id, item_id);

      RemoveItemIdFromBackpackImpl(item_id, item.owner);

      // Delete the actual item.
      delete item_storage[internal_id];
      delete all_items[item_id];
    }
  }

  function GetItemData(uint64 item_id) constant
      returns (uint32 defindex, address owner, uint16 level,
               uint16 quality, uint16 origin, uint64 original_id) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    ItemInstance item = item_storage[internal_id];
    defindex = item.defindex;
    owner = item.owner;
    level = item.level;
    quality = item.quality;
    origin = item.origin;
    original_id = item.original_id;
  }

  function GetItemDefindex(uint64 item_id) constant returns (uint32) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    ItemInstance item = item_storage[internal_id];
    return item.defindex;
  }

  function GetItemLength(uint64 item_id) constant returns (uint256 count) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    ItemInstance item = item_storage[internal_id];
    return item.int_attributes.length;
  }

  function GetItemIntAttribute(uint64 item_id, uint32 defindex) constant
      returns (uint64 value) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    // Iterate through all the items and change the value if we already see a
    // value for this defindex.
    ItemInstance item = item_storage[internal_id];
    for (uint i = 0; i < item.int_attributes.length; ++i) {
      IntegerAttribute attr = item.int_attributes[i];
      if (attr.defindex == defindex) {
        return attr.value;
      }
    }

    // The item might have an attribute as part of its schema, which we fall
    // back on when we don't have an explicit value set.
    SchemaItem schema = item_schemas[item.defindex];
    for (i = 0; i < schema.int_attributes.length; ++i) {
      attr = schema.int_attributes[i];
      if (attr.defindex == defindex) {
        return attr.value;
      }
    }

    return 0;
  }

  /// @notice Uses `item_ids[0]`, unlocking and passing the rest of the items
  /// to the items use contract.
  function UseItem(uint64[] item_ids) returns (bytes32 message) {
    if (item_ids.length == 0)
      return "No items given";

    // Verify that item_ids[0] has a contract associated with its item.
    uint32 contract_schema_defindex = GetItemDefindex(item_ids[0]);
    SchemaItem contract_schema = item_schemas[contract_schema_defindex];
    address recipe = contract_schema.recipe;
    if (recipe == 0)
      return "Item 0 has no recipe";

    // Verify that every input item exists
    for (uint i = 0; i < item_ids.length; ++i) {
      uint256 internal_id = all_items[item_ids[i]];
      if (internal_id == 0)
        return "Input item doesn't exist";

      /* TODO(drblue): Need to also verify that everything is owned by the caller
       * here. */
    }

    // For every item in item_ids, ensure that it is locked (we're probably
    // going to be modifying or deleting many of these items), and then do a
    // local unlock for the recipe.
    for (i = 0; i < item_ids.length; ++i) {
      internal_id = all_items[item_ids[i]];
      EnsureLockedImpl(internal_id, item_ids[i]);
      UnlockItemFor(item_ids[i], recipe);
    }

    // Actually run the contract.
    message =
        MutatingExtensionContract(recipe).MutatingExtensionFunction(item_ids);

    // Finally, iterate over all item_ids. Of the ones that still exist, ensure
    // that they are locked.
    for (i = 0; i < item_ids.length; ++i) {
      internal_id = all_items[item_ids[i]];
      if (internal_id != 0)
        EnsureLockedImpl(internal_id, item_ids[i]);
    }
  }

  // --------------------------------------------------------------------------

  function GetNextItemID() private returns(uint64 new_item_id) {
    new_item_id = next_item_id;
    next_item_id += 2;
  }

  function CreateItemImpl(uint32 defindex, uint16 quality,
                          uint16 origin, address recipient,
                          address unlocked_for,
                          uint16 level,
                          uint64 original_id) private
      returns (uint64) {
    uint64 item_id = GetNextItemID();

    uint256 next_internal_id = item_storage.length;
    item_storage.length++;
    ItemInstance item =  item_storage[next_internal_id];
    item.id = item_id;
    item.owner = recipient;
    item.unlocked_for = unlocked_for;
    item.state = ItemState.UNDER_CONSTRUCTION;
    item.level = level;
    item.quality = quality;
    item.origin = origin;
    item.defindex = defindex;
    if (original_id == 0)
      item.original_id = item_id;
    else
      item.original_id = original_id;

    all_items[item_id] = next_internal_id;

    // Note that CreateNewItem always succeeds, up to the item limit.
    AddItemIdToBackpackImpl(item_id, recipient);

    // The item is left unfinalized and unlocked for the creator to possibly
    // add attributes and effects.
    return item_id;
  }

  function SetIntAttributeImpl(IntegerAttribute[] storage int_attributes,
                               uint32 attribute_defindex,
                               uint64 value) private {
    // Verify that attribute_defindex is defined.
    AttributeDefinition a = all_attributes[attribute_defindex];
    if (a.defindex != attribute_defindex)
      return;

    // Iterate through all the items and change the value if we already see a
    // value for this defindex.
    uint i = 0;
    for (i = 0; i < int_attributes.length; ++i) {
      IntegerAttribute attr = int_attributes[i];
      if (attr.defindex == attribute_defindex) {
        attr.value = value;
        attr.modifiable = a.modifiable;
        return;
      }
    }

    // We didn't find a preexisting attribute. Add one.
    int_attributes.length++;
    attr = int_attributes[int_attributes.length - 1];
    attr.defindex = attribute_defindex;
    attr.value = value;
    attr.modifiable = a.modifiable;
  }

  function AddItemIdToBackpackImpl(uint64 item_id, address recipient) private {
    User u = user_data[recipient];
    u.item_ids[u.backpack_length] = item_id;
    u.backpack_length++;
  }

  function RemoveItemIdFromBackpackImpl(uint64 item_id, address owner) private {
    // Walk the owners backpack, looking for the reference to the item. When we
    // find it, remove it.
    User u = user_data[owner];
    for (uint32 i = 0; i < u.backpack_length; ++i) {
      if (u.item_ids[i] == item_id) {
        if (i == u.backpack_length - 1) {
          // We are the last item in the item list.
          u.item_ids[i] = 0;
        } else {
          // We take the last item in the backpack list and move it here
          u.item_ids[i] = u.item_ids[u.backpack_length - 1];
          u.item_ids[u.backpack_length - 1] = 0;
        }

        u.backpack_length--;
        break;
      }
    }
  }

  function EnsureLockedImpl(uint256 internal_id, uint64 item_id) private
      returns(address was_unlocked_for) {
    ItemInstance i = item_storage[internal_id];
    if (i.unlocked_for != 0) {
      was_unlocked_for = i.unlocked_for;
      i.unlocked_for = 0;
      // We don't send notification messages during item construction.
      if (i.state != ItemState.UNDER_CONSTRUCTION) {
        // TODO(drblue): This should have a .gas(10000) to limit the transaction,
        // but we can't do that yet. pyethereum complains with "Transaction
        // Failed" and no other error message.
        UnlockedItemHandler(was_unlocked_for).OnItemLocked(this, item_id);
      }
    } else {
      was_unlocked_for = 0;
    }
  }

  function EnsureUnlockedImpl(uint256 internal_id, uint64 item_id,
                              address unlocked_for) private {
    item_storage[internal_id].unlocked_for = unlocked_for;

    // TODO(drblue): This should have a .gas(10000) to limit the transaction,
    // but we can't do that yet. pyethereum complains with "Transaction
    // Failed" and no other error message.
    UnlockedItemHandler(unlocked_for).OnItemUnlocked(this, item_id);
  }

  function Backpack() {
    owner = msg.sender;

    // We put a single null item in the front of |item_storage| so that we can
    // ensure that 0 is an invalid item storage.
    item_storage.length = 1;

    // As a way of having items both on chain, and off chain, compromise and
    // say that the item ids are all off chain until item 4000000000, then all
    // even numbers are on chain, and all odd numbers are off chain.
    next_item_id = 4000000000;
  }

  address private owner;
  uint64 private next_item_id;
  mapping (address => User) private user_data;

  // Maps attribute defindex to attribute definitions.
  mapping (uint32 => AttributeDefinition) private all_attributes;

  // Maps item defindex to the schema definition.
  mapping (uint32 => SchemaItem) private item_schemas;

  // 0 indexed storage of items.
  ItemInstance[] private item_storage;

  // Maps item ids to internal storage ids.
  mapping (uint64 => uint256) private all_items;
}

/* -------------------------------------------------------------------------- */
/* PaintCan                                                                   */
/* -------------------------------------------------------------------------- */

contract PaintCan is MutatingExtensionContract {
  function MutatingExtensionFunction(uint64[] item_ids)
      external returns (bytes32 message) {
    Backpack backpack = Backpack(msg.sender);

    if (item_ids.length != 2) return "Wrong number of arguments";

    // "set item tint RGB" is defindex 142.
    uint64 tint_rgb = backpack.GetItemIntAttribute(item_ids[0], 142);
    if (tint_rgb == 0)
      return "First item not a paint can.";

    // TODO(drblue): Get a real attribute number for
    // "capabilities": { "paintable" }
    uint64 is_paintable = backpack.GetItemIntAttribute(item_ids[1], 999999);
    if (is_paintable == 0)
      return "Second item not paintable";

    // Create a new item number since we're making modifications to the item.
    uint64 new_item = backpack.OpenForModification(item_ids[1]);
    backpack.SetIntAttribute(new_item, 142, tint_rgb);

    // Team dependent paints set a second attribute.
    // ""set item tint RGB 2" is defindex 261.
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
