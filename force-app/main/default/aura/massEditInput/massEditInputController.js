({

  	doInit : function (component, event, helper){
       component.set("v.noPicklistMatch",!helper.isValueInPicklistOptions(component));
	},
    
	refresh : function (component, event, helper){
		//Set picklist initial value
		helper.setPicklistInitialValue(component,helper);
		//enable or disable the components
	  helper.enableOrDisableFields(component);
	},


	debug : function(component, event, helper) {
  /*  console.log("type: "+component.get("v.type"));
    console.log("subType: "+component.get("v.subType"));
		console.log("selectOptions: "+component.get("v.selectOptions"));
		console.log("value: "+component.get("v.value"));
		console.log("isLockable: "+component.get("v.isLockable"));*/
		console.log("isLocked: "+component.get("v.isLocked"));

	//	component.set("v.disabled","true");



	},

    refreshPicklist : function(component, event, helper) {
       component.set("v.noPicklistMatch",!helper.isValueInPicklistOptions(component));
    },  
    
	onChange : function(component, event, helper) {
        //debugger;
        if (typeof(event.currentTarget.type) !== 'undefined'){
            component.set("v.value",event.currentTarget.value);
        }
		/*var whichOne = event.currentTarget;
		var value = (whichOne.type=="checkbox") ? whichOne.checked : whichOne.value;
		component.set("v.value",value);*/
        
		//fire an event that handle our onchange callback function 
		var event = component.getEvent('change');
		event.fire();
		console.log(component.get("v.value"));
	},

	onKeyDown : function(component, event, helper){
				// Lock field when pressing enter key
			//console.log(event.keyCode);
			if (component.get("v.isLockable") && event.keyCode === 13 )
				{
				component.set("v.isLocked",true);
				}
	},

	unlock : function(component, event, helper){
		component.set("v.isLocked",false);

	}

})