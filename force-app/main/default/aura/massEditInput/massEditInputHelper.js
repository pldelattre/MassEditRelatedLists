({
    selectItemByValue: function(elmnt, value) {

        if (typeof elmnt.options !== 'undefined') {
            for (var i = 0; i < elmnt.options.length; i++) {
                if (elmnt.options[i].value === value) {
                    elmnt.selectedIndex = i;
                    break;
                }
            }
        }

    },

    isValueInPicklistOptions: function(component) {
        	var selectOptions = component.get("v.selectOptions");
        	var value = component.get("v.value");
    		if (typeof selectOptions !== 'undefined') {
            for (var i = 0; i < selectOptions.length; i++) {
                if (selectOptions[i].value == value) return true;
            }
          }
        return false;
    },    
    
    
    enableOrDisableFields: function(component) {
        var allInputTypes = [];
        allInputTypes.push(component.find("myCheckbox"));
        allInputTypes.push(component.find("myPicklist"));
        //console.log(component.find("myPicklist").get());
        allInputTypes.push(component.find("myStandardInput"));
        //console.log(allInputTypes);
        for (var i = 0; i < allInputTypes.length; i++) {
            if (typeof allInputTypes[i] !== 'undefined' && typeof allInputTypes[i].getElement === 'function') {
                allInputTypes[i].getElement().disabled = component.get("v.disabled");
            }
        }
    },

    setPicklistInitialValue: function(component, helper) {
        if (component.get("v.type") == 'picklist') {
            var cmpSelect = component.find("myPicklist");
            if (typeof cmpSelect !== 'undefined' && typeof cmpSelect.getElement === 'function') {
                helper.selectItemByValue(cmpSelect.getElement(), component.get("v.value"));
            }
        }
    }
})