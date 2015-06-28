// An abstract recipee.
//
// TODO: This currently hard codes the idea of a single item as the argument
// so that we can get something working.
contract Recipee {
  function ExecuteRecipee(uint64 first_item_id,
                          uint64 second_item_id) returns (bool success) { }
}

// A contract which can have items unlocked for it. Contracts which have items
// unlocked for them should derive from this interface.
contract UnlockedItemHandler {
  function OnItemUnlocked(address backpack, uint64 item_id) {}
  function OnItemLocked(address backpack, uint64 item_id) {}
}

contract ExtensionContract {
  function ExtensionFunction(bytes32 name, uint64 item_id)
      returns (bytes32 message) {}
}

// Our simplified item system.
//
// A note on code organization: This contact should be kept to core, clean
// functionality. Any methods which cram multiple operations into a single
// message should go into BackpackSystemWithConvenienceMethods, which exists
// for those sorts of non-principled operations.
contract BackpackSystem {
  // TODO: In some far future where enums work in pyethereum, switch these to
  // enums.
  uint8 constant kPermissionSetPermission = 0;
  uint8 constant kPermissionBackpackCapacity = 1;
  uint8 constant kPermissionModifySchema = 2;
  uint8 constant kPermissionItemGrant = 3;
  uint8 constant kPermissionUnlockedItemModify = 4;

  uint constant kNumPermissions = 5;

  // A structure that keeps track of data about an address.
  //
  // At the top is a bunch of permissions that a user/contract might have, such
  // as granting items. These are probably going to be rarely set, but this
  // keeps all data about an address in one place.
  //
  // The rest of this struct keeps track of which items a user owns. Instead of
  // keeping the items on the user, it instead keeps track of the global item
  // ids.
  struct User {
    // Admin Permissions (all default to false).
    bool[5] permissions;

    // Users might not want to receive items from other players.
    bool allow_items_received;

    // Items owned (backpack capcity defaults to false).
    uint16 backpack_capacity;
    uint16 num_items;
    uint64[1800] item_ids;
  }

  function SetPermission(address user, uint8 permission, bool value)
      constant returns (bytes32 message) {
    if (HasPermission(msg.sender, kPermissionSetPermission)) {
      user_data[user].permissions[permission] = value;
      return "OK";
    } else {
      return "Permission Denied";
    }
  }

  function HasPermission(address user, uint8 permission)
      constant returns (bool value) {
    if (permission >= 5)
      return false;
    else if (user == owner)
      return true;
    else
      return user_data[user].permissions[permission];
  }

  function SetAllowItemsReceived(bool value) {
    if (user_data[msg.sender].backpack_capacity > 0)
      user_data[msg.sender].allow_items_received = value;
  }

  function AllowsItemsReceived(address user) constant returns (bool value) {
    return user_data[user].allow_items_received;
  }

  function GetNumItems(address user) constant returns (uint16 count) {
    return user_data[user].num_items;
  }

  function GetItemID(address user, uint16 position) constant
      returns (uint64 id) {
    return user_data[user].item_ids[position];
  }

  // An item schema.
  //
  // You can think of SchemaItems as classes to ItemInstances as objects. This
  // contains information about every object in TF2. In addition to the normal
  // data that goes here from the TF2 files, we also have our system of
  // contract recipees.
  struct SchemaItem {
    uint8 min_level;
    uint8 max_level;
    Recipee action_recipee;
    bytes32 name;
  }

  function SetItemSchema(uint32 defindex, uint8 min_level, uint8 max_level,
                         address action_recipee, bytes32 name)
      returns (bytes32 ret) {
    if (!HasPermission(msg.sender, kPermissionModifySchema))
      return "Permission Denied";

    SchemaItem schema = item_schemas[defindex];
    schema.min_level = min_level;
    schema.max_level = max_level;
    schema.action_recipee = Recipee(action_recipee);
    schema.name = name;
    return "OK";
  }

  uint32 constant kNumIntAttributes = 16;
  uint32 constant kNumStrAttributes = 4;

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
    // This item's current owner.
    address owner;

    // Each item can be unlocked by the |owner| for another account to operate
    // on the item. There can only be one |unlocked_for| address at a time. By
    // default, the |unlocked_for| account can "merely" also delete or give the
    // item away. If the contract has the additional
    // |unlocked_item_modify_permission|, it may also modify the item in some
    // way.
    address unlocked_for;

    // In addition to storing the owner, we also store the offset into the
    // owner's backpack which references this item.
    uint16 bp_position;

    uint64 item_id;
    uint64 original_id;
    uint32 defindex;
    uint8 level;
    uint16 quality;
    uint16 origin;

    // Implement expires.

    // Might want to hoist marketability here. Also tradability, craftability, 
    // etc.

    // TODO: Use constants here when that works.
    uint32[16] int_attribute_key;
    uint64[16] int_attribute_value;

    uint32[4] str_attribute_key;
    // TODO: bytes96 doesn't work anymore?
    bytes32[4] str_attribute_value;
  }

  // All items definitions are owned by the BackpackSystem.
  address private owner;
  uint64 private next_item_id;
  mapping (uint64 => ItemInstance) all_items;
  mapping (address => User) user_data;
  mapping (uint32 => SchemaItem) item_schemas;
  mapping (bytes32 => address) extension_contracts;

  function BackpackSystem() {
    owner = msg.sender;

    // As a way of having items both on chain, and off chain, compromise and
    // say that the item ids are all off chain until item 4000000000, then all
    // even numbers are on chain, and all odd numbers are off chain.
    next_item_id = 4000000000;
  }

  function CreateUser(address user) returns (bytes32 message) {
    if (!HasPermission(msg.sender, kPermissionBackpackCapacity))
      return "Permission Denied";

    User u = user_data[user];
    if (u.backpack_capacity == 0) {
      u.allow_items_received = true;
      u.backpack_capacity = 300;
      return "OK";
    }

    return "User already exists";
  }

  function AddBackpackSpaceForUser(address user) {
    if (!HasPermission(msg.sender, kPermissionBackpackCapacity)) return;

    User u = user_data[user];
    if (u.backpack_capacity > 0 && u.backpack_capacity < 1800) {
      u.backpack_capacity += 100;
    }
  }

  // Grant |unlocked_for| limited rights to give, delete, or (possibly) modify
  // |item_id|. May only be called directly by the owner.
  function UnockItemFor(uint64 item_id, address unlocked_for) {
    ItemInstance i = all_items[item_id];
    if (i.item_id == item_id) {
      if (msg.sender != i.owner)
        return;

      // If the item is already unlocked, lock it now. (If it's already locked
      // for |unlocked_for|, this will still send an OnItemUnlocked(), which
      // will be immediately relocked.)
      if (i.unlocked_for != 0) {
        address previous_locked_for = i.unlocked_for;
        i.unlocked_for = 0;
        UnlockedItemHandler(previous_locked_for).OnItemLocked(this, item_id);
      }

      i.unlocked_for = unlocked_for;

      UnlockedItemHandler(i.unlocked_for).OnItemUnlocked(this, item_id);
    }
  }

  // Locks the item again.
  function LockItem(uint64 item_id) {
    ItemInstance i = all_items[item_id];
    if (i.unlocked_for != 0) {
      // Only the owner and the current |unlocked_for| may relock an item.
      if (msg.sender != i.owner && msg.sender != i.unlocked_for)
        return;

      address previous_locked_for = i.unlocked_for;
      i.unlocked_for = 0;
      UnlockedItemHandler(previous_locked_for).OnItemLocked(this, item_id);
    }
  }

  // TODO(drblue): We should have a redirect table here.
  function GiveItemTo(uint64 item_id, address recipient) {
    ItemInstance old_item = all_items[item_id];
    if (old_item.owner == msg.sender || old_item.unlocked_for == msg.sender) {
      if (user_data[recipient].allow_items_received) {
        // If the item is unlocked, lock it.
        if (old_item.unlocked_for != 0) {
          address previous_locked_for = old_item.unlocked_for;
          old_item.unlocked_for = 0;
          UnlockedItemHandler(previous_locked_for).OnItemLocked(this, item_id);
        }

        // Create a new item with the 
        uint64 new_item_id = next_item_id;
        next_item_id += 2;

        ItemInstance new_item = all_items[new_item_id];
        new_item.owner = recipient;
        new_item.unlocked_for = 0;
        new_item.item_id = new_item_id;
        new_item.original_id = old_item.original_id;
        new_item.defindex = old_item.defindex;
        new_item.level = old_item.level;
        new_item.quality = old_item.quality;
        new_item.origin = old_item.origin;

        for (uint256 i = 0;
             i < kNumIntAttributes && old_item.int_attribute_key[i] != 0;
             ++i) {
          new_item.int_attribute_key[i] = old_item.int_attribute_key[i];
          new_item.int_attribute_value[i] = old_item.int_attribute_value[i];
        }

        for (i = 0;
             i < kNumStrAttributes && old_item.str_attribute_key[i] != 0;
             ++i) {
          new_item.str_attribute_key[i] = old_item.str_attribute_key[i];
          new_item.str_attribute_value[i] = old_item.str_attribute_value[i];
        }

        DestroyItem(item_id);
      }
    }
  }

  function SetIntAttribute(uint64 item_id, uint32 attribute_id,
                           uint64 value) returns (bool success) {
    ItemInstance item = all_items[item_id];
    if (item.unlocked_for == msg.sender &&
        HasPermission(msg.sender, kPermissionUnlockedItemModify)) {
      uint256 i = 0;
      while (i < kNumIntAttributes &&
             item.int_attribute_key[i] != 0) {
        if (item.int_attribute_key[i] == attribute_id) {
          item.int_attribute_value[i] = value;
          return true;
        }

        ++i;
      }

      if (i < kNumIntAttributes) {
        item.int_attribute_key[i] = attribute_id;
        item.int_attribute_value[i] = value;
        return true;
      }

      return false;
    }
  }

  function GetIntAttribute(uint64 item_id, uint32 attribute_id)
      returns (bool success, uint64 value) {
    ItemInstance item = all_items[item_id];
    success = false;
    value = 0;
    for (uint256 i = 0; i < kNumIntAttributes; ++i) {
      if (item.int_attribute_value[i] == attribute_id) {
        success = true;
        value = item.int_attribute_key[i];
        return;
      }
    }
  }

  // ------------------------------------------------------------------------

  // Execute an extension.
  function Exec(bytes32 name, uint64 item_id)
      returns (bytes32 message) {
    ItemInstance item = all_items[item_id];
    if (item.owner == msg.sender || item.unlocked_for == msg.sender) {
      ExtensionContract c = ExtensionContract(extension_contracts[name]);
      // TODO(drblue): You can't just implicitly unlock safely here.
      address previously_unlocked_for = item.unlocked_for;
      item.unlocked_for = c;
      message = c.ExtensionFunction(name, item_id);
      item.unlocked_for = previously_unlocked_for;
      return message;
    } else {
      return "";
    }
  }

  // Creates an unlocked item.
  function GrantNewItem(address user, uint32 defindex, uint16 quality,
                        uint16 origin) returns (uint64 item_id) {
    if (!HasPermission(msg.sender, kPermissionItemGrant)) return;

    SchemaItem schema = item_schemas[defindex];
    uint8 level = schema.min_level;
    if (schema.min_level != schema.max_level) {
      // The level doesn't need cryptographic randomness here. Just use the
      // prevhash.
      uint8 count = schema.max_level - schema.min_level;
      // This doesn't work. It just is always 0.
      level = uint8(uint256(block.blockhash(1)) % count) + schema.min_level;
    }

    User u = user_data[user];
    if (u.backpack_capacity > 0 && u.num_items < u.backpack_capacity) {
      // Create a new item using the next item id.
      item_id = next_item_id;
      next_item_id += 2;
      ItemInstance i = all_items[item_id];
      i.owner = user;
      i.unlocked_for = 0;
      i.item_id = item_id;
      i.original_id = item_id;
      i.defindex = defindex;
      i.level = level;
      i.quality = quality;
      i.origin = origin;

      // Place a reference to this item in the users backpack.
      u.item_ids[u.num_items] = item_id;
      i.bp_position = u.num_items;
      u.num_items++;
    } else {
      item_id = 0;
    }
  }

  // Destroys an item. Can only be initiated by the item owner.
  function DestroyItem(uint64 item_id) {
    if (IsInvalidUserActionForItem(item_id)) return;
    address owner = all_items[item_id].owner;
    uint16 backpack_position = all_items[item_id].bp_position;
    delete all_items[item_id];

    // TODO: We're not updating bp_position correctly here.

    // We also remove the reference to the now deleted item in the user's bp.
    User u = user_data[owner];
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

  function GetItemLevel(uint64 item_id) returns (uint8 level) {
    return all_items[item_id].level;
  }

  // Checks if this is part of a transaction initiated by the owner.
  function IsInvalidUserActionForItem(uint64 item_id) internal constant
      returns (bool invalid) {
    ItemInstance i = all_items[item_id];
    if (i.item_id == item_id) {
      invalid = tx.origin != i.owner;
    } else {
      invalid = false;
    }
  }
}
