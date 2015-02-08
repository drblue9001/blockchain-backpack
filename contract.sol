// - The problem is that there are properties which are short and repeating (worth using a symbol over) and there are properties which are long pieces of text (More than string32). Figure this out.
// - In Valve's implementation, there are item properties which are strings.

contract SymbolTable {
  function SymbolTable() {
    address sender = msg.sender;
    owner = sender;
    next_symbol = 0;
  }

  function DefineSymbol(string32 str) returns (uint16 symbol) {
    address sender = msg.sender;
    if (sender != owner || string_to_symbol[str] != 0) return;
    next_symbol++;
    symbol_to_string[next_symbol] = str;
    string_to_symbol[str] = next_symbol;
  }

  function GetSymbolNumberFor(string32 str) constant returns (uint32 symbol) {
    return string_to_symbol[str];
  }

  function GetStringForSymbol(uint16 symbol) constant returns (string32 str) {
    return symbol_to_string[symbol];
  }
  
  address owner;
  uint32 next_symbol;
  // TODO: All these things should be changed to arrays.
  mapping (uint32 => string32) symbol_to_string;
  mapping (string32 => uint32) string_to_symbol;
}

contract GameSchema {	
  struct AttributeDefinition {
  	  string32 name;
  	  uint32 defindex;
  	  uint16 attribute_class;  // is a symbol id
    // TODO: Make this an array. Maps key names to values. This isn't really iterable.
  	  mapping (uint32 => string32) values;
  }

  function GameSchema() {
    address sender = msg.sender;
    owner = sender;
    table = new SymbolTable();
  }

  function SetAttributeDefinition(uint32 defindex, string32 name, uint16 attribute_class) {
  	  AttributeDefinition a = attributes[defindex];
  	  a.name = name;
  	  a.defindex = defindex;
  	  a.attribute_class = attribute_class;
  }
  
  function SetAttributeProperty(uint32 defindex, uint32 key, string32 value) {
  	  attributes[defindex].values[key] = value;
  }
    
  address owner;
  // TODO: Symbol table may collapse into two arrays.
  SymbolTable table;
  // TODO: This should be an array keyed on defindex.
  mapping (uint32 => AttributeDefinition) attributes;
  // TODO: 
}

// 
contract BackpackSystem {
  // User 
  struct User {
    uint16 backpack_capacity;
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

    mapping (uint32 => uint32) int_properties;
    mapping (uint32 => string32) str_properties;
    // attributes
  }

  // All items definitions are owned by the BackpackSystem.
  mapping (int64 => ItemInstance) all_items;
  mapping (address => User) user_backpacks;

  // function CreateItem(uint32 defindex, 


  function LockItem(uint32 id) {
    
  }
}

// Interesting note: In the raw_tf2_bp.json, my items have the
// attributes specified in the individual items. (ie, an instance of
// "The Cozy Camper" has attribute 57 first, which is the defindex
// of the health regen effect "health regen", which is the first
// attribute in the schema.
