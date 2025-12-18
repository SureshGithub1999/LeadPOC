/**
 * @description
 * Unit tests for ProductTypeFieldsetUtil
 */

@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ProductTypeFieldsetUtilTest {

    /**
     * @description
     * Sets up fake Product Type metadata for tests
     */
    @TestSetup
    private static void setupTestMetadata() {

    ProductTypeFieldsetUtil.testMetadata =
        new Map<String, Product_Type_Fieldset__mdt>{
            'VALID' => new Product_Type_Fieldset__mdt(
                Field_List__c       = 'A__c,B__c',
                Required_Fields__c  = 'A__c',
                Default_Values__c   = '{"A__c":"X"}'
            ),
            'INVALID_JSON' => new Product_Type_Fieldset__mdt(
                Field_List__c       = 'A__c',
                Required_Fields__c  = '',
                Default_Values__c   = '{bad json}'
            ),
            'BLANK_FIELDS' => new Product_Type_Fieldset__mdt(
                Field_List__c       = '',
                Required_Fields__c  = '',
                Default_Values__c   = ''
            )
        };
}


    /**
     * @description
     * Tests valid metadata with fields, required fields and defaults
     */
    @IsTest
static void testValidMetadata() {

    setupTestMetadata(); // 🔥 MOST IMPORTANT LINE

    ProductTypeFieldsetUtil.Fieldset fs =
        ProductTypeFieldsetUtil.getFieldsetForType('VALID');

    System.assertEquals(2, fs.fields.size());
    System.assertEquals(1, fs.required.size());
    System.assertEquals('X', fs.defaults.get('A__c'));
}



    /**
     * @description
     * Tests invalid JSON in Default_Values__c
     */
   @IsTest
static void testInvalidJsonDefaults() {

    setupTestMetadata();

    ProductTypeFieldsetUtil.Fieldset fs =
        ProductTypeFieldsetUtil.getFieldsetForType('INVALID_JSON');

    System.assertNotEquals(null, fs.defaults);
    System.assertEquals(0, fs.defaults.size());
}

@IsTest
static void testBlankAndEdgeCases() {

    setupTestMetadata();

    // 1️⃣ Blank product type
    ProductTypeFieldsetUtil.Fieldset fs1 =
        ProductTypeFieldsetUtil.getFieldsetForType('');
    System.assertEquals(0, fs1.fields.size());

    // 2️⃣ CSV with blanks and spaces
    ProductTypeFieldsetUtil.testMetadata.put(
        'EDGE',
        new Product_Type_Fieldset__mdt(
            Field_List__c      = 'A__c, , B__c , ',
            Required_Fields__c = ' ,A__c, ',
            Default_Values__c  = ''
        )
    );

    ProductTypeFieldsetUtil.Fieldset fs2 =
        ProductTypeFieldsetUtil.getFieldsetForType('EDGE');

    System.assertEquals(2, fs2.fields.size());
    System.assertEquals(1, fs2.required.size());
    System.assertEquals(0, fs2.defaults.size());
}



    /**
     * @description
     * Tests blank Field_List__c and Required_Fields__c
     */
   @IsTest
static void testBlankCsvFields() {

    setupTestMetadata();

    ProductTypeFieldsetUtil.Fieldset fs =
        ProductTypeFieldsetUtil.getFieldsetForType('BLANK_FIELDS');

    System.assertEquals(0, fs.fields.size());
    System.assertEquals(0, fs.required.size());
}


    /**
     * @description
     * Tests metadata not found scenario
     */
    @IsTest
static void testMetadataNotFound() {

    setupTestMetadata();

    ProductTypeFieldsetUtil.Fieldset fs =
        ProductTypeFieldsetUtil.getFieldsetForType('UNKNOWN');

    System.assertEquals(0, fs.fields.size());
}


    /**
     * @description
     * Creates a standard test user
     *
     * @return User
     */
    private static User createAdminUser() {

    Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'System Administrator'
        LIMIT 1
    ];

    return new User(
        Alias              = 'ptadm',
        Email              = 'ptadmin@test.com',
        EmailEncodingKey   = 'UTF-8',
        LastName           = 'Admin',
        LanguageLocaleKey  = 'en_US',
        LocaleSidKey       = 'en_US',
        ProfileId          = p.Id,
        TimeZoneSidKey     = 'Asia/Kolkata',
        Username           = 'ptadmin' + System.currentTimeMillis() + '@test.com'
    );
}
@IsTest
static void testCacheHitCoverage() {
    ProductTypeFieldsetUtil.Fieldset fs1 =
        ProductTypeFieldsetUtil.getFieldsetForType('VALID');

    ProductTypeFieldsetUtil.Fieldset fs2 =
        ProductTypeFieldsetUtil.getFieldsetForType('VALID');

    System.assertEquals(fs1, fs2);
}

}