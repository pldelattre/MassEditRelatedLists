({
	closeModal : function(component, event, helper) {
		component.destroy();
	},
    deletePosts : function(component, event, helper) {
       var action = component.get("c.cleanChatterPosts");
	      action.setCallback(this, function(a) {
            var state = a.getState();
            if (state === "SUCCESS") {
				helper.showToast(component,event,'Success','Unwanted \'create\' posts were removed from chatter','success');
            }else if (state === "ERROR") {
                helper.showToast(component,event,'Error','Couldn\'t clean chatter :(','error'); 
            } 
           component.set("v.isApexInProgress",false);   
           component.destroy();   
        });

        $A.enqueueAction(action);
        component.set("v.isApexInProgress",true);
		
	}
})