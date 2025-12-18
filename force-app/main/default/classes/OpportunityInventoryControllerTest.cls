@IsTest
public class OpportunityInventoryControllerTest {

    // Create an active Standard User if needed
    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        return new User(
            Alias = 'tuser',
            Email = 'testuser' + System.currentTimeMillis() + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'tuser' + System.currentTimeMillis() + '@example.com',
            IsActive = true // must be active for runAs
        );
    }

    @TestSetup
    static void setupData() {

        // Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        // Product
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        // Standard Pricebook
        Id standardPbId = Test.getStandardPricebookId();

        // PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // OpportunityLineItem
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            Quantity = 1,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id
        );
        insert oli;

        // Warehouse Address (lookup)
        Address__c addr = new Address__c(
            Name = 'Main Warehouse Address',
            Postal_Code__c = '567890'
        );
        insert addr;

        // Inventory record
        Inventory__c inv = new Inventory__c(
            Product__c = prod.Id,
            Warehouse__c = addr.Id,
            Available_Quantity__c = 10,
            Reserved_Quantity__c = 2,
            Unit_Cost__c = 80
        );
        insert inv;
    }

    @IsTest
    static void testOpportunityInventoryController() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(opp);

        // Query a System Admin user who is active
        User adminUser = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator'
              AND IsActive = true
            LIMIT 1
        ];

        // Run as active System Admin
        System.runAs(adminUser) {
            OpportunityInventoryController controller = new OpportunityInventoryController(sc);

            System.assertNotEquals(null, controller.opp, 'Opportunity should be initialized');
            System.assert(controller.inventoryList != null, 'Inventory list should be initialized');
            System.assert(controller.inventoryList.size() > 0, 'Inventory records should be returned');
        }
    }
}