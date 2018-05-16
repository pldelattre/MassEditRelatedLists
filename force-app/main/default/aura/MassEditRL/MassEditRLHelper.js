({
	prepareRows : function(component,event,helper,rows) {
        var rl = component.get("v.relatedList");
        //var rows = component.get("v.records");
        for (var i = 0; i < rows.length; i++) {
          rows[i].DMLType='toUpdate';
          rows[i].isVisible=true;
          rows[i].DMLError=false;
          //Build cells by matching layout columns and records returned by apex
          var cells = [];  
  		  for (var j = 0; j < rl.columns.length; j++) {
              var cell = {}
              var fieldApiNameSplit = rl.columns[j].fieldApiName.split('.');
              cell.value = rows[i][fieldApiNameSplit[0]];
              cell.isEditable=true;
              for (var k=1; k < fieldApiNameSplit.length; k++)
              {
                  if (cell.value!=null) cell.value=cell.value[fieldApiNameSplit[k]];
                  cell.isEditable=false;
              }
              cell.fieldApiName=rl.columns[j].fieldApiName;
              cell.sObjectName=rl.objectname;
              cell.format=rl.columns[j].format;
              cell.fieldType=rl.columns[j].fieldType;
              if (cell.fieldType=='DATETIME' && cell.value != null) cell.value=cell.value.substring(0, 16);
              cell.picklistOptions=rl.columns[j].picklistOptions;
              cell.relationship=rl.columns[j].relationship;
              cell.isVisible=rl.columns[j].isVisible;
              cell.isUpdateable=rl.columns[j].isUpdateable;
              cell.UpdateableOnlyOnCreate=rl.columns[j].UpdateableOnlyOnCreate; 
              if (!cell.isUpdateable) cell.isEditable=false;
              if (rl.columns[j].htmlInputType != null){ 
                  cell.inputMainType=rl.columns[j].htmlInputType.mainType;
                  cell.inputSubType=rl.columns[j].htmlInputType.subType;
                  if (cell.inputMainType=='calculated') cell.isEditable=false;
              } else {
                  cell.isEditable=false;
                  cell.inputMainType='undefined';
              }
               
              cell.rowIndex=i;
              cell.colIndex=j;
              cells.push(cell);
          }
          rows[i].cells = cells;
		}
       return rows; 
	},
    
    loadSearchPicklistOptions : function(component,event,helper) {
       var rl = component.get("v.relatedList");
       var options = [{value:'All columns',label:'All columns'}];
        if (rl.columns != null) {
               for (var i = 0; i < rl.columns.length; i++) {
                   if (rl.columns[i].isUpdateable){
                       var option = {value: rl.columns[i].fieldApiName, label: rl.columns[i].fieldApiName};
                       options.push(option);
                   }
               }
      }      
      component.set("v.searchAndReplace.columns",options);  
    },
    
    prepareRecordsToSave : function(component,event,helper) {
       var rl = component.get("v.relatedList");
       var rows = component.get("v.records");
        var toSave= {toUpdate : [], toInsert : [], toDelete : []}; 
        if (rows==null) return null;
       for (var i = 0; i < rows.length; i++) {
           var rec = {};
           rec.sobjectType=rl.objectname;
		   rec.Id=rows[i].Id;
           for (var j=0; j<rows[i].cells.length; j++) {
               if (rows[i].cells[j].isUpdateable || (rows[i].cells[j].UpdateableOnlyOnCreate && rows[i].DMLType =='toInsert')){ 
                rec[rows[i].cells[j].fieldApiName]=rows[i].cells[j].value;
                if (rows[i].cells[j].fieldType=='DATETIME' && rows[i].cells[j].value != null) 
                    rec[rows[i].cells[j].fieldApiName]=rows[i].cells[j].value+':00.000Z';   
                if (rows[i].cells[j].fieldApiName=='OwnerId' && rows[i].cells[j].value == null){
                  rec[rows[i].cells[j].fieldApiName]=$A.get("$SObjectType.CurrentUser.Id");
                  component.set("v.records["+i+"].cells["+j+"].value",$A.get("$SObjectType.CurrentUser.Id"));  
                } 
               }    
           }
           if (rl.objectname=='PriceBookEntry') rec.UseStandardPrice=false;
           // For records to insert, add the extra fields that are not on the layout 
           if (rows[i].DMLType =='toInsert') {
               for (var j=0; j<rl.extraFields.length; j++){
                 rec[rl.extraFields[j]]=rows[i][rl.extraFields[j]]; 
               }
           }
           switch (rows[i].DMLType) {
              case 'toInsert':
              //delete rec.Id;
              toSave.toInsert.push(rec);
              break;
              case 'toDelete':
              toSave.toDelete.push(rec);
              break;
              case 'toUpdate':
              toSave.toUpdate.push(rec);  
           }
       }
     //toSave.toUpdate=toUpdate;   
     console.log("to Update:");   
     console.log(toSave);
     return toSave;   
    },
    
   afterSaveCleaning : function(component,event,helper,saveResult) {
      var rows = component.get("v.records");
      var insertCount=0;var updateCount=0;var deleteCount=0;
       var errorsCount = {insertErrors:0,updateErrors:0,deleteErrors:0,totalErrors:0}; 
      for (var i = 0; i < rows.length; i++) {
         rows[i].DMLError=false;  
         switch (rows[i].DMLType) {
              case 'toInsert':
              if (saveResult.insertResults[insertCount].isSuccess) {
                  rows[i].Id = saveResult.insertResults[insertCount].id;
                  rows[i].DMLType='toUpdate';
                  rows[i].DMLError=false;
                  rows[i]=helper.tuneRowForUpdateableOnInsert(rows[i]);
              } else {
                 rows[i].DMLError=true;
                 errorsCount.insertErrors++;
                 rows[i].DMLMessage=saveResult.insertResults[insertCount].error; 
              }   
              insertCount++;
              break;
              case 'toDelete':
			  if (!saveResult.deleteResults[deleteCount].isSuccess) {
                rows[i].DMLType='toUpdate';
                rows[i].DMLError=true;
                errorsCount.deleteErrors++;  
                rows[i].isVisible=true;
                rows[i].DMLMessage=saveResult.deleteResults[deleteCount].error;    
              } else{
                rows[i].DMLType='doNothing';  
              }    
              deleteCount++;
              break;
              case 'toUpdate':
              if (!saveResult.updateResults[updateCount].isSuccess) {
                rows[i].DMLError=true;
                errorsCount.updateErrors++;  
                rows[i].DMLMessage=saveResult.updateResults[updateCount].error;  
              }  
              updateCount++;
          }  
      }
    //full refresh and rerender of "v.records" attribute. 
    //This is a workaround to a bug in aura framework messing with aura:iteration order.    
    //component.set("v.records",[].concat(JSON.parse(JSON.stringify(rows))));
    component.set("v.records",rows);
    errorsCount.totalErrors=errorsCount.updateErrors+errorsCount.deleteErrors+errorsCount.insertErrors; 
    return errorsCount;   
	},
    
    searchAndReplaceInRows : function(component,event,helper) {
       var rl = component.get("v.relatedList");
       var rows = component.get("v.records");
       var searchParams = component.get("v.searchAndReplace"); 
       var replaceCount = 0; 
       if (rows==null) return;
       for (var i = 0; i < rows.length; i++) {
           if (!rows[i].isVisible) continue;
           for (var j=0; j<rows[i].cells.length; j++) {
               if (rows[i].cells[j].isVisible && rows[i].cells[j].isUpdateable && (searchParams.colValue=="All columns" || searchParams.colValue==rows[i].cells[j].fieldApiName )){
                   if (typeof rows[i].cells[j].value == "string"){
                   //if (rows[i].cells[j].fieldType=="picklist" && !component.get("v.displayPicklistAsText")) continue;
                   var esc = searchParams.searchFor.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
                   var reg = searchParams.isCaseSensitive ? new RegExp(esc,'g') : new RegExp(esc, 'ig');
                   rows[i].cells[j].value=rows[i].cells[j].value.replace(reg,
                                                                     function() {
                                                                      replaceCount++; 
                                                                      return searchParams.replaceBy;
                                                                     });
                   }
                   if (typeof rows[i].cells[j].value == "number" && !isNaN(searchParams.searchFor) && !isNaN(searchParams.replaceBy)){
                   rows[i].cells[j].value=Number(rows[i].cells[j].value.toString().replace(searchParams.searchFor,
                                                                      function() {
                                                                          replaceCount++; 
                                                                          return searchParams.replaceBy;
                                                                       }));    
                   }    
           	   }
           }
       }  
      component.set("v.records",rows);
      helper.showToast(component,event,'Info',replaceCount+' occurence(s) of \"'+searchParams.searchFor+'\" were replaced by \"'+searchParams.replaceBy+'\"','info');  
      return;   
    },
    
	
    tagRowForDeletion : function(component,indexRow) {
       var newDMLType = component.get("v.records["+indexRow+"].DMLType") != 'toInsert' ? 'toDelete' : 'doNothing'; 
	   component.set("v.records["+indexRow+"].DMLType",newDMLType);
       component.set("v.records["+indexRow+"].isVisible",false); 
    },

	cloneARow : function(component,event,helper,indexRow) {
       var rows = component.get("v.records");
       //the parse/stringify approach creates a real clone of the object and not just a pointer 
       var newRow =  JSON.parse(JSON.stringify(component.get("v.records["+indexRow+"]")));
       newRow.DMLType='toInsert';
       newRow.Id = null;
       newRow=helper.tuneRowForUpdateableOnInsert(newRow);
       rows.splice(indexRow+1,0,newRow);
        //component.set("v.records",[].concat(JSON.parse(JSON.stringify(rows)))); //Fix aura bugs but slow performance :(
       component.set("v.records",rows); 
    },
    
    alignCellsVisibilityToColumn : function(component,colIndex,targetVisibility) {
       var rows = component.get("v.records");
       if (rows==null) return;
       for (var i = 0; i < rows.length; i++) {
         rows[i].cells[colIndex].isVisible=targetVisibility;  
       }
       component.set("v.records",rows);  
    },    

	addRow : function(component,event,helper) {
       var rl = component.get("v.relatedList"); 
       var rows = component.get("v.records");
       var newRow = {};
       //let's simulate the retrieval of an empty record from apex.  
       for (var i = 0; i < rl.allFieldsWithFieldType.length; i++) {
           var field = rl.allFieldsWithFieldType[i];
           if (field.fieldApiName == 'OwnerId')
           newRow[field.fieldApiName]=$A.get("$SObjectType.CurrentUser.Id");   
           else if (field.fieldType=="ID" || field.fieldType=="REFERENCE")
           newRow[field.fieldApiName]=null;    
           else if (field.htmlInputType!=null && field.htmlInputType.subType=="number")
           newRow[field.fieldApiName]=0;
           else if (field.htmlInputType!=null && field.htmlInputType.subType=="date")
           newRow[field.fieldApiName]='2018-01-01';
           else if (field.fieldType=="DATETIME")
           newRow[field.fieldApiName]='2018-01-01T01:00:00.000Z';
           else if (rl.extraFields.includes(field.fieldApiName))
           newRow[field.fieldApiName]='Lorem Ipsum';    
           else newRow[field.fieldApiName]='';
       }
       //let's link it to this this record .
       newRow[rl.field]=component.get("v.recordId"); 
       
       //let's prepare the row 
       var newRowContainer = []; 
       newRowContainer.push(newRow);  
       var rowsWithCells = helper.prepareRows(component,event,helper,newRowContainer);
       rowsWithCells[0].DMLType='toInsert';
       rowsWithCells[0]=helper.tuneRowForUpdateableOnInsert(rowsWithCells[0]); 
       rows=rows.concat(rowsWithCells);
        
       component.set("v.records",rows);
    },
    
    tuneRowForUpdateableOnInsert : function(row){
        for (var i=0; i<row.cells.length; i++) {
            if (row.cells[i].UpdateableOnlyOnCreate) {
                row.cells[i].isEditable = (row.DMLType=='toInsert') ? true : false;
            } 
        }
  	   return row;   
    },
 
  	isAnyVisibleRow : function(component) {
       var rows = component.get("v.records");
       for (var i = 0; i < rows.length; i++) {
        if (rows[i].isVisible) return true;
       }    
       return false;
   },        
    
	showToast : function(component, event, title, message, type) {
	var toastEvent = $A.get("e.force:showToast");
	toastEvent.setParams({
			"title": title,
			"message": message,
			"type" : type,
			"duration" : 9000
	});
	toastEvent.fire();
},
    
navToRecord : function (component, event, id) {
    var navEvt = $A.get("e.force:navigateToSObject");
    navEvt.setParams({
      "recordId": id,
      //"slideDevName": "related"
    });
    navEvt.fire();
},
    
newTabToURL : function(url) {
		window.open(url);  
}    
})