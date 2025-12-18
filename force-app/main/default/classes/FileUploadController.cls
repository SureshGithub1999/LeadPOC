/**
 * @description
 * Controller class used for fetching and deleting uploaded files
 * related to a Salesforce record. This class is designed to be
 * called from Lightning Web Components or Aura components.
 *
 * @author Rowthu Sravani
 */
public with sharing class FileUploadController{
    /**
     * @description
     * Retrieves the latest ContentVersion details for the given
     * ContentDocument Ids.
     *
     * @param documentIds
     *        List of ContentDocument Ids
     *
     * @return List<ContentVersion>
     *         Latest file versions with metadata
     */
    @AuraEnabled(cacheable=false)
    public static List<ContentVersion> getFileDetails(List<Id> documentIds) {

        //  //  CRUD check for READ access
        // if (!Schema.sObjectType.ContentVersion.isAccessible()) {
        //     throw new AuraHandledException('You do not have permission to access files.');
        // }

        return [
            SELECT Id, Title, ContentSize, FileType, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :documentIds
            AND IsLatest = true
            WITH SECURITY_ENFORCED
        ];
    }
     /**
     * @description
     * Deletes a file (ContentDocument) from Salesforce.
     *
     * @param contentDocumentId
     *        Id of the ContentDocument to be deleted
     */
    @AuraEnabled
    public static void deleteFile(Id contentDocumentId) {
        delete [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId];
    }
}