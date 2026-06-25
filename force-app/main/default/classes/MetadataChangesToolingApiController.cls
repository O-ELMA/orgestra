public with sharing class MetadataChangesToolingApiController {
    private static final Integer DEFAULT_CHANGE_LIMIT = 10000;

    public class MetadataChangeRow {
        @AuraEnabled public String id;
        @AuraEnabled public String apiName;
        @AuraEnabled public String typeName;
        @AuraEnabled public DateTime lastModifiedDateTime;
        @AuraEnabled public Id lastModifiedById;
        @AuraEnabled public String lastModifiedByName;

        public MetadataChangeRow(Metadata_Change__c changeRecord) {
            this.id = changeRecord.Id;
            this.apiName = changeRecord.API_Name__c;
            this.typeName = changeRecord.Type__c;
            this.lastModifiedDateTime = changeRecord.Last_Modified_Date_Time__c;
            this.lastModifiedById = changeRecord.Last_Modified_By__c;
            this.lastModifiedByName = changeRecord.Last_Modified_By__r == null ? null : changeRecord.Last_Modified_By__r.Name;
        }
    }

    @AuraEnabled
    public static List<MetadataChangeRow> getMetadataChanges(String typeFilter, String apiNameFilter, String changedAfter, Id lastModifiedById) {
        List<String> whereClauses = new List<String>();

        if (String.isNotBlank(typeFilter)) {
            whereClauses.add('Type__c = \'' + String.escapeSingleQuotes(typeFilter.trim()) + '\'');
        }

        if (String.isNotBlank(apiNameFilter)) {
            whereClauses.add('API_Name__c LIKE \'%' + String.escapeSingleQuotes(apiNameFilter.trim()) + '%\'');
        }

        DateTime changedAfterDateTime = parseDateTime(changedAfter);
        if (changedAfterDateTime != null) {
            whereClauses.add('Last_Modified_Date_Time__c > :changedAfterDateTime');
        }

        if (lastModifiedById != null) {
            whereClauses.add('Last_Modified_By__c = :lastModifiedById');
        }

        String soql = 'SELECT Id, API_Name__c, Type__c, Last_Modified_Date_Time__c, Last_Modified_By__c, Last_Modified_By__r.Name ' +
            'FROM Metadata_Change__c';
        if (!whereClauses.isEmpty()) {
            soql += ' WHERE ' + String.join(whereClauses, ' AND ');
        }
        soql += ' ORDER BY Last_Modified_Date_Time__c DESC LIMIT ' + DEFAULT_CHANGE_LIMIT;

        List<MetadataChangeRow> rows = new List<MetadataChangeRow>();
        for (Metadata_Change__c changeRecord : Database.query(soql)) {
            rows.add(new MetadataChangeRow(changeRecord));
        }
        return rows;
    }

    private static DateTime parseDateTime(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        String normalized = value.trim();
        if (normalized.endsWith('Z')) {
            normalized = normalized.removeEnd('Z');
        }
        normalized = normalized.replace('T', ' ');
        Integer dotIndex = normalized.indexOf('.');
        if (dotIndex > -1) {
            normalized = normalized.substring(0, dotIndex);
        }

        return DateTime.valueOfGmt(normalized);
    }
}
