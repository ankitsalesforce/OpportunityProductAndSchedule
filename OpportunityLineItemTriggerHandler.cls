public class OpportunityLineItemTriggerHandler {
    public static void preventProductDeletion(List<OpportunityLineItem> oldProducts, string stage){
        for(OpportunityLineItem p : oldProducts){
            if(p.Opportunity_Stage__c==stage){
                p.adderror('Product cannot be deleted. Opportunity Stage is '+stage);
            }
        }
    }
    //not in use 
    public static void copyOpportunityFieldValue(List<OpportunityLineItem> lstOpportunityLineItem,Map<Id,OpportunityLineItem> mapOldOpportunityLineItem)
    {
        Set<Id> lstOpportunityID=new Set<Id>();
        Map<Id,Opportunity> mapOpportunity=new Map<Id,Opportunity>();
        for(OpportunityLineItem objOpportunityLineItem:lstOpportunityLineItem)
        {
            lstOpportunityID.add(objOpportunityLineItem.OpportunityId);
        }
        List<Opportunity> lstOpportunityToUpdate=new List<Opportunity>();
        for(Opportunity objOpportunity:[Select Id,Estimated_Contract_Start_Date__c,Estimated_Contract_End_Date__c,Override_Date__c, (Select ServiceDate,End_Date__c From OpportunityLineItems Order by CreatedDate DESC)
                                        From Opportunity Where Id=:lstOpportunityID])
        {
            system.debug('objOpportunity.OpportunityLineItems>>'+objOpportunity.OpportunityLineItems.size());
            system.debug('objOpportunity.Override_Date__c>>'+objOpportunity.Override_Date__c);
            if(objOpportunity.OpportunityLineItems.size()==1 || objOpportunity.Override_Date__c==true)
            {
                OpportunityLineItem objOpportunityLineItem=objOpportunity.OpportunityLineItems[0];
                objOpportunity.Estimated_Contract_Start_Date__c=objOpportunityLineItem.ServiceDate;
                objOpportunity.Estimated_Contract_End_Date__c=objOpportunityLineItem.End_Date__c;
                lstOpportunityToUpdate.add(objOpportunity);
            }
        }
        
        if(lstOpportunityToUpdate.size()>0)
            update lstOpportunityToUpdate;
        OpportunityLineItemScheduleHandler.createOrUpdateSchedule(lstOpportunityLineItem,mapOldOpportunityLineItem,true);
    }
    
    //before insert
    public static void copyScheduleField(List<OpportunityLineItem> lstOpportunityLineItem)
    {
        for(OpportunityLineItem objOpportunityLineItem:lstOpportunityLineItem)
        {
            objOpportunityLineItem.Schedule_Start_Date__c=objOpportunityLineItem.ServiceDate;
            if(objOpportunityLineItem.ServiceDate!=null && objOpportunityLineItem.End_Date__c!=null)
                objOpportunityLineItem.Number_of_Installments__c=getNumberOfMonths(objOpportunityLineItem.ServiceDate,objOpportunityLineItem.End_Date__c);
            objOpportunityLineItem.Schedule_Type__c='Divide Amount into Multiple Installments';
            objOpportunityLineItem.Schedule_Installment_Period__c='Monthly';
        }
    }
    
    public static Integer getNumberOfMonths(Date startDate,Date endDate)
    {
        /* Integer numberOfMonths = startDate.monthsBetween(endDate);
system.debug('*****'+numberOfMonths);
if (endDate.day() > startDate.day()) 
numberOfMonths++;

system.debug('total number of installment ***'+numberOfMonths);
return numberOfMonths;
*/
        
        
        Integer yearsDifference = endDate.year() - startDate.year();
        Integer monthsDifference = endDate.month() - startDate.month();
        
        
        Integer totalMonths = (yearsDifference * 12) + monthsDifference + 1; 
        system.debug('total number of installment ***'+totalMonths);
        return totalMonths;
        
    }
    
    //before insert /before update
    //if override checkbox is true , then only update product dates with oppy dates
    public static void updateStartEndDates(List<OpportunityLineItem> lstOpportunityLineItem){
        Set<Id> oppIds = new Set<Id>();
        for (OpportunityLineItem oli : lstOpportunityLineItem) {
            if (oli.Override_Dates__c) {
                oppIds.add(oli.OpportunityId);
            }
        }
        
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([SELECT Id, Estimated_Contract_Start_Date__c, Estimated_Contract_End_Date__c,Contract_Length_Years__c  FROM Opportunity WHERE Id IN :oppIds]);
        
        for (OpportunityLineItem oli : lstOpportunityLineItem) {
            if (oppMap.containsKey(oli.OpportunityId)) {
                Opportunity opp = oppMap.get(oli.OpportunityId);
                if(opp.Contract_Length_Years__c != null){
                    oli.Quantity = opp.Contract_Length_Years__c;
                }
                
                if(oli.Override_Dates__c){
                    oli.ServiceDate = opp.Estimated_Contract_Start_Date__c;
                    oli.End_Date__c = opp.Estimated_Contract_End_Date__c;
                }
            }
        }
    }
      
    //after Update
    public static void adjustLineItemSchedules(Map<Id, OpportunityLineItem> oldMap, Map<Id, OpportunityLineItem> newMap) {
        List<OpportunityLineItemSchedule> schedulesToBeDelete = new List<OpportunityLineItemSchedule>();
        List<OpportunityLineItemSchedule> schedulesToBeInsert = new List<OpportunityLineItemSchedule>();
        
        for (Id oppLineItemId : newMap.keySet()) {
            OpportunityLineItem oldLineItem = oldMap.get(oppLineItemId);
            OpportunityLineItem newLineItem = newMap.get(oppLineItemId);
            
            Date oldStartDate = oldLineItem.ServiceDate;
            Date newStartDate = newLineItem.ServiceDate;
            Date oldEndDate = oldLineItem.End_Date__c;
            Date newEndDate = newLineItem.End_Date__c;
            
            if (oldStartDate != newStartDate || oldEndDate != newEndDate) {
                schedulesToBeDelete.addAll(getExistingSchedules(oppLineItemId));
                schedulesToBeInsert.addAll(prepareSchedule(newLineItem));
            }
        }
        
        if (!schedulesToBeDelete.isEmpty()) {
            delete schedulesToBeDelete;
        }
        if (!schedulesToBeInsert.isEmpty()) {
            insert schedulesToBeInsert;
        }
    }
    
    private static List<OpportunityLineItemSchedule> getExistingSchedules(Id oppLineItemId) {
        return [SELECT Id,ScheduleDate,Type,OpportunityLineItemId,Revenue 
            				FROM OpportunityLineItemSchedule 
            				WHERE OpportunityLineItemId =:oppLineItemId];
    }
    
    Public static list<OpportunityLineItemSchedule> prepareSchedule(OpportunityLineItem lineItem){
        List<OpportunityLineItemSchedule> schedulesToInsert = new List<OpportunityLineItemSchedule>();
        Date installmentDate = lineItem.Schedule_Start_Date__c; 
        Decimal installmentAmount;
        
        
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
        system.debug('lineItem.Number_of_Installments__c****'+lineItem.Number_of_Installments__c);
        Integer updatedInstallment = Integer.ValueOf(lineItem.Number_of_Installments__c - 1);
        for (Integer i = 0; i < updatedInstallment; i++) {
            system.debug('lineItem**');
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
        
        return schedulesToInsert;
    }

}