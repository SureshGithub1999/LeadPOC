@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class AddConfigProductControllerTest {

    @TestSetup
    static void setup() {
        update new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );

        Account acc = new Account(Name='Acc');
        insert acc;

        Opportunity opp = new Opportunity(
            Name='Opp',
            StageName='Prospecting',
            CloseDate=Date.today().addDays(10),
            AccountId=acc.Id
        );
        insert opp;
    }

    /* ---------------- INIT DATA ---------------- */

    @IsTest
    static void testGetInitDataSuccess() {
        Test.startTest();
        Map<String,Object> res =
            AddConfigProductController.getInitData(
                [SELECT Id FROM Opportunity LIMIT 1].Id
            );
        Test.stopTest();

        System.assert(res.containsKey('productTypeOptions'));
    }

    @IsTest
    static void testGetInitDataNull() {
        try {
            AddConfigProductController.getInitData(null);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    /* ---------------- FIELDSET ---------------- */

    @IsTest
    static void testGetFieldsForProductType() {
        List<Schema.PicklistEntry> vals =
            Product2.Product_Type__c.getDescribe().getPicklistValues();

        if (!vals.isEmpty()) {
            List<Map<String,Object>> fields =
                AddConfigProductController.getFieldsForProductType(
                    vals[0].getValue()
                );
            System.assertNotEquals(null, fields);
        }
    }

    /* ---------------- CORE SUCCESS ---------------- */

    @IsTest
    static void testCreateProductAndOLISuccess() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Map<String,Object> payload = new Map<String,Object>{
            'opportunityId' => opp.Id,
            'productTypeDevName' => 'Product_Type_1',
            'fieldValues' => new Map<String,Object>{
                'Name' => 'Prod',
                'Stock_Unit__c' => 'STK1',
                'Description' => 'Desc',
                'UnitPrice' => 100
            },
            'quantity' => 1,
            'salesPrice' => 100
        };

        Test.startTest();
        Id oliId =
            AddConfigProductController.createProductAndOLI(
                JSON.serialize(payload)
            );
        Test.stopTest();

        System.assertNotEquals(null, oliId);
    }

    /* ---------------- NEGATIVE ---------------- */

    @IsTest
    static void testMissingOppId() {
        try {
            AddConfigProductController.createProductAndOLI(
                JSON.serialize(
                    new Map<String,Object>{
                        'salesPrice'=>100,
                        'quantity'=>1
                    }
                )
            );
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void testInvalidSalesPrice() {
        try {
            AddConfigProductController.createProductAndOLI(
                JSON.serialize(
                    new Map<String,Object>{
                        'opportunityId'=>[SELECT Id FROM Opportunity LIMIT 1].Id,
                        'salesPrice'=>0,
                        'quantity'=>1,
                        'fieldValues'=>new Map<String,Object>{'Name'=>'X'}
                    }
                )
            );
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    /* ---------------- HELPERS ---------------- */

    @IsTest
    static void testHelpers() {

        Product2 p = new Product2();
        AddConfigProductController.testSetProductCode(
            p,
            'Product_Type_1',
            new Map<String,Object>{ 'Stock_Unit__c'=>'CODE1' }
        );
        System.assertEquals('CODE1', p.ProductCode);

        OpportunityLineItem oli = new OpportunityLineItem();
        AddConfigProductController.testSetOLIDescription(
            oli,
            'Product_Type_1',
            new Map<String,Object>{ 'Description'=>'Desc' }
        );
        System.assertEquals('Desc', oli.Description);
    }

    @IsTest
    static void testEnsureStandardPricebookEntry() {

        Product2 p = new Product2(Name='P', IsActive=true);
        insert p;

        Test.startTest();
        AddConfigProductController.testEnsureStandardPricebookEntry(
            p.Id, 100
        );
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM PricebookEntry WHERE Product2Id=:p.Id]
        );
    }
    @IsTest
static void testSetProductCodeUnknownType() {

    Product2 p = new Product2();

    AddConfigProductController.testSetProductCode(
        p,
        'UNKNOWN_TYPE',
        new Map<String,Object>{ 'X__c'=>'123' }
    );

    System.assertEquals(null, p.ProductCode);
}
@IsTest
static void testSetOLIDescriptionUnknownType() {

    OpportunityLineItem oli = new OpportunityLineItem();

    AddConfigProductController.testSetOLIDescription(
        oli,
        'UNKNOWN_TYPE',
        new Map<String,Object>{
            'Description' => 'SHOULD NOT SET'
        }
    );

    System.assertEquals(null, oli.Description);
}
@IsTest
static void testEnsureStandardPricebookEntryAlreadyExists() {

    Product2 p = new Product2(Name='Prod', IsActive=true);
    insert p;

    insert new PricebookEntry(
        Product2Id = p.Id,
        Pricebook2Id = Test.getStandardPricebookId(),
        UnitPrice = 100,
        IsActive = true
    );

    Test.startTest();
    AddConfigProductController.testEnsureStandardPricebookEntry(
        p.Id, 100
    );
    Test.stopTest();

    System.assertEquals(
        1,
        [SELECT COUNT() FROM PricebookEntry WHERE Product2Id=:p.Id]
    );
}
@IsTest
static void testOpportunityAlreadyHasPricebook() {

    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    opp.Pricebook2Id = Test.getStandardPricebookId();
    update opp;

    Test.startTest();
    Opportunity result =
        AddConfigProductController.testGetOpportunityWithPricebook(opp.Id);
    Test.stopTest();

    System.assertEquals(Test.getStandardPricebookId(), result.Pricebook2Id);
}
@IsTest
static void testSetProductCodeFieldMissing() {

    Product2 p = new Product2();

    AddConfigProductController.testSetProductCode(
        p,
        'Product_Type_1',
        new Map<String,Object>() // ❌ no Stock_Unit__c
    );

    System.assertEquals(null, p.ProductCode);
}

@IsTest
static void testUnitPriceZeroFallsBackToSalesPrice() {

    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

    Map<String, Object> payload = new Map<String, Object>{
        'opportunityId' => opp.Id,
        'productTypeDevName' => 'Product_Type_1',
        'fieldValues' => new Map<String, Object>{
            'Name' => 'Fallback Product',
            'Stock_Unit__c' => 'STK-ZERO',
            'UnitPrice' => 0   // 🔥 KEY PRESENT BUT ZERO
        },
        'quantity' => 1,
        'salesPrice' => 150
    };

    Test.startTest();
    Id oliId = AddConfigProductController.createProductAndOLI(
        JSON.serialize(payload)
    );
    Test.stopTest();

    OpportunityLineItem oli = [
        SELECT UnitPrice
        FROM OpportunityLineItem
        WHERE Id = :oliId
    ];

    // UnitPrice should fall back to salesPrice
    System.assertEquals(150, oli.UnitPrice);
}

}