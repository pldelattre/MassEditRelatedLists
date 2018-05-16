({
    /**
     * Perform the SObject search via an Apex Controller
     */
    doSearch : function(cmp,event) {
        // Get the search string, input element and the selection container
        var searchString = cmp.get('v.searchString');
        var inputElement = cmp.find('lookup');
        var lookupList = cmp.find('lookuplist');
				var lookupDiv = cmp.find('lookup-div');

        // Clear any errors and destroy the old lookup items container
        inputElement.set('v.errors', null);

        // We need at least 2 characters for an effective search
        if (event.getParam("keyCode") === 27 )

        {
            // Hide the lookuplist
						$A.util.removeClass(lookupDiv, 'slds-is-open');
            return;
        }

        // Show the lookuplist
				$A.util.addClass(lookupDiv, 'slds-is-open');

        // Get the API Name
        var sObjectAPIName = cmp.get('v.sObjectAPIName');
		var objectsToSearch = cmp.get('v.objectsToSearch');
        
        // Create an Apex action
        var action = cmp.get('c.lookup');

        // Mark the action as abortable, this is to prevent multiple events from the keyup executing
        action.setAbortable();

        // Set the parameters
        action.setParams({ "searchString" : searchString, "objectsToSearch" : objectsToSearch});

        // Define the callback
        action.setCallback(this, function(response) {
            var state = response.getState();

            // Callback succeeded
            if (cmp.isValid() && state === "SUCCESS")
            {
                // Get the search matches
                var matches = response.getReturnValue();

                // If we have no matches, return nothing
                if (matches.length == 0)
                {
                    cmp.set('v.matches', null);
                    return;
                }

                // Store the results
                cmp.set('v.matches', matches);
								//console.log(cmp.get("v.matches"));
            }
            else if (state === "ERROR") // Handle any error by reporting it
            {
                var errors = response.getError();

                if (errors)
                {
                    if (errors[0] && errors[0].message)
                    {
                        this.displayToast('Error', errors[0].message);
                    }
                }
                else
                {
                    this.displayToast('Error', 'Unknown error.');
                }
            }
        });

        // Enqueue the action if 2 characters at least for an effective search
        if (!(typeof searchString === 'undefined' || searchString.length < 2 ))
        {$A.enqueueAction(action); 
        var objname = objectsToSearch[0];
        if (objectsToSearch.length > 1) objname+=' and '+ objectsToSearch[1];
        cmp.set('v.searchMessage','\"'+searchString+'\" in '+objname);
        }
        else {
          cmp.set('v.matches', null);
          cmp.set('v.searchMessage','Type at least 2 characters');
        }
    },

    /**
     * Handle the Selection of an Item
     */
    handleSelection : function(cmp, event) {
        // Resolve the Object Id from the events Element Id (this will be the <a> tag)
        var objectId = this.resolveId(event.currentTarget.id);

        // The Object label is the inner text)
        var objectLabel = event.currentTarget.innerText;

        // Log the Object Id and Label to the console
        //console.log('objectId=' + objectId);
        //console.log('objectLabel=' + objectLabel);


				// update the selectedItemId and selectedItemLabel attributes
				cmp.set("v.selectedItemId",objectId);
				cmp.set("v.selectedItemLabel",objectLabel);

        // Update the Searchstring with the Label
        cmp.set("v.searchString", objectLabel);
        
        //And the icon !
        var el = event.currentTarget;
        var iconName = el.dataset.iconname;
        cmp.set("v.iconName",iconName);

        // Hide the Lookup List
        //var lookupList = cmp.find("lookuplist");
        //$A.util.addClass(lookupList, 'slds-hide');
				var lookupDiv = cmp.find('lookup-div');
				$A.util.removeClass(lookupDiv, 'slds-is-open');


        // Hide the Input Element
        var inputElement = cmp.find('lookup');
        $A.util.addClass(inputElement, 'slds-hide');

        // Show the Lookup pill
        var lookupPill = cmp.find("lookup-pill");
        $A.util.removeClass(lookupPill, 'slds-hide');

        // Lookup Div has selection
        var inputElement = cmp.find('lookup-div');
        $A.util.addClass(inputElement, 'slds-has-selection');

    },

    handleInitialSelection : function(cmp, event) {
        // Resolve the Object Id from the events Element Id (this will be the <a> tag)
        var objectsToSearch = cmp.get('v.objectsToSearch');
        var objectId = cmp.get("v.selectedItemId");
        //console.log("apiname: "+sObjectAPIName+" recordid: "+ objectId)
        if ((typeof objectId === 'undefined') || (objectId=="") || (objectId==null)) {return;} //Exit init action if no selectedItemId was provided
		if ((typeof objectsToSearch === 'undefined') || (objectsToSearch==null)) {return;}
        var action = cmp.get('c.getRecordName');
        action.setParams({ "theRecordId" : objectId, "objectsToSearch" : objectsToSearch});

        action.setCallback(this, function(response) {
            var state = response.getState();

            // Callback succeeded
            if (cmp.isValid() && state === "SUCCESS")
            {
                // The Object label is the response of the query)
                var queryResult = response.getReturnValue();

                // Log the Object Id and Label to the console
                //console.log('objectId=' + objectId);
                


                // update the selectedItemId and selectedItemLabel attributes
                //cmp.set("v.selectedItemId",objectId);
                cmp.set("v.selectedItemLabel",queryResult.recLabel);

                // Update the Searchstring with the Label
                cmp.set("v.searchString", queryResult.recLabel);
                
                //update the icon
                cmp.set("v.iconName",queryResult.objectIcon);

                // Hide the Lookup List
                //var lookupList = cmp.find("lookuplist");
                //$A.util.addClass(lookupList, 'slds-hide');
                var lookupDiv = cmp.find('lookup-div');
                $A.util.removeClass(lookupDiv, 'slds-is-open');


                // Hide the Input Element
                var inputElement = cmp.find('lookup');
                $A.util.addClass(inputElement, 'slds-hide');

                // Show the Lookup pill
                var lookupPill = cmp.find("lookup-pill");
                $A.util.removeClass(lookupPill, 'slds-hide');

                // Lookup Div has selection
                var inputElement = cmp.find('lookup-div');
                $A.util.addClass(inputElement, 'slds-has-selection');

            }
            else if (state === "ERROR") // Handle any error by reporting it
            {
                var errors = response.getError();

                if (errors)
                {
                    if (errors[0] && errors[0].message)
                    {
                        this.displayToast('Error', errors[0].message);
                    }
                }
                else
                {
                    this.displayToast('Error', 'Unknown error.');
                }
            }
        });

        // Enqueue the action

        $A.enqueueAction(action);
		cmp.set("v.prevSelectedItemId",objectId); 


    },


    /**
     * Clear the Selection
     */
    clearSelection : function(cmp) {

		//debugger;
        // Clear the Searchstring
        cmp.set("v.searchString", '');

        // Hide the Lookup pill
        var lookupPill = cmp.find("lookup-pill");
        $A.util.addClass(lookupPill, 'slds-hide');

        // Show the Input Element
        var inputElement = cmp.find('lookup');
        $A.util.removeClass(inputElement, 'slds-hide');

        // Lookup Div has no selection
        var inputElement = cmp.find('lookup-div');
        $A.util.removeClass(inputElement, 'slds-has-selection');

	    /*if (cmp.get("v.selectedItemId")!="") { 
            cmp.set("v.selectedItemId",null);
        }*/
	    cmp.set("v.selectedItemLabel","");
    },

    /**
     * Resolve the Object Id from the Element Id by splitting the id at the _
     */
    resolveId : function(elmId)
    {
        var i = elmId.lastIndexOf('_');
        return elmId.substr(i+1);
    },

    /**
     * Create a new record
     */

    createNewRecord : function(cmp)
    {
      var createRecordEvent = $A.get("e.force:createRecord");
      createRecordEvent.setParams({
          "entityApiName": cmp.get("v.sObjectAPIName")
      });
      createRecordEvent.fire();
    },



    /**
     * Display a message
     */
    displayToast : function (title, message)
    {
        var toast = $A.get("e.force:showToast");

        // For lightning1 show the toast
        if (toast)
        {
            //fire the toast event in Salesforce1
            toast.setParams({
                "title": title,
                "message": message
            });

            toast.fire();
        }
        else // otherwise throw an alert
        {
            alert(title + ': ' + message);
        }
    }
})