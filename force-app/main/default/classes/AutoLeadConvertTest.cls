/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 *
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@IsTest
public class AutoLeadConvertTest {

    private static User createTestUser() {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        return new User(
            Alias = 'tuser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com'
        );
    }

    private static List<Lead> createTestLeads(Integer count) {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < count; i++) {
            leads.add(new Lead(
                FirstName = 'Test',
                LastName = 'Lead' + i,
                Company = 'Test Company ' + i + '_' + Datetime.now().getTime(),
                Status = 'Open - Not Contacted',
                Email = 'test' + i + '@example.com',
                Phone = '9' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 9)));
        }
        insert leads;
        return leads;
    }

    @IsTest
    static void testSuccessfulLeadConversion() {

        User u = createTestUser();
        insert u;

        System.runAs(u) {

            List<Lead> leads = createTestLeads(2);

            List<Id> leadIds = new List<Id>();
            for (Lead l : leads) {
                leadIds.add(l.Id);
            }

            Test.startTest();
            List<AutoLeadConvert.ConvertResponse> responses =
                AutoLeadConvert.convertLead(leadIds);
            Test.stopTest();

            System.assertEquals(2, responses.size(), 'Expected exactly 2 conversion responses for the provided lead IDs');

            for (AutoLeadConvert.ConvertResponse resp : responses) {
                System.assert(
                    resp.success,
                    'Lead conversion failed: ' + resp.message
                );
                System.assertNotEquals(null, resp.accountId, 'Expected Account Id to be populated after lead conversion');
                System.assertNotEquals(null, resp.contactId, 'Expected Contact Id to be populated after lead conversion');
                System.assertNotEquals(null, resp.opportunityId, 'Expected Opportunity Id to be populated after lead conversion');
            }
        }
    }
}