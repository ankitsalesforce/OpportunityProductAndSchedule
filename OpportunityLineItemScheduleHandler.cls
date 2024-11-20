public class OpportunityLineItemScheduleHandler {
    public static void createOrUpdateSchedule(List<OpportunityLineItem> opportunityLineItems,Map<Id,OpportunityLineItem> mapOldOpportunityLineItem,boolean isInsert) {
        List<OpportunityLineItemSchedule> schedulesToInsert = new List<OpportunityLineItemSchedule>();
        Set<Id> lstOpportunityLineItemID=new Set<Id>();
        for (OpportunityLineItem oli : opportunityLineItems) {
            OpportunityLineItem objOldOpportunityLineItem=null;
            if(isInsert==false)
            objOldOpportunityLineItem=mapOldOpportunityLineItem.get(oli.Id);
            if((objOldOpportunityLineItem!=null && IsFieldChange(oli,objOldOpportunityLineItem)) || isInsert)
                lstOpportunityLineItemID.add(oli.Id);
        }
        List<OpportunityLineItemSchedule> existingSchedules = [
            SELECT Id FROM OpportunityLineItemSchedule 
            WHERE OpportunityLineItemId IN:lstOpportunityLineItemID
        ];
        
        if (!existingSchedules.isEmpty()) {
            delete existingSchedules;
        }
        
        for (OpportunityLineItem lineItem : opportunityLineItems) {
               OpportunityLineItem objOldOpportunityLineItem=null;
            if(isInsert==false)
            objOldOpportunityLineItem=mapOldOpportunityLineItem.get(lineItem.Id);
            if((objOldOpportunityLineItem!=null && IsFieldChange(lineItem,objOldOpportunityLineItem)) || isInsert)
            {
                // Remove existing schedules
                Date installmentDate = lineItem.Schedule_Start_Date__c; // Start from the Opportunity close date             Decimal installmentAmount;
                Decimal installmentAmount;
                // Calculate the installment amount based on Schedule Type
                system.debug('lineItem.Schedule_Type__c'+lineItem.Schedule_Type__c);
                if (lineItem.Schedule_Type__c == 'Divide Amount into Multiple Installments') {
                    system.debug('1');
                    installmentAmount = lineItem.TotalPrice / lineItem.Number_of_Installments__c;
                } else if (lineItem.Schedule_Type__c == 'Repeat Amount for Each Installment') {
                    system.debug('2');
                    installmentAmount = lineItem.TotalPrice;
                }
                
                schedulesToInsert.add(
                    new OpportunityLineItemSchedule(
                        OpportunityLineItemId = lineItem.Id,
                        Revenue = installmentAmount,
                        ScheduleDate=installmentDate,
                    	Type = 'Revenue'));
        
                decimal updatedInstallment = lineItem.Number_of_Installments__c - 1;
                for (Integer i = 0; i < updatedInstallment; i++) {
                    OpportunityLineItemSchedule schedule = new OpportunityLineItemSchedule();
                    schedule.OpportunityLineItemId = lineItem.Id;
                    schedule.Revenue = installmentAmount;
                    if (lineItem.Schedule_Installment_Period__c == 'Monthly') {
                        installmentDate = installmentDate.addMonths(1);
                    } else if (lineItem.Schedule_Installment_Period__c == 'Quarterly') {
                        installmentDate = installmentDate.addMonths(3);
                    } else if (lineItem.Schedule_Installment_Period__c == 'Yearly') {
                        installmentDate = installmentDate.addYears(1);
                    }
                     else if (lineItem.Schedule_Installment_Period__c == 'Daily') {
                        installmentDate = installmentDate.addDays(1);
                    }
                      else if (lineItem.Schedule_Installment_Period__c == 'Weekly') {
                        installmentDate = installmentDate.addDays(7);
                    }
                    schedule.ScheduleDate=installmentDate;
                    schedule.Type = 'Revenue'; // Type can be 'Revenue' or 'Quantity'
                    if(installmentAmount>0)
                    schedulesToInsert.add(schedule);
                }
            }
        }
        
        // Insert new schedules
        if (!schedulesToInsert.isEmpty()) {
            insert schedulesToInsert;
        }
    }
    public static boolean IsFieldChange(OpportunityLineItem objOpportunityLineItem,OpportunityLineItem objOldOpportunityLineItem)
    {
        if((objOpportunityLineItem.TotalPrice!=null && objOpportunityLineItem.Number_of_Installments__c!=null
            && objOpportunityLineItem.Schedule_Installment_Period__c!=null && objOpportunityLineItem.Schedule_Start_Date__c!=null
            && objOpportunityLineItem.Schedule_Type__c!=null) && 
           (objOldOpportunityLineItem.TotalPrice!=objOpportunityLineItem.TotalPrice) 
           || (objOldOpportunityLineItem.Number_of_Installments__c!=objOpportunityLineItem.Number_of_Installments__c)
           || (objOldOpportunityLineItem.Schedule_Installment_Period__c!=objOpportunityLineItem.Schedule_Installment_Period__c)
           || (objOldOpportunityLineItem.Schedule_Start_Date__c!=objOpportunityLineItem.Schedule_Start_Date__c)
           || (objOldOpportunityLineItem.Schedule_Type__c!=objOpportunityLineItem.Schedule_Type__c))        
        {
            return true;
        }
        return false;
    }
    
}