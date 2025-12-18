/**
 * @description
 * Invocable Apex class used to automatically convert Leads into
 * Account, Contact, and Opportunity records.
 *
 * This class is designed to be called from Salesforce Flow.
 *
 * @author Rowthu Sravani
 */
public with sharing class AutoLeadConvert {
      /**
     * @description
     * Converts the given list of Lead Ids into Account, Contact,
     * and Opportunity records.
     *
     * @param leadIds
     *        List of Lead record Ids to be converted
     *
     * @return List<ConvertResponse>
     *         Result of each lead conversion including success status
     *         and created record Ids
     */
    @InvocableMethod(label='Auto Convert Lead')
    public static List<ConvertResponse> convertLead(List<Id> leadIds){

        List<ConvertResponse> responses = new List<ConvertResponse>();
        List<Database.LeadConvert> leadConverts = new List<Database.LeadConvert>();

        // Prepare lead convert requests
        for (Id leadId : leadIds) {
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(leadId);
            lc.setDoNotCreateOpportunity(false);
            lc.setConvertedStatus('Closed - Converted');
            leadConverts.add(lc);
        }

        // Bulk lead conversion (outside loop)
        List<Database.LeadConvertResult> results =
            Database.convertLead(leadConverts, false);

        // Process results
        for (Integer i = 0; i < results.size(); i++) {
            ConvertResponse resp = new ConvertResponse();
            Database.LeadConvertResult lcr = results[i];

            if (lcr.isSuccess()) {
                resp.success = true;
                resp.message = 'Lead converted successfully';
                resp.accountId = lcr.getAccountId();
                resp.contactId = lcr.getContactId();
                resp.opportunityId = lcr.getOpportunityId();
            } else {
                resp.success = false;
                resp.message = lcr.getErrors()[0].getMessage();
            }

            responses.add(resp);
        }

        return responses;
    }
     /**
     * @description
     * Wrapper class used to return lead conversion results
     * back to Flow.
     */
    public class ConvertResponse {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
        @InvocableVariable public Id accountId;
        @InvocableVariable public Id contactId;
        @InvocableVariable public Id opportunityId;
    }
}