@IsTest
public class FileUploadControllerTest {

     /**
     * Create a standard test user
     *
     * @return User
     *         Newly created test user
     */
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

     /**
     * Utility method to create a test file
     *
     * @return ContentVersion
     *         Newly created ContentVersion record
     */
    private static ContentVersion createTestFile() {
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test File Content'),
            IsMajorVersion = true
        );
        insert cv;
        return cv;
    }

    /**
     * Test getFileDetails()
     */
    @IsTest
    static void testGetFileDetails() {

        User u = createTestUser();
        insert u;

        System.runAs(u) {

            // Create test file
            ContentVersion cv = createTestFile();

            // Fetch ContentDocumentId
            Id contentDocumentId = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
            ].ContentDocumentId;

            Test.startTest();
            List<ContentVersion> result =
                FileUploadController.getFileDetails(
                    new List<Id>{ contentDocumentId }
                );
            Test.stopTest();

            // Assertions
            System.assertEquals(1, result.size(), 'One file should be returned');
            System.assertEquals('Test File', result[0].Title, 'Title should match');
            System.assertEquals(
                contentDocumentId,
                result[0].ContentDocumentId,
                'ContentDocumentId should match'
            );
            System.assert(
                result[0].ContentSize > 0,
                'Content size should be populated'
            );
        }
    }


    /**
     * Test deleteFile()
     */
    @IsTest
    static void testDeleteFile() {

        User u = createTestUser();
        insert u;

        System.runAs(u) {

        // Create test file
        ContentVersion cv = createTestFile();

        // Fetch ContentDocumentId
        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;

        Test.startTest();
        FileUploadController.deleteFile(contentDocumentId);
        Test.stopTest();

        // Verify deletion
        Integer countDocs = [
            SELECT COUNT()
            FROM ContentDocument
            WHERE Id = :contentDocumentId
        ];

        System.assertEquals(0, countDocs, 'File should be deleted');
    }
}
}