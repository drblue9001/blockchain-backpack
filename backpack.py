#!/usr/bin/python

import json
from pyethereum import tester

print "Loading schema..."
schema_file = open('tf2_schema.json')
schema_json = json.load(schema_file)['result']

# When parsing the schema, the index into the array schema_json['items'] does
# not match the 'defindex' position. So build up a defindex dictionary. (Since
# I don't think I can guarenetee that all defindexes are accounted for?)
attributes_by_defindex = {}
attributes_by_name = {}
items_by_defindex = {}
for item in schema_json['items']:
  defindex = item['defindex']
  items_by_defindex[defindex] = item
for a in schema_json['attributes']:
  defindex = a['defindex']
  attributes_by_defindex[defindex] = a
  attributes_by_name[a['name']] = a

print "Loaded %d item definitions." % len(schema_json['items'])
# TODO(drblue): Do more parsing on the schema file.


# Create the Backpack contract
print "Creating ethereum context..."
s = tester.state()
contract_file = open('contract.sol')
c = s.abi_contract(contract_file.read(), language='solidity')

print "Loading backpack..."
bp_file = open('raw_tf2_bp.json')
backpack_json = json.load(bp_file)['result']
print "Loaded %d items from backpack." % len(backpack_json['items'])

# Create a user and add backpack slots until the backpack is the correct size.
c.CreateUser(65)
num_slots = backpack_json['num_backpack_slots']
times_to_add_backpack_space = (num_slots - 300) / 100
for _ in range(times_to_add_backpack_space):
  c.AddBackpackSpaceForUser(65)

for item in backpack_json['items']:
  defindex = item['defindex']
  schema_item = items_by_defindex[defindex];
  schema_attributes_by_defindex = {}
  if 'attributes' in schema_item:
    # The backpack json format merges inherited attributes into the item
    # instance deinition. Filter out the real attributes.
    for item_attr in schema_item['attributes']:
      # Each attribute in the item definition doesn't list the defindex. We
      # instead have to match by name
      real_attr = attributes_by_name[item_attr['name']]
      schema_attributes_by_defindex[real_attr['defindex']] = real_attr

  print "Importing item %s..." % schema_item['item_name']

  # Create the item instance.
  item_id = c.ImportItem(65, item['original_id'], defindex, item['level'],
                         item['quality'], item['origin'])

  on_item_attr = {}
  if 'attributes' in item:
    for a in item['attributes']:
      a_defindex = a['defindex']
      if not a_defindex in schema_attributes_by_defindex:
        # TODO: For now, only add attributes that are ints.
        if type(a['value']) is int:
          print " - Setting property '%s' to '%s'" % (
            attributes_by_defindex[a_defindex]['name'], a['value'])
          c.AddAttributeToUnlockedItem(item_id, a_defindex, a['value'])

  c.LockItem(item_id);


