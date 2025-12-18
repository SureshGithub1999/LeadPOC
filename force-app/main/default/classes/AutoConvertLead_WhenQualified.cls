/**
 * @description
 * Invocable Apex class used to automatically convert Leads
 * when they reach the Qualified stage.
 *
 * This class is designed to be called from a Salesforce Flow.
 *
 * Note:
 * Lead conversion is executed in bulk using a single DML call
 * to comply with Salesforce governor limits.
 @auther : Vaibhav Kadam 
    * @date  : 17June 2024
 */


public with sharing class AutoConvertLead_WhenQualified {

    /**
     * @description
     * Converts the given list of Lead Ids into Account, Contact,
     * and Opportunity records.
     *
     * @param leadIds
     *        List of Lead record Ids passed from Flow
     *
     * @return List<ConvertResponse>
     *         Conversion result for each Lead
     */


    @InvocableMethod(label='Auto Convert Lead')
    public static List<ConvertResponse> convertLead(List<Id> leadIds) {

        List<ConvertResponse> responses = new List<ConvertResponse>();

        // Safety check
        if (leadIds == null || leadIds.isEmpty()) {
            return responses;
        }

        // Step 1: Prepare LeadConvert requests
        List<Database.LeadConvert> convertRequests = new List<Database.LeadConvert>();

        for (Id leadId : leadIds) {
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(leadId);
            lc.setDoNotCreateOpportunity(false);
            lc.setConvertedStatus('Closed - Converted');
            convertRequests.add(lc);
        }

        // Step 2: Convert all leads in ONE DML call
        List<Database.LeadConvertResult> results =
            Database.convertLead(convertRequests, false);

        // Step 3: Build response for Flow
        for (Database.LeadConvertResult result : results) {
            ConvertResponse resp = new ConvertResponse();
            resp.success = result.isSuccess();
            resp.message = result.isSuccess()
                ? 'Converted Successfully'
                : result.getErrors()[0].getMessage();
            responses.add(resp);
        }

        return responses;
    }
 /**
     * @description
     * Wrapper class used to send Lead conversion
     * status and message back to Salesforce Flow.
     */

    // Wrapper class for Flow
    public class ConvertResponse {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
    }
}