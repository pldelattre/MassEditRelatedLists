({
    /**
     * Search records for a match
     */
    search : function(cmp, event, helper) {
        helper.doSearch(cmp,event);
    },

    /**
     * Select a record from a list
     */
    select: function(cmp, event, helper) {
        helper.handleSelection(cmp, event);
    },

    /**
     * Clear the currently selected SObject
     */
    clear: function(cmp, event, helper) {
        helper.clearSelection(cmp);
    },

    autoClear: function(cmp, event, helper) {
        //if autoClear was wrongly called by lightning, then return
       if (cmp.get("v.prevSelectedItemId")==cmp.get("v.selectedItemId")) return;
       if (cmp.get("v.selectedItemId")==null || cmp.get("v.selectedItemId")==""){ 	
           helper.clearSelection(cmp);
       } else {
         cmp.refreshLookup();
       }
       cmp.set("v.prevSelectedItemId",cmp.get("v.selectedItemId"));     
            
    },

    createRecord: function(cmp, event, helper) {
        helper.createNewRecord(cmp);
    },

    initLookup: function(cmp, event, helper) {
        helper.handleInitialSelection(cmp);
    },

    inputBlur: function(cmp, event, helper) {
        console.log("blur");
        var lookupDiv = cmp.find('lookup-div');
        $A.util.removeClass(lookupDiv, 'slds-is-open');
    }

})