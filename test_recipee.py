#!/usr/bin/python

from pyethereum import tester

# Create the Backpack contract
print "Creating ethereum context..."
s = tester.state()
contract_file = open('contract.sol')
c = s.abi_contract(contract_file.read(), language='solidity')

# Quickly grant user 65 a Crate Series #3 (defindex 5045) and a Key (defindex
# 5021.
c.CreateUser(tester.a1)
crate_id = c.GrantNewItem(tester.a1, 5045, 0, 2);
key_id = c.GrantNewItem(tester.a1, 5021, 6, 2);

print "Gave a crate with id %s and a key with id %s" % (crate_id, key_id)

assert c.GetItemDefindex(crate_id) == 5045
assert c.GetItemDefindex(key_id) == 5021

c.ExecuteItemRecipee(crate_id, key_id, sender=tester.k1);

assert c.GetNumItems(tester.a1) == 1

assert c.GetItemDefindex(c.GetItemID(tester.a1, 0)) == 5040

