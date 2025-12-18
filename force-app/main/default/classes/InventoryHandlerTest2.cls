@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class InventoryHandlerTest2 {

    @TestSetup
    static void setupData() {

        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        insert new Inventory__c(
            Product__c = prod.Id,
            Available_Quantity__c = 50,
            In_Transit_Quantity__c = 0
        );

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert opp;

        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            TotalPrice = 500
        );
    }

    @IsTest
    static void testUpdateInTransit() {

        List<OpportunityLineItem> olis =
            [SELECT Product2Id, Quantity FROM OpportunityLineItem];

        Test.startTest();
        InventoryHandler.updateInTransit(olis);
        Test.stopTest();

        Inventory__c inv =
            [SELECT In_Transit_Quantity__c FROM Inventory__c LIMIT 1];

        System.assertEquals(5, inv.In_Transit_Quantity__c);
    }

    @IsTest
    static void testHandlePOReceived() {

        InventoryHandler.updateInTransit(
            [SELECT Product2Id, Quantity FROM OpportunityLineItem]
        );

        Opportunity opp =
            [SELECT Id, StageName FROM Opportunity LIMIT 1];

        Opportunity oldOpp =
            opp.clone(false, true, false, false);

        opp.StageName = 'PO Received';
        update opp;

        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
        oldMap.put(oldOpp.Id, oldOpp);

        Map<Id, Opportunity> newMap = new Map<Id, Opportunity>();
        newMap.put(opp.Id, opp);

        Test.startTest();
        InventoryHandler.handlePOReceived(oldMap, newMap);
        Test.stopTest();

        Inventory__c inv =
            [SELECT Available_Quantity__c, In_Transit_Quantity__c FROM Inventory__c LIMIT 1];

        System.assertEquals(45, inv.Available_Quantity__c);
        System.assertEquals(0, inv.In_Transit_Quantity__c);
    }
}