({
       doInit: function(component, event, helper) {
   
        var gid = component.getGlobalId();
        component.set("v.CleanGID", "GID"+gid.replace(":", "").replace(";", ""));
           
        var actionFetchOrgInfo = component.get("c.fetchOrgInfo");
        actionFetchOrgInfo.setCallback(this, function(a) {
               var state = a.getState();
               if (state === "SUCCESS") {
                   var result = a.getReturnValue();
                   var myDomain = result.baseURL.split(".my.salesforce.com")[0].split("https://")[1];
                   var namespace = {};
                   namespace.prefix = (result.namespace == null) ? "c" : result.namespace;
                   namespace.prefixWithDashes = (result.namespace == null) ? "" : result.namespace+"__";
                   component.set("v.myDomain",myDomain);
                   component.set("v.namespace",namespace);
               }
           });
        $A.enqueueAction(actionFetchOrgInfo);       
        
        component.set("v.loadStep","Waiting for an authentication token...");     
        window.addEventListener("message", function(event) {
            if (event==null || typeof event.data != "string") return;
            var payload = event.data.split(";;;");
            var allowedGID = payload[0];
            component.set("v.mySessionID",payload[1]);
            // Do not start load the component if the sessionID was provided by another instance 
            // of the component. 
            if (allowedGID!=component.get("v.CleanGID")) return;
            


         var action = component.get("c.getLayout");

        var params = {
            "recordId": component.get("v.recordId"),
            "sObjectName": component.get("v.sObjectName"),
            "sessionID":component.get("v.mySessionID")
        };

        action.setParams(params);
        action.setCallback(this, function(a) {
            var state = a.getState();
            if (state === "SUCCESS") {
               // console.log(a.getReturnValue());
                component.set("v.layout", a.getReturnValue());
                component.set("v.isGlobalActionsCardVisible",true);
            }else if (state === "ERROR") {
                var errors = a.getError();
                //helper.showToast(component,event,'Error','Error preventing to load ...','error');
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        helper.showToast(component,event,'Error',errors[0].message,'error');
                        component.set("v.loadErrorMessage",errors[0].message);
                        if (errors[0].message.includes("endpoint"))
                        	$A.util.removeClass(component.find("createRemoteSiteCard"), "slds-hide");
                        else
                        	$A.util.removeClass(component.find("unknownErrorCard"), "slds-hide");
                    }
                } else {
                    helper.showToast(component,event,'Unknown Error','Unknown Error','error');
                    component.set("v.loadErrorMessage",'Unkown Error...');
                    
                }
            }   
            var loadingCard = component.find("loadingCard");
            $A.util.addClass(loadingCard, "slds-hide"); 
        });

        $A.enqueueAction(action);    
        component.set("v.loadStep","Waiting answer from metadata api...");    
        }, false);     
             

    },
    
    cleanChatter: function(component,event,helper){
        	$A.createComponent(
			 component.get("v.namespace.prefix")+":MassEditRLDeleteChatterPostsModal",
			 {
					 "aura:id": "MassEditRLDeleteChatterPostsModal",
			 },
			 function(newCmp, status, errorMessage){
					 //Add the new button to the body array
					 if (status === "SUCCESS") {
							 var targetCmp = component.find('modalArea');
							 var body = targetCmp.get("v.body");
							 body.push(newCmp);
							 targetCmp.set("v.body", body);
					 }
			 }
		 );  
    },
    
    editLayout: function(component, event, helper) {
       var layoutId=component.get("v.layout.layoutId");
       var objectId=component.get("v.layout.objectId");
       var myDomain=component.get("v.myDomain"); 
       var layoutPath='layouteditor/layoutEditor.apexp?type='+objectId+'&lid='+layoutId;  
       var classicLink='https://'+myDomain+'.my.salesforce.com/'+layoutPath;
       var lightningLink='https://'+myDomain+'.lightning.force.com/one/one.app#/setup/ObjectManager/';
       lightningLink+=objectId+'/PageLayouts/page?address='+encodeURIComponent('/'+layoutPath);  
       helper.newTabToURL(lightningLink); 
    },
    
    editObjectFields: function(component, event, helper) {
       var objectId=component.get("v.layout.objectId");
       var myDomain=component.get("v.myDomain"); 
       var editObjectLink='https://'+myDomain+'.lightning.force.com/one/one.app#/setup/ObjectManager/';
       editObjectLink+=objectId+'/FieldsAndRelationships/view'; 
       helper.newTabToURL(editObjectLink); 
    },
    
   doRefresh: function(component, event, helper) {
       		 component.set("v.layout",null);
       		 component.set("v.isGlobalActionsCardVisible",false);
       		 var loadingCard = component.find("loadingCard");
             $A.util.removeClass(loadingCard, "slds-hide");
             var message = component.get("v.CleanGID")+';;;'+component.get("v.mySessionID");
	       	 window.postMessage(message, '*');
   },
    
   about: function(component, event, helper) {
     		$A.createComponent(
			 component.get("v.namespace.prefix")+":MassEditRLAboutModal",
			 {
					 "aura:id": "About Modal",
			 },
			 function(newCmp, status, errorMessage){
					 //Add the new button to the body array
					 if (status === "SUCCESS") {
							 var targetCmp = component.find('modalArea');
							 var body = targetCmp.get("v.body");
							 body.push(newCmp);
							 targetCmp.set("v.body", body);
					 }
			 }
		 );  
   }    
    
    
})