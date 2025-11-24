public with sharing class PerformanceMetricsController {

    @AuraEnabled(cacheable=true)
    public static List<Org_Health_Metric__c> getHealthMetrics() {

        List<Org_Health_Metric__c> metrics = new List<Org_Health_Metric__c>();
        Date todayDate = Date.today();

        // PILLAR 1: SYSTEM PERFORMANCE
  
        Map<String, System.OrgLimit> ol = System.OrgLimits.getMap();
        /*System.OrgLimit apiLimit = ol.get('DailyApiRequests');
        metrics.add(createMetric('System - API Usage', apiLimit.getValue() + ' / ' + apiLimit.getLimit(), todayDate));
*/
        List<LightningUsageByPageMetrics> eptList = [
            SELECT PageName, SumEPT, RecordCountEPT
            FROM LightningUsageByPageMetrics
            WHERE RecordCountEPT > 0
            ORDER BY MetricsDate DESC LIMIT 5
        ];
        for (LightningUsageByPageMetrics row : eptList) {
            Decimal avg = row.SumEPT / row.RecordCountEPT;
            metrics.add(createMetric('System - EPT ' + row.PageName, avg.setScale(0) + ' ms', todayDate));
        }

        // PILLAR 2: DATA QUALITY
   
        Integer c1 = [SELECT COUNT() FROM Contact WHERE Email = NULL];
        metrics.add(createMetric('Data Quality - Contacts w/o Email', String.valueOf(c1), todayDate));

        Integer c2 = [SELECT COUNT() FROM Opportunity WHERE Amount = NULL AND IsClosed = false];
        metrics.add(createMetric('Data Quality - Open Opps w/o Amount', String.valueOf(c2), todayDate));

        // PILLAR 3: PROCESS EFFICIENCY
       
        Integer q = [SELECT COUNT() FROM AsyncApexJob WHERE Status IN ('Queued','Processing')];
        metrics.add(createMetric('Process - Apex Pending Jobs', String.valueOf(q), todayDate));

        Integer f = [SELECT COUNT() FROM AsyncApexJob WHERE Status = 'Failed' AND CompletedDate = TODAY];
        metrics.add(createMetric('Process - Apex Failed Jobs Today', String.valueOf(f), todayDate));
     
        // PILLAR 4: USER PRODUCTIVITY
       
        Integer tasksToday = [SELECT COUNT() FROM Task WHERE CreatedDate = TODAY];
        metrics.add(createMetric('Productivity - Tasks Logged Today', String.valueOf(tasksToday), todayDate));

        
        // PILLAR 5: TECHNICAL DEBT & ORG COMPLEXITY (UPDATED & FIXED)
        
        
        // 5.1 Custom Objects – Used vs Limit
        Integer customObjUsed = [
            SELECT COUNT()
            FROM EntityDefinition
            WHERE IsCustomizable = true
        ];
        
        Integer customObjLimit = 3000; // Salesforce hard limit
        Decimal customObjPercent = (Decimal.valueOf(customObjUsed) / customObjLimit) * 100;
        
        metrics.add(createMetric(
            'TechDebt - Custom Objects Used',
            customObjUsed + ' / ' + customObjLimit + ' (' + customObjPercent.setScale(1) + '%)',
            todayDate
        ));
        
        
        // 5.2 Custom Fields Usage per Object (>50%)
        List<EntityDefinition> allObjects = [
            SELECT QualifiedApiName, DurableId
            FROM EntityDefinition
            WHERE IsCustomizable = true
        ];
        
        for (EntityDefinition obj : allObjects) {
        
            // Count ONLY custom fields: field name ends with "__c"
            Integer customFieldCount = [
                SELECT COUNT()
                FROM FieldDefinition
                WHERE EntityDefinitionId = :obj.DurableId
                AND QualifiedApiName LIKE '%__c'
            ];
        
            Integer customFieldLimit = 500; // Salesforce per-object custom field limit
            Decimal usagePercent = 0;
        
            if (customFieldCount > 0) {
                usagePercent = (Decimal.valueOf(customFieldCount) / customFieldLimit) * 100;
            }
        
            // Only show high-risk objects (= using more than 50% of limit)
            if (usagePercent >= 50) {
                metrics.add(createMetric(
                    'TechDebt - Field Usage: ' + obj.QualifiedApiName,
                    customFieldCount + ' / ' + customFieldLimit +
                    ' (' + usagePercent.setScale(1) + '%)',
                    todayDate
                ));
            }
        }
        
        
        // 5.3 Active Process Builders
        Integer pbCount = [
            SELECT COUNT()
            FROM FlowDefinitionView
            WHERE ProcessType = 'Workflow'
            AND IsActive = true
        ];
        metrics.add(createMetric('TechDebt - Active Process Builders', String.valueOf(pbCount), todayDate));
        
        
        // 5.4 Active Triggers
        Integer triggerCount = [SELECT COUNT() FROM ApexTrigger WHERE Status = 'Active'];
        metrics.add(createMetric('TechDebt - Active Triggers', String.valueOf(triggerCount), todayDate));
        
        
        // 5.5 Apex Classes
        Integer classCount = [SELECT COUNT() FROM ApexClass];
        metrics.add(createMetric('TechDebt - Apex Classes', String.valueOf(classCount), todayDate));

        // PILLAR 6: CODE & AUTOMATION PERFORMANCE (FIXED)
  
        // 6.1 Large Apex Logs (CPU heavy)
        Integer cpuLogs = [SELECT COUNT() FROM ApexLog WHERE LogLength > 300000];
        metrics.add(createMetric('CodePerf - Large CPU Logs', String.valueOf(cpuLogs), todayDate));

        // 6.2 Active Flows (VALID)
        Integer activeFlows = [
            SELECT COUNT()
            FROM FlowDefinitionView
            WHERE IsActive = true
        ];
        metrics.add(createMetric('CodePerf - Active Flows', String.valueOf(activeFlows), todayDate));

        // 6.3 Failed Flow Interviews Today
        Integer flowFail = [
            SELECT COUNT()
            FROM FlowInterview
            WHERE InterviewStatus = 'Failed'
            AND LastModifiedDate = TODAY
        ];
        metrics.add(createMetric('CodePerf - Failed Flow Interviews', String.valueOf(flowFail), todayDate));

        // 6.4 CPU-related Async Jobs
        Integer cpuAsync = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE ExtendedStatus LIKE '%CPU%'
        ];
        metrics.add(createMetric('CodePerf - CPU Async Jobs', String.valueOf(cpuAsync), todayDate));

           // PILLAR 7: UTILIZATION & ADOPTION
     
        Integer loginToday = [SELECT COUNT() FROM LoginHistory WHERE LoginTime = TODAY];
        metrics.add(createMetric('Adoption - Logins Today', String.valueOf(loginToday), todayDate));

        System.OrgLimit storage = ol.get('DataStorageMB');
        metrics.add(createMetric('Utilization - Storage', storage.getValue() + ' / ' + storage.getLimit() + ' MB', todayDate));

        Integer accounts = [SELECT COUNT() FROM Account];
        metrics.add(createMetric('Utilization - Total Accounts', String.valueOf(accounts), todayDate));

        return metrics;
    }

    private static Org_Health_Metric__c createMetric(String type, String value, Date d) {
        Org_Health_Metric__c m = new Org_Health_Metric__c();
        m.Metric_Type__c = type;
        m.MetricValue__c = value;
        m.Snapshot_Date__c = d;
        return m;
    }
}