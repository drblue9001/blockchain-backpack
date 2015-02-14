#!/usr/bin/python

# Real times of running the naieve version:
#   real	6m26.522s
#   real	6m28.551s
#
# Real times of the version with the first round of non-principeled functions:
#   real	2m38.921s
#   real	2m38.879s
#
# Real times after maxing out the AddXAttributes and QuickImport functions:
#   real	2m23.947s
#   real	2m11.286s

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

# Separate out the items into no, one, two, and many attribute items
no_attribute_items = []
one_attribute_items = []
two_attribute_items = []
three_attribute_items = []
many_attribute_items = []
# Three is the maximum we can cram in one message; I'd do four otherwise.

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

  on_item_attr = []
  if 'attributes' in item:
    for a in item['attributes']:
      a_defindex = a['defindex']
      if not a_defindex in schema_attributes_by_defindex:
        # TODO: For now, only add attributes that are ints.
        if type(a['value']) is int:
          on_item_attr.append({
              'defindex': a_defindex,
              'value': a['value'],
              'name': attributes_by_defindex[a_defindex]['name']})

  if len(on_item_attr) == 0:
    no_attribute_items.append([item, on_item_attr])
  elif len(on_item_attr) == 1:
    one_attribute_items.append([item, on_item_attr])
  elif len(on_item_attr) == 2:
    two_attribute_items.append([item, on_item_attr])
  elif len(on_item_attr) == 3:
    three_attribute_items.append([item, on_item_attr])
  else:
    many_attribute_items.append([item, on_item_attr])

while len(no_attribute_items):
  if (len(no_attribute_items) >= 2):
    [item_one, _] = no_attribute_items.pop()
    defindex_one = item_one['defindex']
    schema_item_one = items_by_defindex[defindex_one];

    [item_two, _] = no_attribute_items.pop()
    defindex_two = item_two['defindex']
    schema_item_two = items_by_defindex[defindex_two];

    print "Importing items (%s, %s)..." % (schema_item_one['item_name'],
                                           schema_item_two['item_name'])

    c.QuickImport2Items(65,
                        item_one['original_id'], defindex_one,
                        item_one['level'], item_one['quality'],
                        item_one['origin'],
                        item_two['original_id'], defindex_two,
                        item_two['level'], item_two['quality'],
                        item_two['origin'])
  else:
    # TODO: Test this; my backpack has an even number of no-attribute items.
    [item_one, _] = no_attribute_items.pop()
    defindex_one = item_one['defindex']
    schema_item_one = items_by_defindex[defindex_one];

    print "Importing item %s..." % schema_item_one['item_name']

    c.QuickImportItem(65, item_one['original_id'], defindex_one,
                      item_one['level'], item_one['quality'],
                      item_one['origin'])

while len(one_attribute_items):
  [item_one, attributes] = one_attribute_items.pop()
  defindex_one = item_one['defindex']
  schema_item_one = items_by_defindex[defindex_one];

  only_attribute = attributes.pop()
  print "Importing item %s {%s=%s}..." % (schema_item_one['item_name'],
                                          only_attribute['name'],
                                          only_attribute['value'])

  c.QuickImportItemWith1Attribute(65, item_one['original_id'], defindex_one,
                                  item_one['level'], item_one['quality'],
                                  item_one['origin'],
                                  only_attribute['defindex'],
                                  only_attribute['value'])

while len(two_attribute_items):
  [item_one, attributes] = two_attribute_items.pop()
  defindex_one = item_one['defindex']
  schema_item_one = items_by_defindex[defindex_one];

  one_attribute = attributes.pop()
  two_attribute = attributes.pop()
  print "Importing item %s {%s=%s, %s=%s}..." % (schema_item_one['item_name'],
                                                 one_attribute['name'],
                                                 one_attribute['value'],
                                                 two_attribute['name'],
                                                 two_attribute['value'])

  c.QuickImportItemWith2Attributes(65, item_one['original_id'], defindex_one,
                                   item_one['level'], item_one['quality'],
                                   item_one['origin'],
                                   one_attribute['defindex'],
                                   one_attribute['value'],
                                   two_attribute['defindex'],
                                   two_attribute['value'])

while len(three_attribute_items):
  [item_one, attributes] = three_attribute_items.pop()
  defindex_one = item_one['defindex']
  schema_item_one = items_by_defindex[defindex_one];

  one_attribute = attributes.pop()
  two_attribute = attributes.pop()
  three_attribute = attributes.pop()
  print "Importing item %s {%s=%s, %s=%s, %s=%s}..." % (
    schema_item_one['item_name'],
    one_attribute['name'],
    one_attribute['value'],
    two_attribute['name'],
    two_attribute['value'],
    three_attribute['name'],
    three_attribute['value'])

  c.QuickImportItemWith3Attributes(65, item_one['original_id'], defindex_one,
                                   item_one['level'], item_one['quality'],
                                   item_one['origin'],
                                   one_attribute['defindex'],
                                   one_attribute['value'],
                                   two_attribute['defindex'],
                                   two_attribute['value'],
                                   three_attribute['defindex'],
                                   three_attribute['value'])

while len(many_attribute_items):
  [item_one, attributes] = many_attribute_items.pop()
  defindex_one = item_one['defindex']
  schema_item_one = items_by_defindex[defindex_one];

  one_attribute = attributes.pop()
  two_attribute = attributes.pop()
  three_attribute = attributes.pop()
  print "Importing item %s {%s=%s, %s=%s, %s=%s}..." % (
    schema_item_one['item_name'],
    one_attribute['name'],
    one_attribute['value'],
    two_attribute['name'],
    two_attribute['value'],
    three_attribute['name'],
    three_attribute['value'])

  contract_item_id = c.StartFullImportItemWith3Attributes(
      65, item_one['original_id'], defindex_one,
      item_one['level'], item_one['quality'],
      item_one['origin'],
      one_attribute['defindex'],
      one_attribute['value'],
      two_attribute['defindex'],
      two_attribute['value'],
      three_attribute['defindex'],
      three_attribute['value'])

  while len(attributes):
    # 6 is the maximum number of attributes we can cram in a message.
    if len(attributes) >= 6:
      one_attr = attributes.pop()
      two_attr = attributes.pop()
      three_attr = attributes.pop()
      four_attr = attributes.pop()
      five_attr = attributes.pop()
      six_attr = attributes.pop()

      print (" - Setting properties {'%s' to '%s', '%s' to '%s', '%s' to '%s'"
             ", '%s' to '%s', '%s' to '%s', '%s' to '%s'}"
             % (one_attr['name'], one_attr['value'],
                two_attr['name'], two_attr['value'],
                three_attr['name'], three_attr['value'],
                four_attr['name'], four_attr['value'],
                five_attr['name'], five_attr['value'],
                six_attr['name'], six_attr['value']))
      c.Add6AttributesToUnlockedItem(contract_item_id,
                                     one_attr['defindex'], one_attr['value'],
                                     two_attr['defindex'], two_attr['value'],
                                     three_attr['defindex'],
                                     three_attr['value'],
                                     four_attr['defindex'],
                                     four_attr['value'],
                                     five_attr['defindex'],
                                     five_attr['value'],
                                     six_attr['defindex'],
                                     six_attr['value'])
    elif len(attributes) >= 5:
      one_attr = attributes.pop()
      two_attr = attributes.pop()
      three_attr = attributes.pop()
      four_attr = attributes.pop()
      five_attr = attributes.pop()

      print (" - Setting properties {'%s' to '%s', '%s' to '%s', '%s' to '%s'"
             ", '%s' to '%s', '%s' to '%s'}"
             % (one_attr['name'], one_attr['value'],
                two_attr['name'], two_attr['value'],
                three_attr['name'], three_attr['value'],
                four_attr['name'], four_attr['value'],
                five_attr['name'], five_attr['value']))
      c.Add5AttributesToUnlockedItem(contract_item_id,
                                     one_attr['defindex'], one_attr['value'],
                                     two_attr['defindex'], two_attr['value'],
                                     three_attr['defindex'],
                                     three_attr['value'],
                                     four_attr['defindex'],
                                     four_attr['value'],
                                     five_attr['defindex'],
                                     five_attr['value'])
    elif len(attributes) >= 4:
      one_attr = attributes.pop()
      two_attr = attributes.pop()
      three_attr = attributes.pop()
      four_attr = attributes.pop()

      print (" - Setting properties {'%s' to '%s', '%s' to '%s', '%s' to '%s'"
             ", '%s' to '%s'}"
             % (one_attr['name'], one_attr['value'],
                two_attr['name'], two_attr['value'],
                three_attr['name'], three_attr['value'],
                four_attr['name'], four_attr['value']))
      c.Add4AttributesToUnlockedItem(contract_item_id,
                                     one_attr['defindex'], one_attr['value'],
                                     two_attr['defindex'], two_attr['value'],
                                     three_attr['defindex'],
                                     three_attr['value'],
                                     four_attr['defindex'],
                                     four_attr['value'])
    elif len(attributes) >= 3:
      one_attr = attributes.pop()
      two_attr = attributes.pop()
      three_attr = attributes.pop()
      print (" - Setting properties {'%s' to '%s', '%s' to '%s', '%s' to '%s'}"
             % (one_attr['name'], one_attr['value'],
                two_attr['name'], two_attr['value'],
                three_attr['name'], three_attr['value']))
      c.Add3AttributesToUnlockedItem(contract_item_id,
                                     one_attr['defindex'], one_attr['value'],
                                     two_attr['defindex'], two_attr['value'],
                                     three_attr['defindex'],
                                     three_attr['value'])
    elif len(attributes) >= 2:
      one_attr = attributes.pop()
      two_attr = attributes.pop()
      print (" - Setting properties {'%s' to '%s', '%s' to '%s'}"
             % (one_attr['name'], one_attr['value'],
                two_attr['name'], two_attr['value']))
      c.Add2AttributesToUnlockedItem(contract_item_id,
                                     one_attr['defindex'], one_attr['value'],
                                     two_attr['defindex'], two_attr['value'])
    else:
      attr = attributes.pop()
      print " - Setting property '%s' to '%s'" % (attr['name'], attr['value'])
      c.AddAttributeToUnlockedItem(contract_item_id, attr['defindex'],
                                   attr['value'])

  c.LockItem(contract_item_id)
