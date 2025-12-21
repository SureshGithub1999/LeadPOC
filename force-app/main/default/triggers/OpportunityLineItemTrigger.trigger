trigger OpportunityLineItemTrigger on OpportunityLineItem (after insert) {

    if (Trigger.isAfter && Trigger.isInsert) {
        InventoryHandler.updateInTransit(Trigger.new);
    }

}
