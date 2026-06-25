public with sharing class MetadataChangeSyncBatch implements Database.Batchable<MetadataDefinition>, Database.AllowsCallouts {
    private static final String API_VERSION = 'v66.0';
    private static final Integer QUERY_LIMIT_PER_TYPE = 8000;
    private static final Integer LOOKBACK_MINUTES = 10;
    private DateTime changedSince;

    public MetadataChangeSyncBatch() {
        this(false);
    }

    public MetadataChangeSyncBatch(Boolean syncAll) {
        this.changedSince = syncAll ? null : System.now().addMinutes(-LOOKBACK_MINUTES);
    }

    public List<MetadataDefinition> start(Database.BatchableContext bc) {
        return MetadataDefinition.Init();
    }

    public void execute(Database.BatchableContext bc, List<MetadataDefinition> scope) {
        List<MetadataRow> metadataRows = new List<MetadataRow>();

        for (MetadataDefinition definition : scope) {
            metadataRows.addAll(queryMetadataRows(definition, this.changedSince));
        }

        if (!metadataRows.isEmpty()) {
            saveMetadataChanges(metadataRows);
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Intentionally blank.
    }

    private static List<MetadataRow> queryMetadataRows(MetadataDefinition definition, DateTime changedSince) {
        if (definition.IsTooling == true) {
            return queryToolingRows(definition, changedSince);
        }
        return querySObjectRows(definition, changedSince);
    }

    private static List<MetadataRow> queryToolingRows(MetadataDefinition definition, DateTime changedSince) {
        List<MetadataRow> rows = new List<MetadataRow>();
        Boolean excludeLastModifiedById = definition.Name == 'FlexiPage';
        String selectFields = 'Id, ' + definition.Key + ', LastModifiedDate' + (excludeLastModifiedById ? '' : ', LastModifiedById');
        String soql =
            'SELECT ' + selectFields + ' ' +
            'FROM ' + definition.Name +
            getToolingWhereClause(changedSince) +
            ' ORDER BY LastModifiedDate DESC LIMIT ' + QUERY_LIMIT_PER_TYPE;

        try {
            String response = queryTooling(soql);
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response);
            List<Object> records = (List<Object>) payload.get('records');
            if (records == null) {
                return rows;
            }

            for (Object rawRecord : records) {
                Map<String, Object> record = (Map<String, Object>) rawRecord;
                rows.add(new MetadataRow(
                    definition.Name,
                    String.valueOf(record.get(definition.Key)),
                    parseIsoDateTime(String.valueOf(record.get('LastModifiedDate'))),
                    excludeLastModifiedById ? null : parseId(String.valueOf(record.get('LastModifiedById')))
                ));
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'Unable to query tooling metadata type ' + definition.Name + ': ' + ex.getMessage());
        }

        return rows;
    }

    private static List<MetadataRow> querySObjectRows(MetadataDefinition definition, DateTime changedSince) {
        List<MetadataRow> rows = new List<MetadataRow>();
        String soql =
            'SELECT Id, ' + definition.Key + ', LastModifiedDate, LastModifiedById ' +
            'FROM ' + definition.Name +
            getSObjectWhereClause(changedSince) +
            ' ORDER BY LastModifiedDate DESC LIMIT ' + QUERY_LIMIT_PER_TYPE;

        try {
            for (SObject record : Database.query(soql)) {
                rows.add(new MetadataRow(
                    definition.Name,
                    String.valueOf(record.get(definition.Key)),
                    (DateTime) record.get('LastModifiedDate'),
                    (Id) record.get('LastModifiedById')
                ));
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'Unable to query metadata type ' + definition.Name + ': ' + ex.getMessage());
        }

        return rows;
    }

    private static void saveMetadataChanges(List<MetadataRow> rows) {
        Set<String> typeNames = new Set<String>();
        Set<String> apiNames = new Set<String>();
        for (MetadataRow row : rows) {
            if (String.isBlank(row.apiName)) {
                continue;
            }
            typeNames.add(row.typeName);
            apiNames.add(row.apiName);
        }
        if (typeNames.isEmpty() || apiNames.isEmpty()) {
            return;
        }

        Map<String, Metadata_Change__c> existingByKey = new Map<String, Metadata_Change__c>();
        for (Metadata_Change__c existing : [
            SELECT Id, API_Name__c, Type__c
            FROM Metadata_Change__c
            WHERE Type__c IN :typeNames
            AND API_Name__c IN :apiNames
        ]) {
            existingByKey.put(buildKey(existing.Type__c, existing.API_Name__c), existing);
        }

        List<Metadata_Change__c> changesToSave = new List<Metadata_Change__c>();
        Set<String> keysToSave = new Set<String>();
        for (MetadataRow row : rows) {
            if (String.isBlank(row.apiName)) {
                continue;
            }

            String key = buildKey(row.typeName, row.apiName);
            if (keysToSave.contains(key)) {
                continue;
            }
            keysToSave.add(key);

            Metadata_Change__c changeRecord = existingByKey.containsKey(key)
                ? existingByKey.get(key)
                : new Metadata_Change__c();
            changeRecord.API_Name__c = row.apiName;
            changeRecord.Type__c = row.typeName;
            changeRecord.Last_Modified_Date_Time__c = row.lastModifiedDateTime;
            changeRecord.Last_Modified_By__c = row.lastModifiedById;
            changesToSave.add(changeRecord);
        }

        if (!changesToSave.isEmpty()) {
            upsert changesToSave;
        }
    }

    private static String buildKey(String typeName, String apiName) {
        return String.valueOf(typeName) + '|' + String.valueOf(apiName);
    }

    private static Id parseId(String value) {
        if (String.isBlank(value) || value == 'null') {
            return null;
        }
        return (Id) value;
    }

    private static String getToolingWhereClause(DateTime changedSince) {
        return changedSince == null ? '' : ' WHERE LastModifiedDate >= ' + formatToolingDateTime(changedSince);
    }

    private static String getSObjectWhereClause(DateTime changedSince) {
        return changedSince == null ? '' : ' WHERE LastModifiedDate >= :changedSince';
    }

    private static String formatToolingDateTime(DateTime value) {
        return value.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    private static DateTime parseIsoDateTime(String value) {
        if (String.isBlank(value) || value == 'null') {
            return null;
        }

        String normalized = value.removeEnd('Z').replace('T', ' ');
        Integer dotIndex = normalized.indexOf('.');
        if (dotIndex > -1) {
            normalized = normalized.substring(0, dotIndex);
        }
        return DateTime.valueOfGmt(normalized);
    }

    private class MetadataRow {
        public String typeName;
        public String apiName;
        public DateTime lastModifiedDateTime;
        public Id lastModifiedById;

        public MetadataRow(String typeName, String apiName, DateTime lastModifiedDateTime, Id lastModifiedById) {
            this.typeName = typeName;
            this.apiName = apiName;
            this.lastModifiedDateTime = lastModifiedDateTime;
            this.lastModifiedById = lastModifiedById;
        }
    }

    private static String queryTooling(String soql) {
        String endpointSuffix = '/tooling/query/?q=' + EncodingUtil.urlEncode(soql, 'UTF-8');
        return Utils.sendGetRequest(endpointSuffix);
    }
}
