#!/usr/bin/python
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
fs = FileContractStore()
c = fs.Backpack.create(sender=tester.k0, state=s)


def IncrementMineCounter():
  IncrementMineCounter.calls_since_last_mine += 1;
  if (IncrementMineCounter.calls_since_last_mine > 30):
    s.mine()
    IncrementMineCounter.calls_since_last_mine = 0
IncrementMineCounter.calls_since_last_mine = 0


def EnsureAttribute(defindex):
  if not defindex in EnsureAttribute.loaded_attributes:
    a = attributes_by_defindex[defindex]
    n = a["name"]
    n = n[:32] if len(n) > 32 else n
    print ("Loading attribute '%s'..." % n)
    c.SetAttribute(defindex, "name", n)
    IncrementMineCounter()
    EnsureAttribute.loaded_attributes.add(defindex)
EnsureAttribute.loaded_attributes = set()


def EnsureSchemaItem(defindex):
  if not defindex in EnsureSchemaItem.loaded_item_schema:
    item = items_by_defindex[defindex]
    print ("Loading item schema for '%s'..." % item["name"])
    c.SetItemSchema(defindex, item["min_ilevel"], item["max_ilevel"], 0);
    IncrementMineCounter()
    # Upload all the attributes, too:
    for a in item.get("attributes", {}):
      EnsureAttribute(attributes_by_name[a["name"]]["defindex"])
    EnsureSchemaItem.loaded_item_schema.add(defindex);
EnsureSchemaItem.loaded_item_schema = set();


# As a special hack for now, manually load the killeater score attributes a d
# set them to be modifiable. We do this because we want a non-owner to be able
# to modify these attributes on an item. (This isn't really necessary until
# later; it is here more as a reminder.)
for i in [214, 294, 379, 381, 383, 494]:
  c.SetAttributeModifiable(i, True)
  EnsureAttribute(i)

# TODO(drblue): We probably want to increment the backpack space here.

for item in backpack_json['items']:
  defindex = item['defindex']
  EnsureSchemaItem(defindex)

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

  # Ensure all the attributes for this item instance are set.
  attr_keys = []
  attr_values = []
  for attr in on_item_attr:
    EnsureAttribute(attr['defindex'])
    attr_keys.append(attr['defindex'])
    attr_values.append(attr['value'])

  old_id = item["id"]
  new_id = c.ImportItem(item["defindex"], item["quality"],
                        item["origin"], item["level"], item["original_id"],
                        tester.a1);
  print "Imported item id='%s' as id='%s'..." % (item["id"], new_id)
  if attr_keys:
    print " - Importing %s attributes onto %s" % (len(attr_keys), new_id);
    c.SetIntAttributes(new_id, attr_keys, attr_values);
  c.FinalizeItem(new_id);
