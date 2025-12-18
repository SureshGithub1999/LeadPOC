trigger OpportunityLineItemTrigger on OpportunityLineItem (after insert) {
    InventoryHandler.updateInTransit(Trigger.new);
}