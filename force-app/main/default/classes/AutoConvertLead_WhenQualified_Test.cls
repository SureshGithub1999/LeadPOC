/**
 * @description
 * Test class for AutoConvertLead_WhenQualified.
 *
 * This test class validates:
 * 1. Successful Lead conversion using Invocable Apex.
 * 2. Null input handling (guard clause).
 *
 * The class follows Salesforce and PMD best practices:
 * - Uses System.runAs()
 * - Includes assertion messages
 * - Avoids seeAllData=true
 * @auther : vaibhav kadam 
    * @date  : 17June 2025
 */
@IsTest
public class AutoConvertLead_WhenQualified_Test {

    /**
     * @description
     * Utility method to create a valid Lead record
     * required for Lead conversion.
     *
     * @return Lead
     */
    private static Lead createValidLead() {
        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            Email = 'test@example.com',
            Phone = '9876543210'
        );
        insert l;
        return l;
    }

    /**
     * @description
     * Test method to validate successful Lead conversion.
     * Covers the main execution path of the Invocable method.
     * Uses System.runAs() to satisfy PMD rule.
     */
    @IsTest
    static void testSuccessfulConversion() {

        // Fetch Standard User profile
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        // Create test user
        User testUser = new User(
            Alias = 'tuser',
            Email = 'tuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'tuser' + System.currentTimeMillis() + '@test.com'
        );
        insert testUser;

        // Execute logic as test user
        System.runAs(testUser) {

            Lead goodLead = createValidLead();

            Test.startTest();
            List<AutoConvertLead_WhenQualified.ConvertResponse> responses =
                AutoConvertLead_WhenQualified.convertLead(
                    new List<Id>{ goodLead.Id }
                );
            Test.stopTest();

            // Assertions
            System.assertEquals(
                1,
                responses.size(),
                'One response should be returned for one Lead'
            );

            System.assertEquals(
                true,
                responses[0].success,
                'Lead should be converted successfully'
            );

            System.assertEquals(
                'Converted Successfully',
                responses[0].message,
                'Success message should indicate conversion completion'
            );
        }
    }

    /**
     * @description
     * Test method to validate null input handling.
     * Ensures the method safely returns an empty response list.
     */
    @IsTest
static void testNullInput() {

    // Reuse Standard User profile
    Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'Standard User'
        LIMIT 1
    ];

    User testUser = new User(
        Alias = 'tuser2',
        Email = 'tuser2@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'User',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = p.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        Username = 'tuser2' + System.currentTimeMillis() + '@test.com'
    );
    insert testUser;

    System.runAs(testUser) {

        Test.startTest();
        List<AutoConvertLead_WhenQualified.ConvertResponse> responses =
            AutoConvertLead_WhenQualified.convertLead(null);
        Test.stopTest();

        System.assertEquals(
            0,
            responses.size(),
            'No responses should be returned when input is null'
        );
    }
}
}