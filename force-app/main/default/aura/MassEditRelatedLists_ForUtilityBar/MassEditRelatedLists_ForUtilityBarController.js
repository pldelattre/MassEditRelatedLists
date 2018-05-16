({
	doInit : function(component, event, helper) {
         console.log("Init comp unitiy bar");
         var action = component.get("c.getRecObjectAndName");
        if (component.get("v.recordId")!=null) {
            	var params = {
                    "recordId": component.get("v.recordId"),
                };
        
                action.setParams(params);
                action.setCallback(this, function(a) {
                    var state = a.getState();
                    if (state === "SUCCESS") {
                        console.log(a.getReturnValue());
                        component.set("v.curRec", a.getReturnValue());
                        component.set("V.isLoading",false);
                        if (component.get("v.curRec.recordName")!=null) component.set("v.isStartCompBtnDisabled",false);
                    }else if (state === "ERROR") {
                    }   
                });
        
                $A.enqueueAction(action);   
        }
        else {
            component.set("v.isStartCompBtnDisabled",true);
            //It seems there is a bug where utility bar doesn't detect instantly the recordid. 
            //Following is workaround to redo the "doInit" after 2 secs if recordId is empty
            if (component.get("v.isLoading")) {
               setTimeout(function(){ component.redoInit(); }, 2000);
               component.set("V.isLoading",false);
            }
        } 
            
        

        
    },
        onRecordIdChange : function(component, event, helper) {
        var newRecordId = component.get("v.recordId");
        console.log(newRecordId);
    },
    
    startComp : function (component,event, helper) {
        var compExisting = component.find("MERL");
        if (compExisting!=null) compExisting.destroy();
        $A.createComponent(
            "c:MassEditRelatedLists",
            {
                "aura:id":"MERL",
                "recordId":component.get("v.recordId"),
                "sObjectName":component.get("v.curRec.sObjectName"),
                "maxRowCountPerRL":component.get("v.maxRowCountPerRL")
            },
            function(newCmp, status, errorMessage){
                var content = component.find("MassEditRelatedListsContainer");
                content.set("v.body", newCmp);
            }
        );
        component.set("v.loadedFor.sObjectName",component.get("v.curRec.sObjectName"));
        component.set("v.loadedFor.recordName",component.get("v.curRec.recordName"));
        $A.util.removeClass(component.find("loadedForTable"), "slds-hide");
        $A.util.addClass(component.find("noRecYetDiv"), "slds-hide");
        component.set("v.loadLabel","Reload");
    }  
    
})