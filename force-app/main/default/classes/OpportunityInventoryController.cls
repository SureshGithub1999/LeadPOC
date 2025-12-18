/**
 * @description
 * Controller used to display Opportunity details along with
 * related Inventory records based on Opportunity Products.
 * This controller is designed for use with a Visualforce page
 * using ApexPages.StandardController.
 *
 * Security:
 * - Enforces record sharing using `with sharing`
 * - Uses WITH SECURITY_ENFORCED in SOQL
 * - Applies FLS using Security.stripInaccessible
 *
 * @author Rowthu Sravani
 */
public with sharing class OpportunityInventoryController {

    /**
     * The Opportunity record associated with the page.
     */
    public Opportunity opp { get; set; }
     /**
     * List of Inventory records related to Opportunity Products.
     */
    public List<Inventory__c> inventoryList { get; set; }
     /**
     * Constructor for OpportunityInventoryController.
     *
     * @param stdCtrl
     *        StandardController instance containing the Opportunity Id
     */

    public OpportunityInventoryController(ApexPages.StandardController stdCtrl) {

        Id oppId = stdCtrl.getId();

        /* QUERY OPPORTUNITY */
        Opportunity oppRec = [
            SELECT Id, Name, StageName,OwnerId, AccountId
            FROM Opportunity
            WHERE Id = :oppId
            WITH SECURITY_ENFORCED
            LIMIT 1

        ];

      List<OpportunityLineItem> oliList = [
    SELECT Product2Id, Product2.Name
    FROM OpportunityLineItem
    WHERE OpportunityId = :oppId
    WITH SECURITY_ENFORCED
];


        /* QUERY INVENTORY */
       Set<Id> productIds = new Set<Id>();
for (OpportunityLineItem oli : oliList) {
    productIds.add(oli.Product2Id);
}

List<Inventory__c> invList = [
    SELECT Name,
           Product__r.Name,
           Warehouse__c,
           Available_Quantity__c,
           Reserved_Quantity__c,
           Stock_Status__c,
           Total_Stock_Value__c,
           Unit_Cost__c
    FROM Inventory__c
    WHERE Product__c IN :productIds
    WITH SECURITY_ENFORCED
];


        /* FLS ENFORCEMENT */
        opp = (Opportunity) Security.stripInaccessible(
            AccessType.READABLE,
            new List<Opportunity>{ oppRec }
        ).getRecords()[0];

        inventoryList = (List<Inventory__c>) Security.stripInaccessible(
            AccessType.READABLE,
            invList
        ).getRecords();
    }
}