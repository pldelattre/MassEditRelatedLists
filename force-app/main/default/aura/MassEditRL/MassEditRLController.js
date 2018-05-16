({
 doInit: function(component, event, helper) {
		component.set("v.myDomain",window.location.origin.replace("\.lightning\.force\.com","").replace("https://",""));
        //console.log('RL load records INIT');
     	$A.util.removeClass(component.find("loadingSpinner"), "slds-hide");
     	component.set("v.displaySaveStatus",false);
        var action = component.get("c.getRecords");

        var params = {
            "recordId": component.get("v.recordId"),
            "sObjectName": component.get("v.sObjectName"),
            "rl": JSON.stringify(component.get("v.relatedList")),
            "queryLimit" : component.get("v.maxRowCount")
        };

        //console.log(params);

        action.setParams(params);
        action.setCallback(this, function(a) {
            var state = a.getState();
            if (state === "SUCCESS") {
                //console.log(a.getReturnValue());
                var returnValue=a.getReturnValue();      
                var rowsWithCells = helper.prepareRows(component,event,helper,returnValue);
                component.set("v.isUnsavedRecords",false);
                component.set("v.records", rowsWithCells);
            } else{
             	 component.set("v.displayCreateRowButton",false);    
            }
                
            $A.util.addClass(component.find("loadingSpinner"), "slds-hide");  
        });

        $A.enqueueAction(action);
		helper.loadSearchPicklistOptions(component,event,helper);


    },
    
    toggleColVisibilityMenu: function(component, event, helper) {
      $A.util.toggleClass(component.find("ColVisibilityMenu"), "slds-is-open");
          
        var myPopover = component.find('ColVisibilityMenu');
        var clickedFn = $A.getCallback(function(event){
            var popoverEle = myPopover.getElement();
            //if click happened outside of popover div hide
            if(!popoverEle.contains(event.target)){
                $A.util.toggleClass(myPopover, 'slds-is-open');
                window.removeEventListener('click',clickedFn);
            }
    	});
	   window.addEventListener('click',clickedFn);     
    },     
    
   doRefresh: function(component, event, helper) {
     component.refreshData();
   },   
    
   save: function(component, event, helper) {  
       $A.util.removeClass(component.find("loadingSpinner"), "slds-hide");
       var toSave = helper.prepareRecordsToSave(component,event,helper);           
       var targetObjectLabel = component.get("v.relatedList").label;
       
       if (toSave == null){
       	helper.showToast(component,event,'Warning','No '+targetObjectLabel+' records to update, insert or delete','warning');
        $A.util.addClass(component.find("loadingSpinner"), "slds-hide");     
        return;   
       }
       
       console.log('Saving records for Object:'+component.get("v.sObjectName"));
        var action = component.get("c.saveRecords");

        var params = {
            "sObjectName": component.get("v.sObjectName"),
            "toUpdate": toSave.toUpdate,
            "toInsert": toSave.toInsert,
            "toDelete": toSave.toDelete
        };
        action.setParams(params);
        action.setCallback(this, function(a) {
            var state = a.getState();
            if (state === "SUCCESS") {
                console.log("SUCCESS - Save Result:");
                console.log(a.getReturnValue());
                var ec = helper.afterSaveCleaning(component,event,helper,a.getReturnValue());
                component.set("v.displaySaveStatus",true);
                  if (ec.totalErrors!=0) {
                    var msg = ec.totalErrors+' records could not be saved. Hover over the failure icon(s) to get more detail';
                    helper.showToast(component,event,'Saving operation partially failed',msg,'warning');
                } else component.set("v.isUnsavedRecords",false);
                //if (!helper.isAnyVisibleRow(component)) component.set("v.displayCreateRowButton",true);
                //$A.get('e.force:refreshView').fire(); // Disabled because cause full component reload when component started from quick action.
            } else if (state === "ERROR") {
                var errors = a.getError();
                helper.showToast(component,event,'Error','Error preventing to save '+targetObjectLabel+' ...','error');
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        helper.showToast(component,event,'Error',errors[0].message,'error');
                    }
                } else {
                    helper.showToast(component,event,'Unknown Error',errors[0].message,'error');
                    
                }
            }
           $A.util.addClass(component.find("loadingSpinner"), "slds-hide");   
        });

        $A.enqueueAction(action);       
      
	},
    
   deleteRow: function(component, event, helper) {  
     var indexRow = event.getSource().get('v.value');
     helper.tagRowForDeletion(component,indexRow);
     //if (!helper.isAnyVisibleRow(component)) component.set("v.displayCreateRowButton",true);  
     component.set("v.displaySaveStatus",false);
     component.set("v.isUnsavedRecords",true);  
  },
  
  toggleColVisibility:function (component, event,helper) {
   var indexCol = event.getSource().get('v.value');
   var isChecked = event.getSource().get('v.checked');
   component.set("v.relatedList.columns["+indexCol+"].isVisible",isChecked);   
   helper.alignCellsVisibilityToColumn(component,indexCol,isChecked);    
  },  
    
  cloneRow: function(component, event, helper) { 
     var indexRow = event.getSource().get('v.value');
     helper.cloneARow(component,event,helper,indexRow);
     component.set("v.displaySaveStatus",false); 
     component.set("v.isUnsavedRecords",true); 
  }, 
    
  createRow: function(component, event, helper) { 
     helper.addRow(component,event,helper);
  },    
   
   closeSearchBox: function(component, event, helper) {   
       var searchBox = component.find("searchBox");
       $A.util.addClass(searchBox, "slds-hide");
       var buttonOpenSearchBox = component.find("buttonOpenSearchBox");
       $A.util.removeClass(buttonOpenSearchBox, "slds-hide");     
   }, 
   
   openSearchBox: function(component, event, helper) {   
       var searchBox = component.find("searchBox");
       $A.util.removeClass(searchBox, "slds-hide");
       var buttonOpenSearchBox = component.find("buttonOpenSearchBox");
       $A.util.addClass(buttonOpenSearchBox, "slds-hide");      
   },
    
  searchAndReplace: function(component, event, helper) { 
   helper.searchAndReplaceInRows(component,event,helper);
  },

  onFieldChange: function(component, event, helper) { 
     component.set("v.displaySaveStatus",false);
     component.set("v.isUnsavedRecords",true); 
  },     
  editObjectFields: function(component, event, helper) {
       var objectId=component.get("v.relatedList.objectId");
       var myDomain=component.get("v.myDomain"); 
       var editObjectLink='https://'+myDomain+'.lightning.force.com/one/one.app#/setup/ObjectManager/';
       editObjectLink+=objectId+'/FieldsAndRelationships/view'; 
       helper.newTabToURL(editObjectLink); 
   },  

    editLayout: function(component, event, helper) {
       var layoutId=component.get("v.relatedList.parentRecordLayoutId");
       var objectId=component.get("v.relatedList.parentObjectId");
       var myDomain=component.get("v.myDomain"); 
       var layoutPath='layouteditor/layoutEditor.apexp?type='+objectId+'&lid='+layoutId;  
       var classicLink='https://'+myDomain+'.my.salesforce.com/'+layoutPath;
       var lightningLink='https://'+myDomain+'.lightning.force.com/one/one.app#/setup/ObjectManager/';
       lightningLink+=objectId+'/PageLayouts/page?address='+encodeURIComponent('/'+layoutPath);  
       helper.newTabToURL(lightningLink); 
    },  
    
  debug: function(component, event, helper) {  
        console.log("v.relatedList.columns");
    	console.log(component.get("v.relatedList.columns"));
        console.log("v.records");
    	console.log(component.get("v.records"));
      	debugger;
      // component.set("v.relatedList.columns[0].isVisible",component.get("v.relatedList.columns[0].isVisible"));
        //component.set("v.relatedList.columns[0].isVisible",false); 
      	
	}
})