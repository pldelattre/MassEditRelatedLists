({
	doInit : function(component, event, helper) {
            var evt = $A.get("e.force:navigateToComponent");
            evt.setParams({
                componentDef : "c:MassEditRelatedLists",
                componentAttributes: {
					recordId : component.get("v.recordId"),
                    sObjectName : component.get("v.sObjectName")
                }
            });
            evt.fire();
    }     
})