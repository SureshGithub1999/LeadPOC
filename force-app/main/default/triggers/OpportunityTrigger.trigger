trigger OpportunityTrigger on Opportunity (after update) {

    if (Trigger.isAfter && Trigger.isUpdate) {
        InventoryHandler.handlePOReceived(Trigger.oldMap, Trigger.newMap);
    }

}
