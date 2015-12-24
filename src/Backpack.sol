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

// An extension contract which takes a list of item ids and returns a message.
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

  function HasPermissionInt(address user, uint32 permission)
      constant returns (bool) {
    return HasPermission(user, Permissions(permission));
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

  // --------------------------------------------------------------------------
  // Part 2: Attributes
  //
  // ItemInstances and SchemaItems can have attributes. These attributes are
  // defined here.
  struct AttributeDefinition {
    // Whether users with Permissions.ModifiableAttribute can modify this
    // attribute. For security reasons, this is a default value and is stored
    // per attribute on items which receive this attribute. modifiable
    // attributes may not be placed on schema items.
    bool modifiable;
  }

  function SetAttributeModifiable(uint32 defindex, bool modifiable)
      returns (bytes32) {
    if (!HasPermission(msg.sender, Permissions.ModifySchema))
      return "Permission Denied";
    if (defindex == 0)
      return "Invalid Attribute";
    all_attributes[defindex].modifiable = modifiable;
    return "OK";
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

    SchemaItem schema = item_schemas[item_defindex];
    SetIntAttributeImpl(schema.int_attributes, attribute_defindex, value);
    return "OK";
  }

  // --------------------------------------------------------------------------
  // Part 3: Item Instances
  //
  // 

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

  event ItemCreated(address indexed owner,
                    uint64 indexed id,
                    uint64 original_id,
                    uint32 defindex,
                    uint16 level,
                    uint16 quality,
                    uint16 origin);

  event ItemTransformed(address indexed owner,
                        uint64 indexed id,
                        uint64 indexed old_id);
  event ItemGive(address indexed owner,
                 address new_owner,
                 uint64 indexed id,
                 uint64 indexed old_id);

  event ItemSetIntAttribute(uint64 indexed id,
                            uint32 attribute_defindex,
                            uint64 value);
  event ItemRemoveIntAttribute(uint64 indexed id,
                               uint32 attribute_defindex);

  event ItemSetStrAttribute(uint64 indexed id,
                            uint32 attribute_defindex,
                            string value);

  event ItemDeleted(address indexed owner,
                    uint64 indexed id);

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

    // The item type index.
    uint32 defindex;
  }

  // Used to create new items. If the caller has permission to make new items,
  // create one with the following properties and put it in the under
  // construction state. Returns the item id or 0 if error.
  //
  // (Requires Permissions.GrantItems.)
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
      uint256 range = schema.max_level - schema.min_level + 1;
      level += uint16(uint256(block.blockhash(block.number - 1)) % range);
    }

    return CreateItemImpl(defindex, quality, origin, recipient,
                          msg.sender /* unlocked_for */,
                          level /* level */,
                          0 /* original_id */);
  }

  // Used to import an existing, off-chain item, which already has a |level|
  // and an |original_id|. Item is returned in the under construction
  // state. Returns the new item id or 0 if error.
  //
  // (Requires Permissions.GrantItems.)
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

  // When |item_id| exists, and the item is unlocked for the caller, create a
  // new item number for this item, put it in the under construction state, and
  // return it. Otherwise returns 0.
  //
  // (Requires Permissions.AddAttributesToItem.)
  function OpenForModification(uint64 item_id) returns (uint64) {
    if (!HasPermission(msg.sender, Permissions.AddAttributesToItem))
      return 0;

    ItemInstance item = new_all_items[item_id];
    if (item.state == ItemState.ITEM_EXISTS &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      item.unlocked_for = 0;

      uint64 new_item_id = GetNextItemID();

      ItemTransformed(item.owner, new_item_id, item.id);

      ItemInstance new_item = new_all_items[new_item_id];
      new_item.id = new_item_id;
      new_item.owner = item.owner;
      new_item.unlocked_for = msg.sender;
      new_item.state = ItemState.UNDER_CONSTRUCTION;
      new_item.defindex = item.defindex;

      // Opening an item for modification doesn't change any IDs.

      delete new_all_items[item_id];

      return new_item_id;
    }

    return 0;
  }

  // Give the item to recipient. This will generate a new |item_id|. Returns
  // the new |item_id|.
  //
  // (May only be called by the item's owner or unlocked_for.)
  function GiveItemTo(uint64 item_id, address recipient) returns (uint64) {
    // Ensure the recipient has space.
    User u = user_data[recipient];
    if (u.backpack_length >= u.backpack_capacity)
      return 0;

    ItemInstance item = new_all_items[item_id];
    if (item.state == ItemState.ITEM_EXISTS &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      user_data[item.owner].backpack_length--;

      uint64 new_item_id = GetNextItemID();
      ItemGive(recipient, item.owner, new_item_id, item.id);

      ItemInstance new_item = new_all_items[new_item_id];
      new_item.id = new_item_id;
      new_item.owner = recipient;
      new_item.unlocked_for = 0;
      new_item.state = ItemState.ITEM_EXISTS;
      new_item.defindex = item.defindex;

      u.backpack_length++;

      delete new_all_items[item_id];

      return new_item_id;
    }

    return 0;
  }

  // Adds an integer attribute to an item in the under construction state.
  //
  // (Requires Permissions.AddAttributesToItem.)
  function SetIntAttribute(uint64 item_id,
                           uint32 attribute_defindex,
                           uint64 value) {
    ItemInstance item = new_all_items[item_id];
    if (item.state == ItemState.UNDER_CONSTRUCTION &&
        HasPermission(msg.sender, Permissions.AddAttributesToItem) &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      ItemSetIntAttribute(item_id, attribute_defindex, value);
    }
  }

  function SetIntAttributes(uint64 item_id,
                            uint32[] keys,
                            uint64[] values) external {
    if (keys.length != values.length)
      return;

    ItemInstance item = new_all_items[item_id];
    if (item.state == ItemState.UNDER_CONSTRUCTION &&
        HasPermission(msg.sender, Permissions.AddAttributesToItem) &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      for (uint i = 0; i < keys.length; ++i) {
        ItemSetIntAttribute(item_id, keys[i], values[i]);
      }
    }
  }

  function RemoveIntAttribute(uint64 item_id, uint32 attribute_defindex) {
    ItemInstance item = new_all_items[item_id];
    if (item.state == ItemState.UNDER_CONSTRUCTION &&
        HasPermission(msg.sender, Permissions.AddAttributesToItem) &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      ItemRemoveIntAttribute(item_id, attribute_defindex);
    }
  }

  function SetStrAttribute(uint64 item_id,
                           uint32 attribute_defindex,
                           string value) {
    ItemInstance item = new_all_items[item_id];
    if (item.state == ItemState.UNDER_CONSTRUCTION &&
        HasPermission(msg.sender, Permissions.AddAttributesToItem) &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      ItemSetStrAttribute(item_id, attribute_defindex, value);
    }
  }

  // Marks an item in the under construction state as finalized. No further
  // modifications can be made to this item.
  function FinalizeItem(uint64 item_id) {
    ItemInstance item = new_all_items[item_id];
    if (item.state == ItemState.UNDER_CONSTRUCTION &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      item.unlocked_for = 0;
      item.state = ItemState.ITEM_EXISTS;
    }
  }

  // Allows |user| to temporarily act as the |item_id|'s owner.
  //
  // (May only be called by |item_id|'s owner.)
  function UnlockItemFor(uint64 item_id, address user) {
    ItemInstance item = new_all_items[item_id];
    if (item.state == ItemState.ITEM_EXISTS && item.owner == msg.sender)
      item.unlocked_for = user;
  }

  // Revokes access to |item_id| by the address that current can act as
  // |item_id|'s owner.
  //
  // (May be called by |item_id|'s owner, or the current address temporarily
  // acting as the item's owner.)
  function LockItem(uint64 item_id) {
    ItemInstance item = new_all_items[item_id];
    if (item.owner == msg.sender || item.unlocked_for == msg.sender)
      item.unlocked_for = 0;
  }

  // Deletes the item.
  //
  // (May only be called by the item's owner or unlocked_for.)
  function DeleteItem(uint64 item_id) {
    ItemInstance item = new_all_items[item_id];
    if (item.owner == msg.sender || item.unlocked_for == msg.sender) {
      item.unlocked_for = 0;

      user_data[item.owner].backpack_length--;

      ItemDeleted(item.owner, item.id);

      // Delete the actual item.
      delete new_all_items[item_id];
    }
  }

  function GetItemData(uint64 item_id) constant
      returns (uint32 defindex, address owner) {
    ItemInstance item = new_all_items[item_id];
    defindex = item.defindex;
    owner = item.owner;
  }

  function GetItemDefindex(uint64 item_id) constant returns (uint32) {
    ItemInstance item = new_all_items[item_id];
    return item.defindex;
  }

  function GetItemOwner(uint64 item_id) constant returns (address owner) {
    ItemInstance item = new_all_items[item_id];
    return item.owner;
  }

  function CanGiveItem(uint64 item_id) constant returns (bool) {
    ItemInstance item = new_all_items[item_id];
    return item.state == ItemState.ITEM_EXISTS &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender);
  }

  /* TODO(drblue): Rename this method since it now accesses just schema data. */
  function GetItemIntAttribute(uint64 item_id, uint32 defindex) constant
      returns (uint64 value) {
    // The item might have an attribute as part of its schema, which we fall
    // back on when we don't have an explicit value set.
    ItemInstance item = new_all_items[item_id];
    SchemaItem schema = item_schemas[item.defindex];
    for (uint i = 0; i < schema.int_attributes.length; ++i) {
      IntegerAttribute attr = schema.int_attributes[i];
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

  // Adds |amount| to the current value of |attribute_defindex| on |item_id|.
  // |attribute_defindex| must have been set as a modifiable attribute at the
  // time the attribute was originally set on this object. The caller must have
  // Permissions.ModifiableAttribute, or this method does nothing.
  function AddToModifiable(uint64 item_id,
                           uint32 attribute_defindex,
                           uint32 amount) {
    if (!HasPermission(msg.sender, Permissions.ModifiableAttribute))
      return;

    /* TODO(drblue): Punting for now; must deal with the new world. */

    // AddToModifiable can only be used to modify existing attributes. Invalid
    // input.
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

    ItemInstance item = new_all_items[item_id];
    item.id = item_id;
    item.owner = recipient;
    item.unlocked_for = unlocked_for;
    item.state = ItemState.UNDER_CONSTRUCTION;
    item.defindex = defindex;

    if (original_id == 0)
      original_id = item_id;

    ItemCreated(recipient, item_id, original_id,
                defindex, level, quality, origin);

    // Note that CreateNewItem always succeeds, even if it bumps past the item
    // limit.
    user_data[recipient].backpack_length++;

    // The item is left unfinalized and unlocked for the creator to possibly
    // add attributes and effects.
    return item_id;
  }

  function SetIntAttributeImpl(IntegerAttribute[] storage int_attributes,
                               uint32 attribute_defindex,
                               uint64 value) private {
    // Verify that attribute_defindex is defined.
    AttributeDefinition a = all_attributes[attribute_defindex];

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

  function DoActionImpl(address owner, uint64[] item_ids, address action)
      private returns (bytes32 message) {
    // Verify that every input item exists and is owned by caller.
    for (uint i = 0; i < item_ids.length; ++i) {
      ItemInstance item = new_all_items[item_ids[i]];
      if (item.owner != owner)
        return "Sender does not own item.";
    }

    // For every item in item_ids, ensure that it is unlocked for the action.
    for (i = 0; i < item_ids.length; ++i)
      new_all_items[item_ids[i]].unlocked_for = action;

    // Actually run the contract.
    message =
        MutatingExtensionContract(action).MutatingExtensionFunction(item_ids);

    // Finally, iterate over all item_ids. Of the ones that still exist, ensure
    // that they are locked.
    for (i = 0; i < item_ids.length; ++i) {
      item = new_all_items[item_ids[i]];
      if (item.id == item_ids[i])
        item.unlocked_for = 0;
    }
  }

  function Backpack() {
    owner = msg.sender;

    // As a way of having items both on chain, and off chain, compromise and
    // say that the item ids are all off chain until item 5000000000, then all
    // even numbers are on chain, and all odd numbers are off chain.
    next_item_id = 5000000000;
  }

  address private owner;
  uint64 private next_item_id;
  mapping (address => User) private user_data;

  // Maps attribute defindex to attribute definitions.
  mapping (uint32 => AttributeDefinition) private all_attributes;

  // Maps item defindex to the schema definition.
  mapping (uint32 => SchemaItem) private item_schemas;

  mapping (uint64 => ItemInstance) private new_all_items;

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

    // Verify that all |their_items| belong to |user_two|.
    for (i = 0; i < their_items.length; ++i) {
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
        DeleteTradeImpl(trade_id);
        return;
      }
    }
    for (i = 0; i < t.user_two_items.length; ++i) {
      if (backpack.CanGiveItem(t.user_two_items[i]) != true) {
        DeleteTradeImpl(trade_id);
        return;
      }
    }

    if (!backpack.AllowsItemsReceived(t.user_one) ||
        !backpack.AllowsItemsReceived(t.user_two)) {
      DeleteTradeImpl(trade_id);
      return;
    }

    // There's a whole lot of validity checking stuff that needs to be done
    //  here for a real implementation. (Like whether the items will fit in
    //  each user's backpack.)  This loop swaps items back and forth. It is
    //  still not the most optimized implementation and does not deal with the
    //  case where both backpacks are full. However, it is good enough for
    //  demonstration purposes.

    uint length = t.user_one_items.length;
    if (t.user_two_items.length > length)
      length = t.user_two_items.length;
    for (i = 0; i < length; ++i) {
      if (i < t.user_one_items.length)
        backpack.GiveItemTo(t.user_one_items[i], t.user_two);
      if (i < t.user_two_items.length)
        backpack.GiveItemTo(t.user_two_items[i], t.user_one);
    }

    DeleteTradeImpl(trade_id);
  }

  function RejectTrade(uint256 trade_id) {
    Trade t = trades[trade_id];
    if (msg.sender != t.user_two)
      return;

    DeleteTradeImpl(trade_id);
  }

  function TradeCoordinator(Backpack system) {
    backpack = system;
    trades.length = 1;
  }

  function DeleteTradeImpl(uint256 trade_id) private {
    Trade t = trades[trade_id];
    delete t.user_one_items;
    delete t.user_two_items;
    delete trades[trade_id];
  }

  Backpack backpack;
  Trade[] trades;
}

/* -------------------------------------------------------------------------- */
/* Crate                                                                      */
/* -------------------------------------------------------------------------- */

// Contract execution in Ethereum is purely deterministic; a person must be
// able to examine the blockchain and see that there's one canonical valid
// state. So any random number generation that we do must be psuedorandom and
// deterministic, while still being resistant to manipulation by the user.
//
// When we "uncrate", we are making a precommitment to open a crate in the
// future.
contract Crate is MutatingExtensionContract {
  struct RollID {
    uint offset;
    uint blockheight;
    address user;
  }

  // Calling the crating contract through the UseItem interface will destroy
  // the key and the crate, and put a precommitment to roll two blocks into the
  // future.
  function MutatingExtensionFunction(uint64[] item_ids)
      external returns (bytes32 message) {
    if (msg.sender != address(backpack))
      return "Invalid caller";

    // Verify that we were given a crate and key.
    if (item_ids.length != 2)
      return "Wrong number of arguments";
    if ((backpack.GetItemDefindex(item_ids[0]) != 5022) ||
        (backpack.GetItemDefindex(item_ids[1]) != 5021))
      return "Incorrect items passed";

    uint blockheight = block.number + 2;
    uint[] precommitments = precommitments_per_block_number[blockheight];

    uint roll_id = open_rolls.length++;
    RollID r = open_rolls[roll_id];
    r.offset = precommitments.length;
    r.blockheight = blockheight;
    r.user = backpack.GetItemOwner(item_ids[0]);

    // Add to the list of precommitments.
    uint i = precommitments.length++;
    precommitments[i] = roll_id;

    backpack.DeleteItem(item_ids[0]);
    backpack.DeleteItem(item_ids[1]);

    return "OK";
  }

  function PerformUncrate(uint roll_id) external returns (bytes32 message) {
    RollID r = open_rolls[roll_id];
    if ((r.blockheight == 0) ||
        (block.number < r.blockheight + 1) ||
        (block.number > r.blockheight + 255 - 2)) {
      return "Wrong block height";
    }

    uint roll = GetRandom(r.blockheight, r.offset) % 9;
    uint64 new_id = backpack.CreateNewItem(item_ids[roll], 6, 8, r.user);
    backpack.FinalizeItem(new_id);
    // TODO(drblue): delete r and remove from prpecommitments per block number.
    return "OK";
  }

  function GetRandom(uint blockheight, uint offset)
      internal returns (uint random) {
    return uint(sha256(block.blockhash(blockheight - 1), block.blockhash(blockheight), offset));
  }

  function Crate(Backpack system) {
    backpack = system;

    item_ids[0] = 175;      // Vita-Saw
    item_ids[1] = 142;      // Gunslinger
    item_ids[2] = 128;      // Equalizer
    item_ids[3] = 130;      // Scottish Resistance
    item_ids[4] = 247;      // Old Guadalajara
    item_ids[5] = 248;      // Napper's Respite
    item_ids[6] = 5020;     // Name Tag
    item_ids[7] = 5039;     // An Extraordinary Abundance of Tinge
    item_ids[8] = 5040;     // A Distinctive Lack of Hue
  }

  Backpack backpack;
  uint32[9] item_ids;
  RollID[] open_rolls;
  mapping (uint => uint[]) precommitments_per_block_number;
}

contract Deployer {
  function LoadSchema(uint32[] defindex, uint8[] min_level, uint8[] max_level) {
    if (!bp.HasPermissionInt(msg.sender, 2))
      return;

    for (uint i = 0; i < defindex.length; ++i) {
      bp.SetItemSchema(defindex[i], min_level[i], max_level[i], 0);
    }
  }

  function ImportItem(uint32 defindex,
                      uint16 quality,
                      uint16 origin,
                      uint16 level,
                      uint64 original_id,
                      address recipient,
                      uint32[] keys,
                      uint64[] values) returns (uint64 id) {
    if (!bp.HasPermissionInt(msg.sender, 3))
      return 0;

    id = bp.ImportItem(defindex, quality, origin, level, original_id,
                       recipient);
    bp.SetIntAttributes(id, keys, values);
    bp.FinalizeItem(id);
  }

  function ImportItemWithAString(uint32 defindex,
                                 uint16 quality,
                                 uint16 origin,
                                 uint16 level,
                                 uint64 original_id,
                                 address recipient,
                                 uint32[] keys,
                                 uint64[] values,
                                 uint32 str_key,
                                 string str_value) returns (uint64 id) {
    if (!bp.HasPermissionInt(msg.sender, 3))
      return 0;

    id = bp.ImportItem(defindex, quality, origin, level, original_id,
                       recipient);
    bp.SetIntAttributes(id, keys, values);
    bp.SetStrAttribute(id, str_key, str_value);
    // Leave the item open for further modification.
  }

  function ImportSimpleItems(uint32[] defindex,
                             uint16[] quality,
                             uint16[] origin,
                             uint16[] level,
                             uint64[] original_id,
                             address recipient) {
    if (!bp.HasPermissionInt(msg.sender, 3))
      return;

    for (uint i = 0; i < defindex.length; ++i) {
      uint64 id = bp.ImportItem(defindex[i], quality[i], origin[i], level[i],
                                original_id[i], recipient);
      bp.FinalizeItem(id);
    }
  }

  function Deployer(Backpack system) {
    bp = system;
  }

  Backpack bp;
}
