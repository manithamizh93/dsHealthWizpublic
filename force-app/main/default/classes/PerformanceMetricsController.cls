public with sharing class PerformanceMetricsController {

    @AuraEnabled(cacheable=true)
    public static List<Org_Health_Metric__c> getHealthMetrics() {
        List<Org_Health_Metric__c> metrics = new List<Org_Health_Metric__c>();
        Date todayDate = Date.today();

        // PILLAR 1: SYSTEM PERFORMANCE (Speed & Limits)
                
        // 1.1 API Usage
        Map<String, System.OrgLimit> ol = System.OrgLimits.getMap();
        System.OrgLimit apiLimit = ol.get('DailyApiRequests');
        metrics.add(createMetric('System - API Usage', apiLimit.getValue() + ' / ' + apiLimit.getLimit(), todayDate));

        // 1.2 Lightning Experience Page Time (EPT)
        List<LightningUsageByPageMetrics> eptList = [
            SELECT PageName, SumEPT, RecordCountEPT
            FROM LightningUsageByPageMetrics
            WHERE RecordCountEPT > 0
            ORDER BY MetricsDate DESC LIMIT 5
        ];
        for (LightningUsageByPageMetrics row : eptList) {
            Decimal avgEpt = row.SumEPT / row.RecordCountEPT;
            metrics.add(createMetric('System - EPT ' + row.PageName, avgEpt.setScale(0) + ' ms', todayDate));
        }

        // 1.3 Specific System Limits (CPU, Heap, etc. - from general map)        
        for (String limitName : ol.keySet()) {
            System.OrgLimit rl = ol.get(limitName);            
            if(rl.getValue() > 0 && limitName != 'DailyApiRequests' && limitName != 'DataStorageMB') {
                metrics.add(createMetric(
                    'System - Limit ' + limitName,
                    rl.getValue() + '/' + rl.getLimit(),
                    todayDate
                ));
            }
        }
      
        // PILLAR 2: DATA QUALITY (Completeness & Accuracy)
            
        // 2.1 Contacts missing Email Address
        Integer badContacts = [SELECT COUNT() FROM Contact WHERE Email = NULL];
        metrics.add(createMetric('Data Quality - Contacts w/o Email', String.valueOf(badContacts), todayDate));

        // 2.2 Opportunities missing Amount (Example of critical business data)
        Integer badOpps = [SELECT COUNT() FROM Opportunity WHERE Amount = NULL AND IsClosed = false];
        metrics.add(createMetric('Data Quality - Opps w/o Amount', String.valueOf(badOpps), todayDate));
   
        // PILLAR 3: PROCESS EFFICIENCY (Automation Health)
       
        // 3.1 Pending/Slow Jobs (Backlog)
        Integer queuedJobs = [SELECT COUNT() FROM AsyncApexJob WHERE Status IN ('Queued','Processing')];
        metrics.add(createMetric('Process - Apex Pending', String.valueOf(queuedJobs), todayDate));

        // 3.2 Failed Jobs Today (Errors)
        Integer failedJobs = [SELECT COUNT() FROM AsyncApexJob WHERE Status = 'Failed' AND CompletedDate = TODAY];
        metrics.add(createMetric('Process - Apex Failed Today', String.valueOf(failedJobs), todayDate));

     
        // PILLAR 4: USER PRODUCTIVITY (Activity Levels)        

        // 4.1 Tasks Created Today (Calls/Emails logged)
        Integer tasksCreated = [SELECT COUNT() FROM Task WHERE CreatedDate = TODAY];
        metrics.add(createMetric('Productivity - Tasks Today', String.valueOf(tasksCreated), todayDate));

        // PILLAR 5: UTILIZATION & ADOPTION (Usage)       

        // 5.1 Active Logins Today
        // We count distinct logins for today to measure adoption
        Integer loginCount = [SELECT COUNT() FROM LoginHistory WHERE LoginTime = TODAY];
        metrics.add(createMetric('Adoption - Logins Today', String.valueOf(loginCount), todayDate));

        // 5.2 Data Storage Usage
        System.OrgLimit storageLimit = ol.get('DataStorageMB');
        metrics.add(createMetric('Utilization - Storage', storageLimit.getValue() + ' / ' + storageLimit.getLimit() + ' MB', todayDate));

        // 5.3 Total Key Records (Growth Indicator)
        Integer accountCount = [SELECT COUNT() FROM Account];
        metrics.add(createMetric('Utilization - Total Accounts', String.valueOf(accountCount), todayDate));

        return metrics;
    }

    // Helper method to create the metric record
    private static Org_Health_Metric__c createMetric(String type, String value, Date d) {
        Org_Health_Metric__c m = new Org_Health_Metric__c();
        m.Metric_Type__c = type;
        m.MetricValue__c = value;
        m.Snapshot_Date__c = d;
        return m;
    }
}