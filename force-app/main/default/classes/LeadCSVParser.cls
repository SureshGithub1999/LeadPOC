public with sharing class LeadCSVParser {

    //
    // Input from Flow
    //
    public class ParserRequest {
        @InvocableVariable(label='Content Document Id')
        public String contentDocumentId;
    }

    //
    // Output back to Flow
    //
    public class ParseResult {
        @InvocableVariable public Integer SuccessCount;
        @InvocableVariable public Integer FailureCount;
        @InvocableVariable public String ContentDocumentId;
    }

    @InvocableMethod(label='Parse CSV and Insert Leads')
    public static List<ParseResult> parseCSV(List<ParserRequest> reqList) {

        List<ParseResult> output = new List<ParseResult>();

        for (ParserRequest req : reqList) {

            Integer successCount = 0;
            Integer failureCount = 0;

            System.debug('=== START PARSE PROCESS ===');
            System.debug('>>> Received ContentDocumentId: ' + req.contentDocumentId);

            try {
                // Fetch latest ContentVersion
                ContentVersion cv = [
                    SELECT VersionData
                    FROM ContentVersion
                    WHERE ContentDocumentId = :req.contentDocumentId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];

                String fileBody = cv.VersionData.toString();
                fileBody = fileBody.replace('\r', '');
                List<String> lines = fileBody.split('\n');

                List<Lead> leadList = new List<Lead>();
                List<Integer> lineIndexList = new List<Integer>();
                List<Lead__c> failedList = new List<Lead__c>();

                // Skip header
                for (Integer lineNum = 1; lineNum < lines.size(); lineNum++) {

                    String line = lines[lineNum].trim();

                    if (String.isBlank(line)) {
                        failureCount++;
                        failedList.add(new Lead__c(
                            Row_Number__c = lineNum,
                            Error_Message__c = 'Blank row'
                        ));
                        continue;
                    }

                    List<String> cols = line.split(',');

                    Lead l = new Lead(
                        FirstName            = getSafe(cols, 0),
                        LastName             = getSafe(cols, 1),
                        Email                = getSafe(cols, 2),
                        Phone                = getSafe(cols, 3),
                        Company              = getSafe(cols, 4),
                        LeadSource           = getSafe(cols, 5),

                        Country              = getSafe(cols, 6),
                        City                 = getSafe(cols, 7),
                        State                = getSafe(cols, 8),
                        Region__c            = getSafe(cols, 9),

                        ProductInterest__c   = getSafe(cols, 10),
                        Industry             = getSafe(cols, 11),
                        Estimated_Budget__c  = parseDecimal(getSafe(cols, 12)),
                        Interest_Level__c    = getSafe(cols, 13),
                        Imported_Lead__c     = parseBoolean(getSafe(cols, 14))
                    );

                    leadList.add(l);
                    lineIndexList.add(lineNum);
                }

                if (!leadList.isEmpty()) {

                    Database.SaveResult[] results = Database.insert(leadList, false);

                    for (Integer i = 0; i < results.size(); i++) {

                        Integer originalLine = lineIndexList[i];

                        if (results[i].isSuccess()) {
                            successCount++;
                        } else {
                            failureCount++;

                            Database.Error err = results[i].getErrors()[0];

                            failedList.add(new Lead__c(
                                Name = leadList[i].FirstName,
                                Row_Number__c = originalLine,
                                Error_Message__c = err.getMessage()
                            ));
                        }
                    }
                }

                if (!failedList.isEmpty()) {
                    insert failedList;
                }

            } catch (Exception e) {

              successCount = 0;
              failureCount = 1;

    System.debug('Error while parsing CSV: ' + e.getMessage());
            }

            ParseResult res = new ParseResult();
            res.SuccessCount = successCount;
            res.FailureCount = failureCount;
            res.ContentDocumentId = req.contentDocumentId;

            output.add(res);
        }

        return output;
    }

    // ----------------- Helper Methods -----------------

    private static String getSafe(List<String> cols, Integer index) {
        return (cols.size() > index) ? cols[index].trim() : null;
    }

    private static Decimal parseDecimal(String val) {
        if (String.isBlank(val)) return null;
        try {
            return Decimal.valueOf(val);
        } catch (Exception e) {
            return null;
        }
    }

    private static Boolean parseBoolean(String val) {
        if (String.isBlank(val)) return false;
        val = val.trim().toLowerCase();
        return val == 'true' || val == 'yes' || val == '1';
    }
}