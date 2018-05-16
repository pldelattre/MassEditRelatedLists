({
	helperMethod : function() {
		
	},
    
	showToast : function(component, event, title, message, type) {
	var toastEvent = $A.get("e.force:showToast");
	toastEvent.setParams({
			"title": title,
			"message": message,
			"type" : type,
			"duration" : 7000
	});
	toastEvent.fire();
	},
    
    navigate : function(component, event, helper) {
    var urlEvent = $A.get("e.force:navigateToURL");
    urlEvent.setParams({
      "url": 'https://pdepackager.my.salesforce.com/layouteditor/layoutEditor.apexp?type=Account&lid=00h58000000uP2pAAE'
    });
    urlEvent.fire();
	},
    
    newTabToURL : function(url) {
		window.open(url);  
	}
    

    
})