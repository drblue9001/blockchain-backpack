#!/usr/bin/python

from pyethereum import tester

# Create the Backpack contract
print "Creating ethereum context..."
s = tester.state()
contract_file = open('contract.sol')
c = s.abi_contract(contract_file.read(), language='solidity')

phlog_strangifier_file = open('phlog_strangifier.sol')
phlog_strangifier = s.abi_contract(phlog_strangifier_file.read(),
                                   language='solidity')

# 0 needs to be a real contract!
c.SetItemSchema(5722, 13, 13, phlog_strangifier.address,
                "Phlogistinator Strangifier");
c.SetItemSchema(594, 10, 10, 0, "The Phlogistinator");

c.CreateUser(tester.a1)
strangifier_id = c.GrantNewItem(tester.a1, 5722, 0, 2);
phlog_id = c.GrantNewItem(tester.a1, 594, 6, 2);

print "Gave a strangifier with id %s and a phlog with id %s" % (
  strangifier_id, phlog_id)

assert c.GetItemDefindex(strangifier_id) == 5722
assert c.GetItemDefindex(phlog_id) == 594

c.ExecuteItemRecipee(strangifier_id, phlog_id, sender=tester.k1);

assert c.GetNumItems(tester.a1) == 1

assert c.GetItemDefindex(c.GetItemID(tester.a1, 0)) == 594

