// Kick off a one-time full sync so data is populated immediately.
MetadataChangeSyncScheduler.syncAll();

// Schedule the recurring every-10-minute sync.
MetadataChangeSyncScheduler.scheduleEveryTenMinutes();
