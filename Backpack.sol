// Copyright 2015 Dr. Blue.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
      returns (bytes32) {
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
    MutatingExtensionContract on_use_contract;

    // New values for this item.
    IntegerAttribute[] int_attributes;
    StringAttribute[] str_attributes;
  }

  function SetItemSchema(uint32 defindex, uint8 min_level, uint8 max_level,
                         address use_contract)
      returns (bytes32 ret) {
    if (!HasPermission(msg.sender, Permissions.ModifySchema))
      return "Permission Denied";

    SchemaItem schema = item_schemas[defindex];
    schema.min_level = min_level;
    schema.max_level = max_level;
    schema.on_use_contract = MutatingExtensionContract(use_contract);
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

    // Calculate the level. It is OK to use non-secure psuedorandom numbers
    // here because the item level is purely decorational thing that isn't seen
    // most of the time and manipulation isn't worth miners colluding. (Unlike
    // uncrating, where we have to use the pre-commitment trick.)
    uint16 level = schema.min_level;
    if (schema.min_level != schema.max_level) {
      // TODO(drblue): It appears that in pyethereum tester, blockhash(0) is a
      // constant. This doesn't appear to be the case on the main clients.
      uint256 range = schema.max_level - schema.min_level;
      level = uint16(uint256(block.blockhash(0)) % range);
    }

    return CreateItemImpl(defindex, quality, origin, recipient,
                          msg.sender /* unlocked_for */,
                          level /* level */,
                          0 /* original_id */);
  }

  // The lower level item creation function and is optimized for creation of
  // items which already exist off chain, though it can be used for any fine
  // tune building of an item. If |attribute_key| is non zero, we optimize a
  // call to 
  function ImportItem(uint32 defindex,
                      uint16 quality,
                      uint16 origin,
                      uint16 level,
                      uint64 original_id,
                      address recipient) external
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
      return 0;

    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return 0;

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

    return 0;
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

  function RemoveIntAttribute(uint64 item_id, uint32 attribute_defindex) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    ItemInstance item = item_storage[internal_id];
    if (item.state == ItemState.UNDER_CONSTRUCTION &&
        HasPermission(msg.sender, Permissions.AddAttributesToItem) &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      // Verify that attribute_defindex is defined.
      AttributeDefinition a = all_attributes[attribute_defindex];
      if (a.defindex != attribute_defindex)
        return;

      // Iterate through all the items and change the value if we already see a
      // value for this defindex.
      uint i = 0;
      uint last = item.int_attributes.length - 1;
      for (i = 0; i < item.int_attributes.length; ++i) {
        IntegerAttribute attr = item.int_attributes[i];
        if (attr.defindex == attribute_defindex) {
          // If we are not the last item in the list, we copy the last item in
          // the list to where we are so we don't have holes.
          if (i != last)
            attr = item.int_attributes[last];

          item.int_attributes.length--;
          return;
        }
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
    if (item.state == ItemState.ITEM_EXISTS && item.owner == msg.sender)
      EnsureUnlockedImpl(internal_id, item_id, c);
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

  function GetItemOwner(uint64 item_id) constant returns (address owner) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    ItemInstance item = item_storage[internal_id];
    return item.owner;
  }

  function CanGiveItem(uint64 item_id) constant returns (bool) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return false;

    ItemInstance item = item_storage[internal_id];
    return item.state == ItemState.ITEM_EXISTS &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender);
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
    address action = contract_schema.on_use_contract;
    if (action == 0)
      return "Item 0 has no recipe";

    return DoActionImpl(msg.sender, item_ids, action);
  }

  function SetAction(bytes32 name, address recipe) {
    if (!HasPermission(msg.sender, Permissions.ModifySchema))
      return;

    actions[name] = recipe;
  }

  function DoAction(bytes32 name, uint64[] item_ids)
      returns (bytes32 message) {
    // Note: Unlike UseItem, we don't enforce item_ids to contain anything.

    // Find the action recipe from |name|.
    address action = actions[name];
    if (action == 0)
      return "No such action.";

    return DoActionImpl(msg.sender, item_ids, action);
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

  function DoActionImpl(address owner, uint64[] item_ids, address action)
      private returns (bytes32 message) {
    // Verify that every input item exists and is owned by caller.
    for (uint i = 0; i < item_ids.length; ++i) {
      uint256 internal_id = all_items[item_ids[i]];
      if (internal_id == 0)
        return "Input item doesn't exist";

      ItemInstance item = item_storage[internal_id];
      if (item.owner != owner)
        return "Sender does not own item.";
    }

    // For every item in item_ids, ensure that it is locked (we're probably
    // going to be modifying or deleting many of these items), and then do a
    // local unlock for the action.
    for (i = 0; i < item_ids.length; ++i) {
      internal_id = all_items[item_ids[i]];
      EnsureLockedImpl(internal_id, item_ids[i]);
      UnlockItemFor(item_ids[i], action);
    }

    // Actually run the contract.
    message =
        MutatingExtensionContract(action).MutatingExtensionFunction(item_ids);

    // Finally, iterate over all item_ids. Of the ones that still exist, ensure
    // that they are locked.
    for (i = 0; i < item_ids.length; ++i) {
      internal_id = all_items[item_ids[i]];
      if (internal_id != 0)
        EnsureLockedImpl(internal_id, item_ids[i]);
    }
  }

  function EnsureLockedImpl(uint256 internal_id, uint64 item_id) private
      returns(address was_unlocked_for) {
    ItemInstance i = item_storage[internal_id];
    if (i.unlocked_for != 0) {
      was_unlocked_for = i.unlocked_for;
      i.unlocked_for = 0;
    } else {
      was_unlocked_for = 0;
    }
  }

  function EnsureUnlockedImpl(uint256 internal_id, uint64 item_id,
                              address unlocked_for) private {
    item_storage[internal_id].unlocked_for = unlocked_for;
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

  // Extension contracts.
  mapping (bytes32 => address) private actions;
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

/* -------------------------------------------------------------------------- */
/* RestorePaintJob                                                            */
/* -------------------------------------------------------------------------- */

contract RestorePaintJob is MutatingExtensionContract {
  function MutatingExtensionFunction(uint64[] item_ids)
      external returns (bytes32 message) {
    Backpack backpack = Backpack(msg.sender);

    if (item_ids.length != 1) return "Wrong number of arguments";

    // "set item tint RGB" is defindex 142.
    uint64 tint_rgb = backpack.GetItemIntAttribute(item_ids[0], 142);
    if (tint_rgb == 0)
      return "Item isn't painted";

    uint64 new_item = backpack.OpenForModification(item_ids[0]);
    if (new_item == 0)
      return "Failed to open for modification";

    backpack.RemoveIntAttribute(new_item, 142);
    backpack.RemoveIntAttribute(new_item, 261);
    backpack.FinalizeItem(new_item);

    return "OK";
  }
}

/* -------------------------------------------------------------------------- */
/* TradeCoordinator                                                           */
/* -------------------------------------------------------------------------- */

// TODO: Think about using events. Think about spam a bit more.
contract TradeCoordinator {
  struct Trade {
    address user_one;
    address user_two;
    uint64[] user_one_items;
    uint64[] user_two_items;
  }

  function ProposeTrade(uint64[] my_items,
                        address user_two,
                        uint64[] their_items)
      returns (uint trade_id) {
    uint i;
    for (i = 0; i < my_items.length; ++i) {
      // Verify this item belongs to the sender.
      if (backpack.GetItemOwner(my_items[i]) != msg.sender)
        return 0;
      // Verify this item is in a state where we can give it away.
      if (backpack.CanGiveItem(my_items[i]) != true)
        return 0;
    }

    // Verify that all |their_items| belong to |user_two| single person.
    for (i = 0; i < their_items.length; ++i) {
      // Verify this item belongs to |user_two|.
      if (backpack.GetItemOwner(their_items[i]) != user_two)
        return 0;
    }

    // Get the next trade number
    trade_id = trades.length;
    trades.length++;
    Trade t = trades[trade_id];
    t.user_one = msg.sender;
    t.user_two = user_two;
    t.user_one_items = my_items;
    t.user_two_items = their_items;
  }

  function AcceptTrade(uint256 trade_id) {
    Trade t = trades[trade_id];
    if (msg.sender != t.user_two)
      return;

    // We need to recheck the validity of the trade before we accept it.
    uint i;
    for (i = 0; i < t.user_one_items.length; ++i) {
      if (backpack.CanGiveItem(t.user_one_items[i]) != true) {
        RejectTradeImpl(trade_id);
        return;
      }
    }
    for (i = 0; i < t.user_two_items.length; ++i) {
      if (backpack.CanGiveItem(t.user_two_items[i]) != true) {
        RejectTradeImpl(trade_id);
        return;
      }
    }

    if (!backpack.AllowsItemsReceived(t.user_one) ||
        !backpack.AllowsItemsReceived(t.user_two)) {
      RejectTradeImpl(trade_id);
      return;
    }

    /* TODO(drblue): There's a whole bunch of validity checking stuff that we need
     * to do here. Like whether the items will fit in each user's backpack.
     */

    // This loop swaps items back and forth. It is still not the most optimized
    // implementation and does not deal with the case where both backpacks are
    // full. However, it is good enough for demonstration purposes.
    uint length = t.user_one_items.length;
    if (t.user_two_items.length > length)
      length = t.user_two_items.length;
    for (i = 0; i < length; ++i) {
      if (i < t.user_one_items.length)
        backpack.GiveItemTo(t.user_one_items[i], t.user_two);
      if (i < t.user_two_items.length)
        backpack.GiveItemTo(t.user_two_items[i], t.user_one);
    }
  }

  function RejectTrade(uint256 trade_id) {
    Trade t = trades[trade_id];
    if (msg.sender != t.user_two)
      return;

    RejectTradeImpl(trade_id);
  }

  function TradeCoordinator(Backpack system) {
    backpack = system;
    trades.length = 1;
  }

  function RejectTradeImpl(uint256 trade_id) private {
    Trade t = trades[trade_id];
    delete t.user_one_items;
    delete t.user_two_items;
    delete trades[trade_id];
  }

  Backpack backpack;
  Trade[] trades;
}
