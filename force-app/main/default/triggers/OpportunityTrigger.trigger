trigger OpportunityTrigger on Opportunity (after update) {
    InventoryHandler.handlePOReceived(
        Trigger.oldMap,
        Trigger.newMap
    );
}