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


print "Loading backpack..."
bp_file = open('raw_tf2_bp.json')
backpack_json = json.load(bp_file)['result']
print "Loaded %d items from backpack." % len(backpack_json['items'])
# TODO(drblue): Do more parsing on the schema file.

# print "Backpack item names: "
# for item in backpack_json['items']:
#   defindex = item['defindex']
#   schema_item = items_by_defindex[defindex];
#   schema_attributes_by_defindex = {}
#   if 'attributes' in schema_item:
#     for item_attr in schema_item['attributes']:
#       # Each attribute in the item definition doesn't list the defindex. We
#       # instead have to match by name
#       real_attr = attributes_by_name[item_attr['name']]
#       schema_attributes_by_defindex[real_attr['defindex']] = real_attr
#   print "  %s" % schema_item['item_name']
#   on_item_attr = {}
#   inherited_attr = {}
#   if 'attributes' in item:
#     for a in item['attributes']:
#       a_defindex = a['defindex']
#       if a_defindex in schema_attributes_by_defindex:
#         inherited_attr[a_defindex] = a
#       else:
#         on_item_attr[a_defindex] = a
#
#   if on_item_attr:
#     print "    On item attributes:"
#     for a in on_item_attr:
#       print "      %s " % attributes_by_defindex[a]['name']
#
#    if inherited_attr:
#      print "    Inheritted attributes:"
#      for a in inherited_attr:
#        print "      %s " % attributes_by_defindex[a]['name']


# If the filetime of the
print "Creating ethereum context..."
s = tester.state()
contract_file = open('contract.sol')
c = s.abi_contract(contract_file.read(), language='solidity')
c.CreateUser(65)
for item in backpack_json['items']:
  defindex = item['defindex']
  schema_item = items_by_defindex[defindex];
  print "Importing item %s..." % schema_item['item_name']
  c.ImportItem(65, item['original_id'], defindex, item['level'],
               item['quality'], item['origin'])

