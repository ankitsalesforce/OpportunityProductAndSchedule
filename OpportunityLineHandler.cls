/* Class : OpportunityLineHandler
* Purpose : To update Opportunity Product with Opportunity Estimate Start Date ,Estimate End Date,Contract Length
* Dependancy : Used in Opportunity Trigger ,after Update event 
*/

public class OpportunityLineHandler {
    
    public static void updateOpportunityLineItem(list<Opportunity> oppyList,Map<Id,Opportunity> mapOldOpportunity){
        
        list<OpportunityLineItem> oppyLineItemsToBeUpdate = new list<OpportunityLineItem>(); 
        set<Id> oppyIds = new set<Id>();
        
        for(Opportunity opp : oppyList){
            if(mapOldOpportunity != null){
                Opportunity oldOppy = mapOldOpportunity.get(opp.Id);
                if(oldOppy.Estimated_Contract_Start_Date__c != opp.Estimated_Contract_Start_Date__c ||
                   oldoppy.Estimated_Contract_End_Date__c != opp.Estimated_Contract_End_Date__c ||
                   oldoppy.Contract_Length_Years__c != opp.Contract_Length_Years__c){
                       oppyIds.add(opp.Id);
                   }
            }
        }
        
        if(!oppyIds.isEmpty()){
            for(OpportunityLineItem oli : [SELECT Id,ServiceDate,End_Date__c,Quantity,opportunityId,Opportunity.Estimated_Contract_Start_Date__c,
                                           Opportunity.Estimated_Contract_End_Date__c,Opportunity.Contract_Length_Years__c FROM OpportunityLineItem WHERE OpportunityId IN:oppyIds]){
                                               OpportunityLineItem oppLineItem = new OpportunityLineItem();
                                               oppLineItem.Id =  oli.Id;  
                                               oppLineItem.ServiceDate = oli.Opportunity.Estimated_Contract_Start_Date__c;
                                               oppLineItem.Schedule_Start_Date__c = oli.Opportunity.Estimated_Contract_Start_Date__c;
                                               oppLineItem.End_Date__c = oli.Opportunity.Estimated_Contract_End_Date__c;
                                               //oppLineItem.Quantity = oli.Opportunity.Contract_Length_Years__c;
                                               oppLineItem.Number_of_Installments__c = OpportunityLineItemTriggerHandler.getNumberOfMonths(oli.Opportunity.Estimated_Contract_Start_Date__c,oli.Opportunity.Estimated_Contract_End_Date__c);
                                               oppyLineItemsToBeUpdate.add(oppLineItem);
                                           }
        }
        
        
        if(!oppyLineItemsToBeUpdate.isEmpty())
            Update oppyLineItemsToBeUpdate;
        
    }
}