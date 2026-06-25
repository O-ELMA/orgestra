public with sharing class MetadataChangeSyncScheduler implements System.Schedulable {
    public static final String JOB_NAME_PREFIX = 'Metadata Change Sync';
    private static final List<Integer> SCHEDULE_MINUTES = new List<Integer>{ 0, 10, 20, 30, 40, 50 };
    private static final Integer DEFAULT_BATCH_SIZE = 20;

    public void execute(System.SchedulableContext schedulableContext) {
        Database.executeBatch(new MetadataChangeSyncBatch(), DEFAULT_BATCH_SIZE);
    }

    public static Id runNow() {
        return Database.executeBatch(new MetadataChangeSyncBatch(), DEFAULT_BATCH_SIZE);
    }

    public static Id syncAll() {
        return Database.executeBatch(new MetadataChangeSyncBatch(true), DEFAULT_BATCH_SIZE);
    }

    public static List<Id> scheduleEveryTenMinutes() {
        List<Id> jobIds = new List<Id>();
        for (Integer minute : SCHEDULE_MINUTES) {
            String jobName = JOB_NAME_PREFIX + ' - Minute ' + minute;
            String cronExpression = '0 ' + minute + ' * * * ?';
            jobIds.add(System.schedule(jobName, cronExpression, new MetadataChangeSyncScheduler()));
        }
        return jobIds;
    }
}
