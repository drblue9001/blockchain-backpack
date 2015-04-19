#!/usr/bin/python
#
# Depends on https://github.com/ethermarket/ethertdd.

import unittest
from ethereum import tester
from ethertdd import FileContractStore

# Up the gas limit because our contract is pretty huge.
tester.gas_limit = 10000000;

class PermissionsTest(unittest.TestCase):
    def setUp(self):
        self.t = tester.state()
        self.t.mine()
        self.fs = FileContractStore()
        self.contract = self.fs.BackpackSystem.create(sender=tester.k0,
                                                      state=self.t)
        self.t.mine()

    def test_creator_has_all_permissions(self):
        for i in [0, 1, 2, 3, 4]:
            self.assertTrue(self.contract.HasPermission(tester.a0, i))
        for i in [5, 6, 7, 142]:
            self.assertFalse(self.contract.HasPermission(tester.a0, i))

    def test_other_contact_has_no_permissions_by_default(self):
        for i in [0, 1, 2, 3, 4, 5, 6, 142]:
            self.assertFalse(self.contract.HasPermission(tester.a1, i))

if __name__ == '__main__':
    unittest.main()
