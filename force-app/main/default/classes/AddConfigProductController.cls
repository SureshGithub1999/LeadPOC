/**
 * @description Controller to create configurable Product,
 *              PricebookEntry and OpportunityLineItem
 * @author Nikhitha
 */
public with sharing class AddConfigProductController {

    /* =========================================================
       INIT DATA
       ========================================================= */

/**
 * @description
 * Fetches initial data required for Add Config Product UI
 *
 * @param opportunityId
 *        Id of the Opportunity record
 *
 * @return
 *        Map containing product type options
 */

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getInitData(Id opportunityId) {

        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }

        Map<String, Object> result = new Map<String, Object>();

        List<Product_Type_Fieldset__mdt> mList = [
            SELECT DeveloperName
            FROM Product_Type_Fieldset__mdt
            WITH USER_MODE
            LIMIT 100
        ];

        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Product_Type_Fieldset__mdt m : mList) {
            options.add(new Map<String, String>{
                'label' => m.DeveloperName,
                'value' => m.DeveloperName
            });
        }

        result.put('productTypeOptions', options);
        return result;
    }
    /**
 * @description
 * Returns dynamic Product2 fields based on selected Product Type
 *
 * @param productTypeDevName
 *        DeveloperName of Product Type metadata
 *
 * @return
 *        List of field metadata maps for UI rendering
 */

    /* =========================================================
       FIELDSET METADATA
       ========================================================= */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getFieldsForProductType(
        String productTypeDevName
    ) {
        ProductTypeFieldsetUtil.Fieldset fs =
            ProductTypeFieldsetUtil.getFieldsetForType(productTypeDevName);

        List<Map<String, Object>> output = new List<Map<String, Object>>();
        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.Product2.fields.getMap();

        for (String api : fs.fields) {
            if (fieldMap.containsKey(api)) {
                Schema.DescribeFieldResult d =
                    fieldMap.get(api).getDescribe();

                output.add(new Map<String, Object>{
                    'apiName' => api,
                    'label' => d.getLabel(),
                    'required' => fs.required.contains(api),
                    'defaultValue' =>
                        fs.defaults.containsKey(api)
                        ? fs.defaults.get(api)
                        : ''
                });
            }
        }
        return output;
    }
/**
 * @description
 * Creates Product, PricebookEntry and OpportunityLineItem
 * based on payload sent from UI
 *
 * @param payloadJson
 *        JSON string containing product, price and opportunity data
 *
 * @return
 *        Id of the created OpportunityLineItem
 */
    /* =========================================================
       CORE LOGIC
       ========================================================= */

    @AuraEnabled
    public static Id createProductAndOLI(String payloadJson) {

        try {

            Map<String, Object> data =
                (Map<String, Object>) JSON.deserializeUntyped(payloadJson);

            Id oppId = (Id) data.get('opportunityId');
            if (oppId == null) {
                throw new AuraHandledException('Missing Opportunity Id.');
            }

            String productType =
                (String) data.get('productTypeDevName');

            Map<String, Object> values =
                (Map<String, Object>) data.get('fieldValues');

            Integer qty =
                Integer.valueOf(String.valueOf(data.get('quantity')));

            Decimal salesPrice =
                Decimal.valueOf(String.valueOf(data.get('salesPrice')));

            if (salesPrice <= 0) {
                throw new AuraHandledException('Sales Price must be greater than zero.');
            }

            /* 1️⃣ Create Product */
            Product2 product =
                createProduct(productType, values);

            /* 2️⃣ Ensure Opportunity has Pricebook */
            Opportunity opp =
                getOpportunityWithPricebook(oppId);

            /* 3️⃣ Unit Price */
            Decimal unitPrice =
                values.containsKey('UnitPrice') &&
                Decimal.valueOf(String.valueOf(values.get('UnitPrice'))) > 0
                ? Decimal.valueOf(String.valueOf(values.get('UnitPrice')))
                : salesPrice;

            /* 4️⃣ MUST create Standard Pricebook Entry */
            ensureStandardPricebookEntry(product.Id, unitPrice);

            /* 5️⃣ Create Pricebook Entry for Opportunity Pricebook */
            PricebookEntry pbe = new PricebookEntry(
                Pricebook2Id = opp.Pricebook2Id,
                Product2Id   = product.Id,
                UnitPrice    = unitPrice,
                IsActive     = true
            );
            Database.insert(pbe, AccessLevel.USER_MODE);

            /* 6️⃣ Create Opportunity Line Item */
            OpportunityLineItem oli = new OpportunityLineItem(
                OpportunityId     = opp.Id,
                PricebookEntryId  = pbe.Id,
                Quantity          = qty,
                UnitPrice         = salesPrice,
                ServiceDate       = Date.today()
            );

            setOLIDescription(oli, productType, values);

            Database.insert(oli, AccessLevel.USER_MODE);

            return oli.Id;

        } catch (Exception e) {
            throw new AuraHandledException(
                'Add Product failed: ' + e.getMessage()
            );
        }
    }

    /* =========================================================
       HELPER METHODS
       ========================================================= */

 /**
 * @description
 * Sets ProductCode based on Product Type configuration
 *
 * @param p
 *        Product2 record being created
 *
 * @param productType
 *        DeveloperName of Product Type
 *
 * @param values
 *        Dynamic field values from UI
 */
private static void setProductCode(
    Product2 p,
    String productType,
    Map<String, Object> values
) {
    Map<String, String> fieldByType = new Map<String, String>{
        'Product_Type_1' => 'Stock_Unit__c',
        'Product_Type_2' => 'Config_Metric__c'
    };

    if (!fieldByType.containsKey(productType)) {
        return;
    }

    String sourceField = fieldByType.get(productType);

    if (values.containsKey(sourceField) && values.get(sourceField) != null) {
        p.ProductCode = String.valueOf(values.get(sourceField));
    }
}


/**
 * @description
 * Creates and inserts Product2 record
 *
 * @param productType
 *        DeveloperName of Product Type
 *
 * @param values
 *        Dynamic field values from UI
 *
 * @return
 *        Inserted Product2 record
 */
private static Product2 createProduct(
    String productType,
    Map<String, Object> values
) {
    Product2 p = new Product2();
    p.IsActive = true;
    p.Product_Type__c = productType;

    if (!values.containsKey('Name') || values.get('Name') == null) {
        throw new AuraHandledException('Product Name is required.');
    }

    p.Name = String.valueOf(values.get('Name'));

    setProductCode(p, productType, values);

    Database.insert(p, AccessLevel.USER_MODE);
    return p;
}



    private static Opportunity getOpportunityWithPricebook(Id oppId) {

        Opportunity opp = [
            SELECT Id, Pricebook2Id
            FROM Opportunity
            WHERE Id = :oppId
            WITH USER_MODE
            LIMIT 1
        ];

        if (opp.Pricebook2Id == null) {
            Pricebook2 stdPb = [
                SELECT Id
                FROM Pricebook2
                WHERE IsStandard = true
                WITH USER_MODE
                LIMIT 1
            ];
            opp.Pricebook2Id = stdPb.Id;
            Database.update(opp, AccessLevel.USER_MODE);
        }
        return opp;
    }

    private static void ensureStandardPricebookEntry(
        Id productId,
        Decimal unitPrice
    ) {
        Pricebook2 stdPb = [
            SELECT Id
            FROM Pricebook2
            WHERE IsStandard = true
            WITH USER_MODE
            LIMIT 1
        ];

        List<PricebookEntry> existing = [
            SELECT Id
            FROM PricebookEntry
            WHERE Product2Id = :productId
            AND Pricebook2Id = :stdPb.Id
            WITH USER_MODE
            LIMIT 1
        ];

        if (existing.isEmpty()) {
            PricebookEntry pbe = new PricebookEntry(
                Pricebook2Id = stdPb.Id,
                Product2Id   = productId,
                UnitPrice    = unitPrice,
                IsActive     = true
            );
            Database.insert(pbe, AccessLevel.USER_MODE);
        }
    }
/**
 * @description
 * Sets Opportunity Line Item description
 * based on Product Type
 *
 * @param oli
 *        OpportunityLineItem being created
 *
 * @param productType
 *        DeveloperName of Product Type
 *
 * @param values
 *        Dynamic field values from UI
 */
    private static void setOLIDescription(
    OpportunityLineItem oli,
    String productType,
    Map<String, Object> values
) {
    if (productType == 'Product_Type_1'
        && values.get('Description') != null) {

        oli.Description = String.valueOf(values.get('Description'));

    } else if (productType == 'Product_Type_2'
        && values.get('Specification__c') != null) {

        oli.Description = String.valueOf(values.get('Specification__c'));
    }
}
@TestVisible
static void testSetProductCode(
    Product2 p,
    String productType,
    Map<String, Object> values
) {
    setProductCode(p, productType, values);
}

@TestVisible
static void testSetOLIDescription(
    OpportunityLineItem oli,
    String productType,
    Map<String, Object> values
) {
    setOLIDescription(oli, productType, values);
}

@TestVisible
static Opportunity testGetOpportunityWithPricebook(Id oppId) {
    return getOpportunityWithPricebook(oppId);
}

@TestVisible
static void testEnsureStandardPricebookEntry(Id productId, Decimal price) {
    ensureStandardPricebookEntry(productId, price);
}

}