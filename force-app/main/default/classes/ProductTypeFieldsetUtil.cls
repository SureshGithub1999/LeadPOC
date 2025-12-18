/**
 * @description
 * Utility to fetch fieldset configuration
 * based on Product Type custom metadata
 */
public with sharing class ProductTypeFieldsetUtil {



    /**
     * @description
     * Test-only metadata override map
     * Used to inject fake Product_Type_Fieldset__mdt records
     * during unit testing
     */
    @TestVisible
    private static Map<String, Product_Type_Fieldset__mdt> testMetadata;

    /**
     * @description
     * DTO representing fieldset configuration
     */
    public class Fieldset {
        @AuraEnabled public List<String> fields   = new List<String>();
        @AuraEnabled public List<String> required = new List<String>();
        @AuraEnabled public Map<String, Object> defaults = new Map<String, Object>();
    }

    /**
     * @description
     * Returns fieldset configuration for a product type
     *
     * @param productTypeDevName
     *        DeveloperName of Product_Type_Fieldset__mdt
     *
     * @return Fieldset configuration
     */
    @AuraEnabled
    public static Fieldset getFieldsetForType(String productTypeDevName) {

        Fieldset fs = new Fieldset();

        if (String.isBlank(productTypeDevName)) {
            return fs;
        }

        if (!Test.isRunningTest() &&!Schema.sObjectType.Product_Type_Fieldset__mdt.isAccessible()) {
            return fs;
        }

        Product_Type_Fieldset__mdt metadata =
            loadMetadata(productTypeDevName);

        if (metadata == null) {
            return fs;
        }

        fs.fields   = parseCsv(metadata.Field_List__c);
        fs.required = parseCsv(metadata.Required_Fields__c);
        fs.defaults = parseDefaults(metadata.Default_Values__c);

        return fs;
    }

    /* =========================================================
       METADATA LOADER
       ========================================================= */

    /**
     * @description
     * Loads Product Type metadata record
     *
     * @param developerName
     *        DeveloperName of metadata record
     *
     * @return Product_Type_Fieldset__mdt record or null
     */
    private static Product_Type_Fieldset__mdt loadMetadata(String developerName) {

        /* Test override */
        if (Test.isRunningTest() && testMetadata != null) {
            return testMetadata.get(developerName);
        }

        List<Product_Type_Fieldset__mdt> records = [
            SELECT Field_List__c,
                   Required_Fields__c,
                   Default_Values__c
            FROM Product_Type_Fieldset__mdt
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];

        return records.isEmpty() ? null : records[0];
    }

    /* =========================================================
       PARSERS
       ========================================================= */

    /**
     * @description
     * Parses comma-separated values into a list
     *
     * @param value
     *        Comma-separated string
     *
     * @return List of trimmed values
     */
    private static List<String> parseCsv(String value) {

        List<String> result = new List<String>();

        if (String.isBlank(value)) {
            return result;
        }

        for (String item : value.split(',')) {
            String trimmed = item.trim();
            if (trimmed != '') {
                result.add(trimmed);
            }
        }

        return result;
    }



    /**
     * @description
     * Safely parses JSON defaults
     *
     * @param jsonValue
     *        JSON string from metadata
     *
     * @return Map of default values
     */
    private static Map<String, Object> parseDefaults(String jsonValue) {

        if (String.isBlank(jsonValue)) {
            return new Map<String, Object>();
        }

        try {
            return (Map<String, Object>)
                JSON.deserializeUntyped(jsonValue);
        } catch (Exception ex) {
            return new Map<String, Object>();
        }
    }

}