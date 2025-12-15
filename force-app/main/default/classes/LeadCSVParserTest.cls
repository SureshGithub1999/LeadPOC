@IsTest
public class LeadCSVParserTest {

    // Utility method to create CSV file and return ContentDocumentId
    private static Id createCSVFile() {

        String csvData =
            'FirstName,LastName,Email,Phone,Company,LeadSource,Country,City,State,Region,ProductInterest,Industry,EstimatedBudget,InterestLevel,Imported\n' +
            'John,Doe,john@test.com,9999999999,Test Company,Web,USA,New York,NY,North,CRM,IT,10000,High,true\n' +
            '\n' +
            ',Smith,invalid@test.com,8888888888,,Web,USA,Boston,MA,East,ERP,Finance,abc,Medium,false\n';

        ContentVersion cv = new ContentVersion(
            Title = 'LeadUpload',
            PathOnClient = 'LeadUpload.csv',
            VersionData = Blob.valueOf(csvData)
        );
        insert cv;

        // Get ContentDocumentId
        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        return cv.ContentDocumentId;
    }

    @IsTest
    static void testParseCSV_SuccessAndFailure() {

        // Step 1: Create CSV file
        Id contentDocumentId = createCSVFile();

        // Step 2: Prepare Invocable input
        LeadCSVParser.ParserRequest req = new LeadCSVParser.ParserRequest();
        req.contentDocumentId = contentDocumentId;

        List<LeadCSVParser.ParserRequest> reqList =
            new List<LeadCSVParser.ParserRequest>{ req };

        Test.startTest();
        List<LeadCSVParser.ParseResult> results =
            LeadCSVParser.parseCSV(reqList);
        Test.stopTest();

        // Step 3: Assertions
        System.assertEquals(1, results.size(), 'One result expected');

        LeadCSVParser.ParseResult res = results[0];
        System.assert(res.SuccessCount > 0, 'At least one lead should succeed');
        System.assert(res.FailureCount > 0, 'At least one lead should fail');
        System.assertEquals(contentDocumentId, res.ContentDocumentId);

        // Step 4: Validate Leads created
        List<Lead> leads = [
            SELECT Id, FirstName, LastName, Company
            FROM Lead
            WHERE Email = 'john@test.com'
        ];
        System.assertEquals(1, leads.size(), 'One valid Lead should be inserted');

        // Step 5: Validate failed records stored in custom object
        List<Lead__c> failedLeads = [
            SELECT Id, Row_Number__c, Error_Message__c
            FROM Lead__c
        ];
        System.assert(!failedLeads.isEmpty(), 'Failed records should be logged');
    }

    @IsTest
    static void testParseCSV_BlankFile() {

        String csvData = 'FirstName,LastName,Email\n';

        ContentVersion cv = new ContentVersion(
            Title = 'EmptyCSV',
            PathOnClient = 'Empty.csv',
            VersionData = Blob.valueOf(csvData)
        );
        insert cv;

        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        LeadCSVParser.ParserRequest req = new LeadCSVParser.ParserRequest();
        req.contentDocumentId = cv.ContentDocumentId;

        Test.startTest();
        List<LeadCSVParser.ParseResult> results =
            LeadCSVParser.parseCSV(new List<LeadCSVParser.ParserRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
    }
}