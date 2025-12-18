/**
 * @description Handles Inventory updates based on Opportunity lifecycle
 */
public with sharing class InventoryHandler {

    /* =====================================================
       PUBLIC ENTRY
       ===================================================== */

    /**
     * @description Updates In-Transit quantity when products are added
     * @param olis Opportunity line items
     */
    public static void updateInTransit(List<OpportunityLineItem> olis) {

        if (!canProcessInTransit(olis)) {
            return;
        }

        Set<Id> productIds = extractProductIds(olis);
        if (productIds.isEmpty()) {
            return;
        }

        Map<Id, Inventory__c> invMap = loadInventory(productIds);
        List<Inventory__c> updates = buildInTransitUpdates(olis, invMap);

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    /**
     * @description Trigger entry for PO Received stage
     * @param oldMap Old Opportunity values
     * @param newMap New Opportunity values
     */
    public static void handlePOReceived(
        Map<Id, Opportunity> oldMap,
        Map<Id, Opportunity> newMap
    ) {
        if (!canProcessPOReceived(oldMap, newMap)) {
            return;
        }

        Set<Id> oppIds = getPOReceivedOpps(oldMap, newMap);
        if (oppIds.isEmpty()) {
            return;
        }

        Set<Id> productIds = getProductsFromOpps(oppIds);
        if (productIds.isEmpty()) {
            return;
        }

        List<Inventory__c> updates = buildPOReceivedUpdates(productIds);
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    /* =====================================================
       VALIDATION
       ===================================================== */

    private static Boolean canProcessInTransit(List<OpportunityLineItem> olis) {
        return olis != null &&
               !olis.isEmpty() &&
               Schema.sObjectType.Inventory__c.isAccessible() &&
               Schema.sObjectType.Inventory__c.isUpdateable();
    }

    private static Boolean canProcessPOReceived(
        Map<Id, Opportunity> oldMap,
        Map<Id, Opportunity> newMap
    ) {
        return oldMap != null &&
               newMap != null &&
               Schema.sObjectType.Inventory__c.isAccessible() &&
               Schema.sObjectType.Inventory__c.isUpdateable() &&
               Schema.sObjectType.OpportunityLineItem.isAccessible();
    }

    /* =====================================================
       HELPERS
       ===================================================== */

    private static Set<Id> extractProductIds(List<OpportunityLineItem> olis) {
        Set<Id> ids = new Set<Id>();
        for (OpportunityLineItem oli : olis) {
            if (oli.Product2Id != null) {
                ids.add(oli.Product2Id);
            }
        }
        return ids;
    }

    private static Map<Id, Inventory__c> loadInventory(Set<Id> productIds) {
        Map<Id, Inventory__c> result = new Map<Id, Inventory__c>();
        for (Inventory__c inv : [
            SELECT Id, Product__c, In_Transit_Quantity__c
            FROM Inventory__c
            WHERE Product__c IN :productIds
        ]) {
            result.put(inv.Product__c, inv);
        }
        return result;
    }

    private static List<Inventory__c> buildInTransitUpdates(
        List<OpportunityLineItem> olis,
        Map<Id, Inventory__c> invMap
    ) {
        List<Inventory__c> updates = new List<Inventory__c>();

        for (OpportunityLineItem oli : olis) {
            Inventory__c inv = invMap.get(oli.Product2Id);
            if (inv != null) {
                Decimal current =
                    inv.In_Transit_Quantity__c == null ? 0 : inv.In_Transit_Quantity__c;
                inv.In_Transit_Quantity__c = current + oli.Quantity;
                updates.add(inv);
            }
        }
        return updates;
    }

    private static Set<Id> getPOReceivedOpps(
        Map<Id, Opportunity> oldMap,
        Map<Id, Opportunity> newMap
    ) {
        Set<Id> ids = new Set<Id>();
        for (Opportunity opp : newMap.values()) {
            if (
                opp.StageName == 'PO Received' &&
                oldMap.containsKey(opp.Id) &&
                oldMap.get(opp.Id).StageName != 'PO Received'
            ) {
                ids.add(opp.Id);
            }
        }
        return ids;
    }

    private static Set<Id> getProductsFromOpps(Set<Id> oppIds) {
        Set<Id> productIds = new Set<Id>();
        for (OpportunityLineItem oli : [
            SELECT Product2Id
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIds
        ]) {
            if (oli.Product2Id != null) {
                productIds.add(oli.Product2Id);
            }
        }
        return productIds;
    }

    private static List<Inventory__c> buildPOReceivedUpdates(Set<Id> productIds) {
        List<Inventory__c> updates = new List<Inventory__c>();

        for (Inventory__c inv : [
            SELECT Id, Available_Quantity__c, In_Transit_Quantity__c
            FROM Inventory__c
            WHERE Product__c IN :productIds
        ]) {
            Decimal inTransit =
                inv.In_Transit_Quantity__c == null ? 0 : inv.In_Transit_Quantity__c;
            Decimal available =
                inv.Available_Quantity__c == null ? 0 : inv.Available_Quantity__c;

            inv.Available_Quantity__c = available - inTransit;
            inv.In_Transit_Quantity__c = 0;
            updates.add(inv);
        }
        return updates;
    }
}