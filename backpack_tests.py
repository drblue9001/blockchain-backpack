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

    # TODO: This prints None instead of True and False.
    def test_creator_has_all_permissions(self):
        for i in [0, 1, 2, 3, 4]:
            print self.contract.HasPermission(tester.a0, 0)

if __name__ == '__main__':
    unittest.main()
