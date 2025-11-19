import { LightningElement, wire } from 'lwc';
import getHealthMetrics from '@salesforce/apex/OrgPerformanceMetricsController.getHealthMetrics';

const COLUMNS = [
    { label: 'Metric Type', fieldName: 'Metric_Type__c', type: 'text', wrapText: true },
    { label: 'Value', fieldName: 'MetricValue__c', type: 'text' },
    { label: 'Snapshot Date', fieldName: 'Snapshot_Date__c', type: 'date' }
];

export default class OrgPerformanceMetrics extends LightningElement {
    columns = COLUMNS;
    
    // Wire the Apex method to the 'metrics' property
    @wire(getHealthMetrics)
    metrics;
}