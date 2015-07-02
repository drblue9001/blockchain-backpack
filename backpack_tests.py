#!/usr/bin/python
#
# Depends on https://github.com/ethermarket/ethertdd.

import unittest
from ethereum import tester
from ethertdd import FileContractStore

# Up the gas limit because our contract is pretty huge.
tester.gas_limit = 100000000;

kOK = 'OK\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
kPermissionDenied = 'Permission Denied\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
kNullString = '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
kInvalidAttribute = 'Invalid Attribute\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'

fs = FileContractStore()

class BackpackSystemTest(unittest.TestCase):
    def setUp(self):
        self.t = tester.state()
        self.t.mine()
        self.contract = fs.BackpackSystem.create(sender=tester.k0,
                                                 state=self.t)
        self.t.mine()


class UsersAndPermissionsTest(BackpackSystemTest):
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

class AttributeTest(BackpackSystemTest):
    def test_modify_schema_permission(self):
        self.assertEquals(self.contract.SetAttribute(1, "Two", "Three", sender=tester.k1),
                          kPermissionDenied);

    def test_cant_set_zero(self):
        self.assertEquals(self.contract.SetAttribute(0, "Zero", "Emptiness is Loneliness"),
                          kInvalidAttribute);
        self.assertEquals(self.contract.GetAttribute(0, "Zero"), kNullString);

    def test_can_set_property(self):
        self.assertEquals(self.contract.SetAttribute(1, "One", "1"), kOK);
        self.assertEquals(self.contract.GetAttribute(1, "One"),
                          '1\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00');

class SchemaTest(BackpackSystemTest):
    def test_schema_permission(self):
        self.assertEquals(self.contract.SetItemSchema(18, 5, 25, 0, sender=tester.k1),
                          kPermissionDenied);

    def test_schema_set_and_get_level(self):
        self.assertEquals(self.contract.SetItemSchema(18, 5, 25, 0), kOK);
        self.assertEquals(self.contract.GetItemLevelRange(18), [5, 25]);

    def test_cant_add_invalid_attribute(self):
        self.assertEquals(self.contract.SetItemSchema(18, 5, 25, 0), kOK);
        self.assertEquals(self.contract.AddIntAttributeToItemSchema(18, 6, 15),
                          kInvalidAttribute);

    def test_can_add_valid_attribute(self):
        # Build attribute '388', "kill eater kill type"
        self.assertEquals(self.contract.SetAttribute(388, "name", "kill eater kill type"), kOK);
        self.assertEquals(self.contract.SetAttribute(388, "attribute_class", "kill_eater_kill_type"), kOK);

        # Add the attribute to "Sleeveless in Siberia" (30556).
        self.assertEquals(self.contract.SetItemSchema(30556, 1, 100, 0), kOK);
        self.assertEquals(self.contract.AddIntAttributeToItemSchema(30556, 388, 64), kOK);


class ItemsTests(BackpackSystemTest):
    def GetArrayOfDefindexOfBackpack(self, address):
        count = self.contract.GetNumberOfItemsOwnedFor(address);
        defindixes = []
        for i in range(count):
            item_id = self.contract.GetItemIdFromBackpack(address, i);
            self.assertNotEquals(item_id, 0);
            item_data = self.contract.GetItemData(item_id);
            defindixes.append(item_data[0]);
        return defindixes

    def GetArrayOfItemIdsOfBackpack(self, address):
        count = self.contract.GetNumberOfItemsOwnedFor(address);
        item_ids = []
        for i in range(count):
            item_ids.append(self.contract.GetItemIdFromBackpack(address, i));
        return item_ids

    def test_dont_create_item_with_no_schema(self):
        # Attempting to build an item that has no defined schema should fail.
        self.contract.CreateNewItem(20, 0, 1, tester.a1);
        self.assertEquals(self.contract.GetNumberOfItemsOwnedFor(tester.a1),
                          0);

    def test_user_cant_create_own_items(self):
        # Define item defindex 20, so that the call would otherwise be valid:
        self.assertEquals(self.contract.SetItemSchema(20, 1, 100, 0), kOK);

        self.contract.CreateNewItem(20, 0, 1, tester.a1, sender=tester.k1);

        self.assertEquals(self.contract.GetNumberOfItemsOwnedFor(tester.a1),
                          0);

    def test_valid_item_creation(self):
        # Build a valid schema item and then instantiate it.
        self.assertEquals(self.contract.SetItemSchema(20, 50, 50, 0), kOK);
        self.contract.CreateNewItem(20, 0, 1, tester.a1);

        # Verify that the user's backpack has a single item in it, and that
        # the item has the right defindex.
        self.assertEquals(self.contract.GetNumberOfItemsOwnedFor(tester.a1),
                          1);
        item_id = self.contract.GetItemIdFromBackpack(tester.a1, 0);
        self.assertNotEquals(item_id, 0);

        # Verify that the item's data is correct.
        item_data = self.contract.GetItemData(item_id);
        self.assertEquals(item_data[0], 20);
        # TODO(drblue): Skipping owner since python harness is messing it up.
        self.assertEquals(item_data[2], 50);
        # TODO(drblue): skip quality / origin for now. How do we deal with
        # strangifiers / etc.
        self.assertEquals(item_data[5], item_id);

    def test_delete_last_item(self):
        for i in range(1, 4):
            self.assertEquals(self.contract.SetItemSchema(i, 50, 50, 0), kOK);
            id = self.contract.CreateNewItem(i, 0, 1, tester.a1);
            self.contract.FinalizeItem(id);

        indicies = self.GetArrayOfDefindexOfBackpack(tester.a1);
        self.assertEquals([1,2,3], indicies);

        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);

        # Attempt to delete the last item:
        self.contract.DeleteItem(item_ids[-1], sender=tester.k1);

        indicies = self.GetArrayOfDefindexOfBackpack(tester.a1);
        self.assertEquals([1,2], indicies);

    def test_delete_first_item(self):
        for i in range(1, 4):
            self.assertEquals(self.contract.SetItemSchema(i, 50, 50, 0), kOK);
            id = self.contract.CreateNewItem(i, 0, 1, tester.a1);
            self.contract.FinalizeItem(id);

        indicies = self.GetArrayOfDefindexOfBackpack(tester.a1);
        self.assertEquals([1,2,3], indicies);

        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);

        # Attempt to delete the last item:
        self.contract.DeleteItem(item_ids[0], sender=tester.k1);

        indicies = self.GetArrayOfDefindexOfBackpack(tester.a1);
        self.assertEquals([3,2], indicies);

    def test_cant_delete_others_items(self):
        self.assertEquals(self.contract.SetItemSchema(5, 50, 50, 0), kOK);
        id = self.contract.CreateNewItem(5, 0, 1, tester.a1);
        self.contract.FinalizeItem(id);

        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        self.assertEquals([id], item_ids);

        # Third party can't delete the item:
        self.contract.DeleteItem(id, sender=tester.k2);
        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        self.assertEquals([id], item_ids);

    def test_can_give_item(self):
        self.assertEquals(self.contract.CreateUser(tester.a1), kOK);
        self.assertEquals(self.contract.CreateUser(tester.a2), kOK);

        self.assertEquals(self.contract.SetItemSchema(5, 50, 50, 0), kOK);
        id = self.contract.CreateNewItem(5, 0, 1, tester.a1);
        self.contract.FinalizeItem(id);
        original_id = self.contract.GetItemData(id)[5];

        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        self.assertEquals([id], item_ids);

        new_id = self.contract.GiveItemTo(id, tester.a2, sender=tester.k1);

        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        self.assertEquals([], item_ids);

        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a2);
        self.assertEquals([new_id], item_ids);
        new_original_id = self.contract.GetItemData(new_id)[5];
        self.assertEquals(original_id, new_original_id);

    def test_cant_give_items_when_no_capacity(self):
        self.assertEquals(self.contract.SetItemSchema(5, 50, 50, 0), kOK);
        id = self.contract.CreateNewItem(5, 0, 1, tester.a1);
        self.contract.FinalizeItem(id);

        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        self.assertEquals([id], item_ids);

        self.contract.GiveItemTo(id, tester.a2, sender=tester.k1);

        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        self.assertEquals([id], item_ids);
        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a2);
        self.assertEquals([], item_ids);

    def test_cant_give_yourself_others_items(self):
        self.assertEquals(self.contract.CreateUser(tester.a1), kOK);
        self.assertEquals(self.contract.CreateUser(tester.a2), kOK);

        self.assertEquals(self.contract.SetItemSchema(5, 50, 50, 0), kOK);
        id = self.contract.CreateNewItem(5, 0, 1, tester.a1);
        self.contract.FinalizeItem(id);

        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        self.assertEquals([id], item_ids);

        self.contract.GiveItemTo(id, tester.a2, sender=tester.k2);

        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a1);
        self.assertEquals([id], item_ids);
        item_ids = self.GetArrayOfItemIdsOfBackpack(tester.a2);
        self.assertEquals([], item_ids);

    # TODO(drblue): Add tests for setting an int attribute.

if __name__ == '__main__':
    unittest.main()
