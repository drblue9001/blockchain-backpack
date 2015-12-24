#!/usr/bin/python
#
# Copyright 2015 Dr. Blue.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
##############################################################################
#
# Real times for running this on my backpack:
#
#   real    0m47.604s
#   real    0m46.471s
#
# Note: Despite doing more work, we're faster than the previous 2m11s of the
# previous load_backpack.py script because of improvement in pyethereum. We
# don't deserve credit here at all. (Though maybe the array usage helps...?)

import json
from ethereum import tester
from ethertdd import FileContractStore

# Up the gas limit because our contract is pretty huge.
tester.gas_limit = 100000000;

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

# Create the Backpack contract
print "Creating ethereum context..."
s = tester.state()

s.mine()
fs = FileContractStore().build

### Part 1: Deploying contracts
x = s.block.gas_used
c = fs.Backpack.create(sender=tester.k0, state=s)
backpack_deployment = s.block.gas_used - x

x = s.block.gas_used
deployer = fs.Deployer.create(c.address, sender=tester.k0, state=s)
c.SetPermission(deployer.address, 2, True);
c.SetPermission(deployer.address, 3, True);
c.SetPermission(deployer.address, 4, True);
deployer_deployment = s.block.gas_used - x

### Part 2: Writing attributes and schema data
x = s.block.gas_used

# As a special hack for now, manually load the killeater score attributes a d
# set them to be modifiable. We do this because we want a non-owner to be able
# to modify these attributes on an item. (This isn't really necessary until
# later; it is here more as a reminder.)
for i in [214, 294, 379, 381, 383, 494]:
  c.SetAttributeModifiable(i, True)

# TODO(drblue): We probably want to increment the backpack space here.


def chunks(l, n):
    """Yield successive n-sized chunks from l."""
    for i in xrange(0, len(l), n):
        yield l[i:i+n]


schemas = []
for item in backpack_json['items']:
  defindex = item['defindex']

  # We can't represent Killstreak kit fabricators. :( This appears to be a
  # recent change? This used to work.
  if defindex == 20002:
    continue

  item = items_by_defindex[defindex]
  schema = [defindex, item["min_ilevel"], item["max_ilevel"]]
  if schema not in schemas:
    schemas.append(schema)

for chunk in chunks(schemas, 100):
  t = map(list, zip(*chunk))
  print "Loading %s schema items..." % len(chunk)
  deployer.LoadSchema(t[0], t[1], t[2]);

schema_deployment = s.block.gas_used - x


### Part 3: Writing the item data
x = s.block.gas_used

name_count = 0
desc_count = 0
item_total = 0

simple_items = []
for item in backpack_json['items']:
  defindex = item['defindex']

  # We can't represent Killstreak kit fabricators. :( This appears to be a
  # recent change? This used to work.
  if defindex == 20002:
    continue

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

  on_int_item_attr = []
  on_str_item_attr = []
  if 'attributes' in item:
    for a in item['attributes']:
      a_defindex = a['defindex']
      if a_defindex == 500:
        name_count += 1
      elif a_defindex == 501:
        desc_count += 1
      if not a_defindex in schema_attributes_by_defindex:
        if type(a['value']) is int:
          on_int_item_attr.append({
              'defindex': a_defindex,
              'value': a['value'],
              'name': attributes_by_defindex[a_defindex]['name']})
        elif type(a['value']) is unicode:
          on_str_item_attr.append({
              'defindex': a_defindex,
              'value': a['value'],
              'name': attributes_by_defindex[a_defindex]['name']})

  # Ensure all the attributes for this item instance are set.
  int_attr_keys = []
  int_attr_values = []
  for attr in on_int_item_attr:
    int_attr_keys.append(attr['defindex'])
    int_attr_values.append(attr['value'])

  str_attr_keys = []
  str_attr_values = []
  for attr in on_str_item_attr:
    str_attr_keys.append(attr['defindex'])
    str_attr_values.append(attr['value'])

  old_id = item["id"]
  if not int_attr_keys and not str_attr_keys:
    # This item can be bunched as it has no attributes.
    simple_items.append(item)
  elif not str_attr_keys:
    # We only have to worry about integer attributes.
    new_id = deployer.ImportItem(
      item["defindex"], item["quality"], item["origin"], item["level"],
      item["original_id"], tester.a1, int_attr_keys, int_attr_values);
    print ("Imported item id='%s' as id='%s' with %s int attributes..." %
           (item["id"], new_id, len(int_attr_keys)))
    item_total += 1
  else:
    # We at least have strings. (todo: handle string only case)
    str_count = len(str_attr_keys)
    str_key = str_attr_keys.pop(0)
    # TODO: Remove the encode when the unicode bug in pyethereum is fixed.
    str_value = str_attr_values.pop(0).encode('ascii', 'ignore')
    new_id = deployer.ImportItemWithAString(
      item["defindex"], item["quality"], item["origin"], item["level"],
      item["original_id"], tester.a1, int_attr_keys, int_attr_values,
      str_key, str_value);
    while len(str_attr_keys) > 0:
      str_key = str_attr_keys.pop(0)
      str_value = str_attr_values.pop(0).encode('ascii', 'ignore')
      c.SetStrAttribute(new_id, str_key, str_value)
    c.FinalizeItem(new_id);
    print ("Imported item id='%s' as id='%s' with %s int attributes and %s str attributes..." %
           (item["id"], new_id, len(int_attr_keys), str_count))
    item_total += 1

# Finally, we cram the simple items onto chain 20 at a time.
for chunk in chunks(simple_items, 20):
  print "Importing %s simple items..." % len(chunk)
  defindex = [i["defindex"] for i in chunk]
  quality = [i["quality"] for i in chunk]
  origin = [i["origin"] for i in chunk]
  level = [i["level"] for i in chunk]
  original = [i["original_id"] for i in chunk]
  deployer.ImportSimpleItems(defindex, quality, origin, level, original,
                             tester.a1)
  item_total += len(chunk)

item_deployment = s.block.gas_used - x

print
print "Final Item Statistics:"
print "  Number of named items: %s" % name_count
print "  Number of desc items: %s" % desc_count
print "  Number of items written: %s" % item_total

print
print "Final Gas Tally: "
print "  Backpack Contract Deployment: %s" % backpack_deployment
print "  Deployer Contract Deployment: %s" % deployer_deployment
print "  Schema Deployment:   %s" % schema_deployment
print "  Item Deployment:     %s" % item_deployment
