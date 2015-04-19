#!/usr/bin/python
#
# Depends on https://github.com/ethermarket/ethertdd.

import unittest
from ethereum import tester
from ethertdd import FileContractStore

fs = FileContractStore()

class PermissionsTest(unittest.TestCase):
    def setUp(self):
        contract = fs.BackpackSystem.create();

    def test_basic(self):
        pass

if __name__ == '__main__':
    unittest.main()
