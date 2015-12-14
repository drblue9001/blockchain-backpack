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

import unittest
from ethereum import tester
from ethertdd import FileContractStore

# Up the gas limit because our contract is pretty huge.
tester.gas_limit = 100000000;

kOK = 'OK\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
kPermissionDenied = 'Permission Denied\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
kNullString = '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
kInvalidAttribute = 'Invalid Attribute\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'

fs = FileContractStore().build

class BackpackTest(unittest.TestCase):
    def setUp(self):
        self.t = tester.state()
        self.t.mine()
        self.contract = fs.Backpack.create(sender=tester.k0,
                                           state=self.t)
        self.t.mine()


class UsersAndPermissionsTest(BackpackTest):
    def test_creator_has_all_permissions(self):
        for i in [0, 1, 2, 3, 4, 5]:
            self.assertTrue(self.contract.HasPermission(tester.a0, i))
        for i in [6, 7, 142]:
            self.assertFalse(self.contract.HasPermission(tester.a0, i))

    def test_other_contact_has_no_permissions_by_default(self):
        for i in [0, 1, 2, 3, 4, 5, 6, 7, 142]:
            self.assertFalse(self.contract.HasPermission(tester.a1, i))

    def test_other_contract_gets_a_permission(self):
        # Starts without the permission.
        self.assertFalse(self.contract.HasPermission(tester.a1, 4));

        # Can't take a permission by itself (AddAtributesToItem).
        self.assertEquals(
            self.contract.SetPermission(tester.a1, 4, True, sender=tester.k1),
            kPermissionDenied)
        self.t.mine()
        self.assertFalse(self.contract.HasPermission(tester.a1, 4))

        # Gets the permission from the contract creater.
        self.assertEquals(
            self.contract.SetPermission(tester.a1, 4, True, sender=tester.k0),
            kOK)
        self.t.mine()
        self.assertTrue(self.contract.HasPermission(tester.a1, 4))

    def test_allow_items(self):
        # Create a user
        self.assertEquals(self.contract.CreateUser(tester.a1), kOK);
        self.assertTrue(self.contract.AllowsItemsReceived(tester.a1));

        # The user can turn off the ability to receive items.
        self.contract.SetAllowItemsReceived(False, sender=tester.k1);
        self.assertFalse(self.contract.AllowsItemsReceived(tester.a1));

    def test_user_cant_create_self(self):
        self.assertEquals(self.contract.CreateUser(tester.a1, sender=tester.k1),
                          kPermissionDenied);
        self.assertEquals(self.contract.GetBackpackCapacityFor(tester.a1), 0);

    def test_user_cant_grant_self_capacity(self):
        # Build the user.
        self.assertEquals(self.contract.CreateUser(tester.a1), kOK);
        self.assertEquals(self.contract.GetBackpackCapacityFor(tester.a1), 300);

        # Ensure the user can't grant self more backpack space.
        self.assertEquals(self.contract.AddBackpackCapacityFor(
            tester.a1, sender=tester.k1), kPermissionDenied);
        self.assertEquals(self.contract.GetBackpackCapacityFor(tester.a1), 300);

    def test_can_grant_capacity(self):
        # Build the user.
        self.assertEquals(self.contract.CreateUser(tester.a1), kOK);
        self.assertEquals(self.contract.GetBackpackCapacityFor(tester.a1), 300);

        self.assertEquals(self.contract.AddBackpackCapacityFor(tester.a1), kOK);
        self.assertEquals(self.contract.GetBackpackCapacityFor(tester.a1), 400);

class AttributeTest(BackpackTest):
    def test_modify_schema_permission(self):
        self.assertEquals(self.contract.SetAttributeModifiable(1, True, sender=tester.k1),
                          kPermissionDenied);

class SchemaTest(BackpackTest):
    def test_schema_permission(self):
        self.assertEquals(self.contract.SetItemSchema(18, 5, 25, 0, sender=tester.k1),
                          kPermissionDenied);

    def test_schema_set_and_get_level(self):
        self.assertEquals(self.contract.SetItemSchema(18, 5, 25, 0), kOK);
        self.assertEquals(self.contract.GetItemLevelRange(18), [5, 25]);

    def test_can_add_valid_attribute(self):
        # Build attribute '388', "kill eater kill type"

        # Add the attribute to "Sleeveless in Siberia" (30556).
        self.assertEquals(self.contract.SetItemSchema(30556, 1, 100, 0), kOK);
        self.assertEquals(self.contract.AddIntAttributeToItemSchema(30556, 388, 64), kOK);


class ItemsTests(BackpackTest):
    def test_dont_create_item_with_no_schema(self):
        # Attempting to build an item that has no defined schema should fail.
        self.assertEquals(self.contract.CreateNewItem(20, 0, 1, tester.a1),
                          0);

    def test_user_cant_create_own_items(self):
        # Define item defindex 20, so that the call would otherwise be valid:
        self.assertEquals(self.contract.SetItemSchema(20, 1, 100, 0), kOK);

        self.assertEquals(
            self.contract.CreateNewItem(20, 0, 1, tester.a1, sender=tester.k1),
            0);

    # def test_item_level(self):
    #     self.assertEquals(self.contract.SetItemSchema(20, 10, 20, 0), kOK);
    #     for i in range(0, 20):
    #         self.t.mine()
    #         id = self.contract.CreateNewItem(20, 0, 1, tester.a1);
    #         self.contract.FinalizeItem(id);
    #         print self.contract.GetItemData(id);

    def test_valid_item_creation(self):
        # Build a valid schema item and then instantiate it.
        self.assertEquals(self.contract.SetItemSchema(20, 50, 50, 0), kOK);
        item_id = self.contract.CreateNewItem(20, 0, 1, tester.a1);

        # Verify that the user's backpack has a single item in it, and that
        # the item has the right defindex.
        self.assertNotEquals(item_id, 0);

        # Verify that the item's data is correct.
        item_data = self.contract.GetItemData(item_id);
        self.assertEquals(item_data[0], 20);

    # def test_delete_last_item(self):
    #     for i in range(1, 4):
    #         self.assertEquals(self.contract.SetItemSchema(i, 50, 50, 0), kOK);
    #         id = self.contract.CreateNewItem(i, 0, 1, tester.a1);
    #         self.contract.FinalizeItem(id);

    #     # indicies = self.GetArrayOfDefindexOfBackpack(tester.a1);
    #     # self.assertEquals([1,2,3], indicies);

    #     # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);

    #     # Attempt to delete the last item:
    #     # self.contract.DeleteItem(item_ids[-1], sender=tester.k1);

    #     # indicies = self.GetArrayOfDefindexOfBackpack(tester.a1);
    #     # self.assertEquals([1,2], indicies);

    # def test_delete_first_item(self):
    #     for i in range(1, 4):
    #         self.assertEquals(self.contract.SetItemSchema(i, 50, 50, 0), kOK);
    #         id = self.contract.CreateNewItem(i, 0, 1, tester.a1);
    #         self.contract.FinalizeItem(id);

    #     # indicies = self.GetArrayOfDefindexOfBackpack(tester.a1);
    #     # self.assertEquals([1,2,3], indicies);

    #     # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);

    #     # Attempt to delete the last item:
    #     self.contract.DeleteItem(item_ids[0], sender=tester.k1);

    #     # indicies = self.GetArrayOfDefindexOfBackpack(tester.a1);
    #     # self.assertEquals([3,2], indicies);

    def test_cant_delete_others_items(self):
        self.assertEquals(self.contract.SetItemSchema(5, 50, 50, 0), kOK);
        id = self.contract.CreateNewItem(5, 0, 1, tester.a1);
        self.contract.FinalizeItem(id);

        # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        # self.assertEquals([id], item_ids);

        # Third party can't delete the item:
        self.contract.DeleteItem(id, sender=tester.k2);
        # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        # self.assertEquals([id], item_ids);

    def test_can_give_item(self):
        self.assertEquals(self.contract.CreateUser(tester.a1), kOK);
        self.assertEquals(self.contract.CreateUser(tester.a2), kOK);

        self.assertEquals(self.contract.SetItemSchema(5, 50, 50, 0), kOK);
        id = self.contract.CreateNewItem(5, 0, 1, tester.a1);
        self.contract.FinalizeItem(id);

        # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        # self.assertEquals([id], item_ids);

        new_id = self.contract.GiveItemTo(id, tester.a2, sender=tester.k1);

        # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        # self.assertEquals([], item_ids);

        # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a2);
        # self.assertEquals([new_id], item_ids);

    def test_cant_give_items_when_no_capacity(self):
        self.assertEquals(self.contract.SetItemSchema(5, 50, 50, 0), kOK);
        id = self.contract.CreateNewItem(5, 0, 1, tester.a1);
        self.contract.FinalizeItem(id);

        # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        # self.assertEquals([id], item_ids);

        self.contract.GiveItemTo(id, tester.a2, sender=tester.k1);

        # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        # self.assertEquals([id], item_ids);
        # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a2);
        # self.assertEquals([], item_ids);

    def test_cant_give_yourself_others_items(self):
        self.assertEquals(self.contract.CreateUser(tester.a1), kOK);
        self.assertEquals(self.contract.CreateUser(tester.a2), kOK);

        self.assertEquals(self.contract.SetItemSchema(5, 50, 50, 0), kOK);
        id = self.contract.CreateNewItem(5, 0, 1, tester.a1);
        self.contract.FinalizeItem(id);

        # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        # self.assertEquals([id], item_ids);

        self.contract.GiveItemTo(id, tester.a2, sender=tester.k2);

        # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        # self.assertEquals([id], item_ids);
        # item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a2);
        # self.assertEquals([], item_ids);

    # This is broken and I don't understand why this is broken.
    def test_open_for_modification(self):
        self.contract.SetPermission(tester.a2, 4, True);

        # Give User 1 an item #5.
        self.assertEquals(self.contract.SetItemSchema(5, 50, 50, 0), kOK);
        id = self.contract.CreateNewItem(5, 0, 1, tester.a1);
        self.contract.FinalizeItem(id);

        # Unlock |id| for tester.a2.
        self.contract.UnlockItemFor(id, tester.a2, sender=tester.k1);

        # Have User 2 open it for modification.
        new_id = self.contract.OpenForModification(id, sender=tester.k2);
        self.contract.SetIntAttribute(new_id, 142, 8, sender=tester.k2);
        self.contract.FinalizeItem(new_id);
        self.assertNotEquals(id, new_id);

class ModifiableAttributeTest(BackpackTest):
    def test_can_add_to_modifiable_attribute(self):
        # TODO(drblue): This doesn't have asserts now.
        self.assertEquals(self.contract.SetAttributeModifiable(214, True), kOK);

        self.assertEquals(self.contract.SetItemSchema(94, 1, 100, 0), kOK);
        texas_id = self.contract.CreateNewItem(94, 0, 1, tester.a1);
        self.contract.SetIntAttribute(texas_id, 214, 0);
        self.contract.FinalizeItem(texas_id);

        # Player scored ten points.
        self.contract.AddToModifiable(texas_id, 214, 10);

    def test_cant_add_modifiable_attribute_to_item(self):
        self.assertEquals(self.contract.SetAttributeModifiable(214, True), kOK);

        self.assertEquals(self.contract.SetItemSchema(94, 1, 100, 0), kOK);
        texas_id = self.contract.CreateNewItem(94, 0, 1, tester.a1);
        self.contract.FinalizeItem(texas_id);

        self.assertEquals(self.contract.GetItemIntAttribute(texas_id, 214), 0);

        # Player scored ten points, but this item isn't Strange.
        self.contract.AddToModifiable(texas_id, 214, 10);

        self.assertEquals(self.contract.GetItemIntAttribute(texas_id, 214), 0);

    def test_giving_clears_modifiable_attribute(self):
        # TODO(drblue): This doesn't have asserts now.
        self.assertEquals(self.contract.CreateUser(tester.a1), kOK);
        self.assertEquals(self.contract.CreateUser(tester.a2), kOK);

        self.assertEquals(self.contract.SetAttributeModifiable(214, True), kOK);

        self.assertEquals(self.contract.SetItemSchema(94, 1, 100, 0), kOK);
        texas_id = self.contract.CreateNewItem(94, 0, 1, tester.a1);
        self.contract.SetIntAttribute(texas_id, 214, 0);
        self.contract.FinalizeItem(texas_id);
        self.contract.AddToModifiable(texas_id, 214, 10);
        # TODO(drblue): Look at the asset log.

        new_id = self.contract.GiveItemTo(texas_id, tester.a2, sender=tester.k1)
        self.assertEquals(self.contract.GetItemIntAttribute(new_id, 214), 0);


class PaintCanTest(BackpackTest):
    def setUp(self):
        BackpackTest.setUp(self);
        self.paint_can = fs.PaintCan.create(sender=tester.k0, state=self.t)
        self.contract.SetPermission(self.paint_can.address, 4, True);
        self.assertEquals(self.contract.CreateUser(tester.a1), kOK);


    def test_paint_can(self):
        # TODO(drblue): This doesn't have asserts now.

        # Step three: define the Australium gold paint can. While there's just
        # one copy of the contract shared among paint cans, each can
        self.assertEquals(self.contract.SetItemSchema(5037, 5, 5,
                                                      self.paint_can.address),
                          kOK);
        self.assertEquals(self.contract.AddIntAttributeToItemSchema(5037,
                                                                    142,
                                                                    15185211),
                          kOK);

        # Step four: define the Texas Ten Gallon hat. It is paintable.
        self.assertEquals(self.contract.SetItemSchema(94, 1, 100, 0), kOK);
        self.assertEquals(self.contract.AddIntAttributeToItemSchema(94,
                                                                    999999,
                                                                    1),
                          kOK);

        # Step five: give the user an instance of both items.
        texas_id = self.contract.CreateNewItem(94, 0, 1, tester.a1);
        self.contract.FinalizeItem(texas_id);
        paint_id = self.contract.CreateNewItem(5037, 0, 1, tester.a1);
        self.contract.FinalizeItem(paint_id);

        # Step six: have the user build an execute call to both items. TODO.
        self.assertEquals(self.contract.UseItem([paint_id, texas_id],
                                                sender=tester.k1), kOK);

        # The user should only have a Texas Ten Gallon.
        # self.assertEquals(self.GetArrayOfDefindexOfBackpack(tester.a1), [94]);

        # The item |texas_id| should have been replaced by |new_texas_id|.
        # new_texas_id = self.GetArrayOfItemIdsOfBackpack(tester.a1)[0];
        # self.assertNotEquals(new_texas_id, texas_id);
        # TODO(drblue): Look at the asset log.


class RestorePaintJobTest(BackpackTest):
    def setUp(self):
        BackpackTest.setUp(self);
        self.restore = fs.RestorePaintJob.create(sender=tester.k0,
                                                 state=self.t)
        self.contract.SetPermission(self.restore.address, 4, True);
        self.contract.SetAction("RestorePaintJob", self.restore.address);
        self.assertEquals(self.contract.CreateUser(tester.a1), kOK);

    def test_can_restore_paint_job(self):
        # TODO(drblue): This doesn't have asserts now.

        # a1 has a Texas Ten Gallon hat.
        self.assertEquals(self.contract.SetItemSchema(94, 1, 100, 0), kOK);
        texas_id = self.contract.CreateNewItem(94, 0, 1, tester.a1);
        self.contract.SetIntAttribute(texas_id, 142, 81);
        self.contract.FinalizeItem(texas_id);

        # Ensure it has paint.
        #self.assertEquals(self.contract.GetItemIntAttribute(texas_id, 142), 81);

        self.contract.DoAction("RestorePaintJob", [texas_id], sender=tester.k1);

        # TODO(drblue): Look at the asset log to ensure it doesn't have paint.


class TradeCoordinatorTest(BackpackTest):
    def setUp(self):
        BackpackTest.setUp(self);
        self.trade = fs.TradeCoordinator.create(self.contract.address,
                                                sender=tester.k0, state=self.t)
        self.assertEquals(self.contract.CreateUser(tester.a1), kOK);
        self.assertEquals(self.contract.CreateUser(tester.a2), kOK);

    def test_can_trade(self):
        # a1 has a Texas Ten Gallon hat.
        self.assertEquals(self.contract.SetItemSchema(94, 1, 100, 0), kOK);
        texas_id = self.contract.CreateNewItem(94, 0, 1, tester.a1);
        self.contract.FinalizeItem(texas_id);

        # a2 has a Righteous Bison.
        self.assertEquals(self.contract.SetItemSchema(442, 30, 30, 0), kOK);
        bison_id = self.contract.CreateNewItem(442, 0, 1, tester.a2);
        self.contract.FinalizeItem(bison_id);

        # self.assertEquals(self.GetArrayOfDefindexOfBackpack(tester.a1), [94]);
        # self.assertEquals(self.GetArrayOfDefindexOfBackpack(tester.a2), [442]);

        # Your hat for my lazer gun. is gud deal m8.
        self.contract.UnlockItemFor(bison_id, self.trade.address,
                                    sender=tester.k2);
        trade_id = self.trade.ProposeTrade([bison_id], tester.a1, [texas_id],
                                           sender=tester.k2);
        self.assertNotEquals(0, trade_id);

        # I am a prey species and will accept this trade!
        self.contract.UnlockItemFor(texas_id, self.trade.address,
                                    sender=tester.k1);
        self.trade.AcceptTrade(trade_id, sender=tester.k1);

        # Now a1 has a Righteous Bison and a2 has a Texas Ten Gallon hat.
        # self.assertEquals(self.GetArrayOfDefindexOfBackpack(tester.a1), [442]);
        # self.assertEquals(self.GetArrayOfDefindexOfBackpack(tester.a2), [94]);


class CrateTest(BackpackTest):
    def setUp(self):
        BackpackTest.setUp(self);
        self.crate = fs.Crate.create(self.contract.address,
                                     sender=tester.k0, state=self.t)
        self.contract.SetPermission(self.crate.address, 3, True);
        self.contract.SetPermission(self.crate.address, 4, True);
        self.assertEquals(self.contract.CreateUser(tester.a1), kOK);

        for defindex in [175, 142, 128, 130, 247, 248, 5020, 5039, 5040]:
            self.assertEquals(self.contract.SetItemSchema(defindex, 1, 1, 0), kOK);

        # Crate
        self.assertEquals(self.contract.SetItemSchema(5022, 10, 10,
                                                      self.crate.address), kOK);
        self.crate_id = self.contract.CreateNewItem(5022, 0, 1, tester.a1);
        self.contract.FinalizeItem(self.crate_id);

        # Key
        self.assertEquals(self.contract.SetItemSchema(5021, 5, 5, 0), kOK);
        self.key_id = self.contract.CreateNewItem(5021, 0, 1, tester.a1);
        self.contract.FinalizeItem(self.key_id);

        self.assertEquals(self.contract.GetNumberOfItemsOwnedFor(tester.a1), 2);


    def testCrateWorking(self):
        # Precommit to receiving an item.
        self.assertEquals(self.contract.UseItem(
            [self.crate_id, self.key_id], sender=tester.k1),
                          kOK)

        # The previous items should have been removed immediately.
        self.assertEquals(self.contract.GetNumberOfItemsOwnedFor(tester.a1), 0);

        # Ensure that we can't uncrate right away.
        self.assertEquals(self.crate.PerformUncrate(0), 'Wrong block height\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00');

        # Mine a blocks.
        self.t.mine()
        self.t.mine()
        self.t.mine()

        self.assertEquals(self.crate.PerformUncrate(0), kOK);
        self.assertEquals(self.contract.GetNumberOfItemsOwnedFor(tester.a1), 1);

    def testCrateNotEnoughBlocks(self):
        # Precommit to receiving an item.
        self.assertEquals(self.contract.UseItem(
            [self.crate_id, self.key_id], sender=tester.k1),
                          kOK)

        # The previous items should have been removed immediately.
        self.assertEquals(self.contract.GetNumberOfItemsOwnedFor(tester.a1), 0);

        # Ensure that we can't uncrate right away.
        self.assertEquals(self.crate.PerformUncrate(0), 'Wrong block height\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00');

        # Mine a blocks.
        self.t.mine()
        self.t.mine()

        # We still need to see one more block.
        self.assertEquals(self.crate.PerformUncrate(0), 'Wrong block height\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00');




if __name__ == '__main__':
    unittest.main()
