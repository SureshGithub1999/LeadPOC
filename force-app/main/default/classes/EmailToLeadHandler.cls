/**
 * @description Inbound Email Handler to create Leads from CSV attachments
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class EmailToLeadHandler implements Messaging.InboundEmailHandler {

    /**
     * @description Handles inbound email and processes CSV attachments
     * @param email    The inbound email message
     * @param envelope The inbound email envelope
     * @return Messaging.InboundEmailResult
     */
    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        List<Lead> leadsToInsert = new List<Lead>();

        try {
            Boolean attachmentFound = processAttachments(email, leadsToInsert);

            if (!attachmentFound) {
                sendFailureEmail(email.fromAddress, 'No CSV attachment was found.');
                result.success = false;
                return result;
            }

            if (leadsToInsert.isEmpty()) {
                sendFailureEmail(
                    email.fromAddress,
                    'CSV processed but no valid lead records were found.'
                );
                result.success = true;
                return result;
            }

            insertLeads(leadsToInsert, email.fromAddress);
            result.success = true;
            return result;

        } catch (Exception e) {
            sendFailureEmail(
                email.fromAddress,
                'Unexpected error occurred: ' + e.getMessage()
            );
            result.success = false;
            return result;
        }
    }

    /**
     * @description Processes all email attachments
     * @param email The inbound email
     * @param leads The lead list to populate
     * @return TRUE if at least one attachment was found
     */
    private Boolean processAttachments(
        Messaging.InboundEmail email,
        List<Lead> leads
    ) {
        Boolean found = false;

        if (email.binaryAttachments != null) {
            for (Messaging.InboundEmail.BinaryAttachment att : email.binaryAttachments) {
                found = true;
                processCSV(att.fileName, att.body.toString(), leads);
            }
        }

        if (email.textAttachments != null) {
            for (Messaging.InboundEmail.TextAttachment att : email.textAttachments) {
                found = true;
                processCSV(att.fileName, att.body, leads);
            }
        }

        return found;
    }

    /**
     * @description Inserts leads and sends notification emails
     * @param leads     Leads to insert
     * @param fromEmail Sender email address
     */
    private void insertLeads(List<Lead> leads, String fromEmail) {
        Database.SaveResult[] results = Database.insert(leads, false);

        Integer successCount = 0;
        List<String> errors = new List<String>();

        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                successCount++;
            } else {
                for (Database.Error err : results[i].getErrors()) {
                    errors.add('Row ' + (i + 2) + ': ' + err.getMessage());
                }
            }
        }

        if (successCount > 0) {
            sendSuccessEmail(fromEmail, successCount);
        }

        if (!errors.isEmpty()) {
            sendFailureEmail(fromEmail, String.join(errors, '\n'));
        }
    }

    /**
     * @description Parses CSV file and creates Lead records
     * @param fileName CSV file name
     * @param body     CSV content
     * @param leads    Lead list to populate
     */
    private void processCSV(String fileName, String body, List<Lead> leads) {
        if (String.isBlank(fileName) || !fileName.toLowerCase().endsWith('.csv')) {
            return;
        }

        List<String> rows = body.split('\n');
        Boolean skipHeader = true;

        for (String row : rows) {
            row = row.trim();

            if (row == '') {
                continue;
            }

            if (skipHeader) {
                skipHeader = false;
                continue;
            }

            List<String> cols = row.contains('\t')
                ? row.split('\t')
                : row.split(',');

            if (cols.size() < 8) {
                continue;
            }

            leads.add(new Lead(
                FirstName          = cols[0].trim(),
                LastName           = cols[1].trim(),
                Email              = cols[2].trim(),
                Phone              = cols[3].trim(),
                Company            = cols[4].trim(),
                LeadSource         = cols[5].trim(),
                Status             = cols[6].trim(),
                ProductInterest__c = cols[7].trim(),
                Region__c          = (cols.size() > 8) ? cols[8].trim() : null
            ));
        }
    }

    /**
     * @description Sends success email
     * @param toEmail Recipient email
     * @param count   Number of leads created
     */
    private void sendSuccessEmail(String toEmail, Integer count) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { toEmail });
        mail.setSubject('Lead Import Successful');
        mail.setPlainTextBody('Total Leads Created: ' + count);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }

    /**
     * @description Sends failure email
     * @param toEmail Recipient email
     * @param message Failure message
     */
    private void sendFailureEmail(String toEmail, String message) {

        if (String.isBlank(toEmail)) {
    return;
}


        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { toEmail });
        mail.setSubject('Lead Import Failed');
        mail.setPlainTextBody(message);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}