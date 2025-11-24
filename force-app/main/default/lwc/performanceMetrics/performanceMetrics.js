import { LightningElement, wire, track } from 'lwc';
import getHealthMetrics from '@salesforce/apex/PerformanceMetricsController.getHealthMetrics';

export default class PerformanceMetrics extends LightningElement {
    @track groupedData = [];

    columns = [
        { label: 'Metric Type', fieldName: 'Metric_Type__c', type: 'text' },
        { label: 'Value', fieldName: 'MetricValue__c', type: 'text' },
        { label: 'Snapshot Date', fieldName: 'Snapshot_Date__c', type: 'date' }
    ];

    // Mapping pillars based on prefix
    pillarMapping = {
        "System": "SYSTEM PERFORMANCE",
        "Data Quality": "DATA QUALITY",
        "Process": "PROCESS EFFICIENCY",
        "Productivity": "USER PRODUCTIVITY",
        "Adoption": "UTILIZATION & ADOPTION",
        "Utilization": "UTILIZATION & ADOPTION",
        "TechDebt": "TECHNICAL DEBT & COMPLEXITY",
        "CodePerf": "CODE & AUTOMATION PERFORMANCE"        
    };

    @wire(getHealthMetrics)
    wiredMetrics({ data, error }) {
        if (data) {
            this.groupedData = this.groupByPillar(data);
        } else if (error) {
            console.error(error);
        }
    }

    groupByPillar(metrics) {
        let map = {};

        metrics.forEach(m => {
            let prefix = m.Metric_Type__c.split(' - ')[0];
            let pillar = this.pillarMapping[prefix] || "Other";

            if (!map[pillar]) {
                map[pillar] = [];
            }
            map[pillar].push(m);
        });

        return Object.keys(map).map(key => ({
            pillar: key,
            items: map[key]
        }));
    }
}
