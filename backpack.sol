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

  function GetBackpackCapacityFor(address user) returns (uint16 capacity) {
    return user_data[user].backpack_capacity;
  }

  function BackpackSystem() {
    owner = msg.sender;
  }

  address private owner;
  mapping (address => User) private user_data;
}
