({
	showToast : function(component, event, title, message, type) {
	var toastEvent = $A.get("e.force:showToast");
	toastEvent.setParams({
			"title": title,
			"message": message,
			"type" : type,
			"duration" : 7000
	});
	toastEvent.fire();
	}
})