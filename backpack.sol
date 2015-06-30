//


// TODOs:
// - Look at changing permissions into a set of modifiers.



// An extension contract which takes a list of item ids and 
contract MutatingExtensionContract {
  function ExtensionFunction(bytes32 name, uint64[] item_id)
      external returns (bytes32 message);
}

// Version 3 of the backpack system. This tries to make the cost of trading not
// depend on the number of attributes on an item.
contract BackpackSystem {
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
    schema.int_attributes[attribute_defindex] = value;
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

    // Whether this attribute is modifyable. This value is copied from the
    // attribute definition at the time the attribute is set on an item
    // instance.
    bool modifyable;
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
  // Items have both a private internal id 0 based, and the id referred to
  // externally, which should be in the same numeric namespace as the rest of
  // Valve's item servers.
  struct ItemInstance {
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

    // 0 if this is the original instance of an item. If not, this is the
    // previous item id.
    uint64 original_id;

    // New values for this item.
    IntegerAttribute[] int_attributes;
    StringAttribute[] str_attributes;
  }

  // This is the main method which is used to make new items. As long as the
  // caller has permission, it always succeeds regardless if the user's
  // backpack is over capacity or not.
  function CreateNewItem(uint32 defindex, uint16 quality,
                         uint16 origin, address recipient) {
    if (!HasPermission(msg.sender, Permissions.GrantItems))
      return;

    // The item defindex is not defined!
    SchemaItem schema = item_schemas[defindex];
    if (schema.min_level == 0)
      return;

    uint64 item_id = GetNextItemID();

    uint256 next_internal_id = item_storage.length;
    item_storage.length++;
    ItemInstance item =  item_storage[next_internal_id];
    item.state = ItemState.UNDER_CONSTRUCTION;
    item.owner = recipient;
    item.unlocked_for = msg.sender;
    item.level = schema.min_level;          // TODO(drblue): Calculate level.
    item.quality = quality;
    item.origin = origin;
    item.defindex = defindex;
    item.original_id = item_id;

    all_items[item_id] = next_internal_id;

    // Note that CreateNewItem always succeeds, up to the item limit.
    User u = user_data[recipient];
    u.item_ids[u.backpack_length] = item_id;
    u.backpack_length++;

    // The item is left unfinalized and unlocked for the creator to possibly
    // add attributes and effects.
  }

  function GiveItemTo(uint64 item_id, address recipient) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    ItemInstance item = item_storage[internal_id];
    if (item.state == ItemState.ITEM_EXISTS &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      // Ensure Locked.


      // Finalize.

      // Remove |previous_item_id| from backpack. Add new item id to backpack.
    }
  }

  // function AddIntAttribute()

  function FinalizeItem(uint64 item_id) {
    uint256 internal_id = all_items[item_id];
    if (internal_id == 0)
      return;

    ItemInstance item = item_storage[internal_id];
    if (item.state == ItemState.UNDER_CONSTRUCTION &&
        (item.owner == msg.sender || item.unlocked_for == msg.sender)) {
      item.state = ItemState.ITEM_EXISTS;
      // Finalizing an item implicitly locks it.
      // EnsureLockedImpl(item_id);
    }
  }

  // function DeleteItem(uint64) {  }

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

  function GetNextItemID() private returns(uint64 new_item_id) {
    new_item_id = next_item_id;
    next_item_id += 2;
  }


  // --------------------------------------------------------------------------


  function BackpackSystem() {
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
  mapping (uint32 => SchemaItem) item_schemas;

  // 0 indexed storage of items.
  ItemInstance[] item_storage;

  // Maps item ids to internal storage ids.
  mapping (uint64 => uint256) all_items;
}
