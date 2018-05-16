/**
 * Apex Controller for looking up an SObject via SOSL
 */
public with sharing class MassEditRL_LookupFieldCtrl
{

    /**
     * Aura enabled method to get the name of the initial record to load
     */

    @AuraEnabled
    public static Result getRecordName (Id theRecordId, String[] objectsToSearch){
      if (theRecordId==null) return new Result(null,null, null); 
      for (String objectName : objectsToSearch){
           String nameField;
           if (Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get('Name')!=null) nameField='Name';
           else if (Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get('DeveloperName')!=null) nameField='DeveloperName';
           else return new Result(null,null, null);
           String myQuery = 'SELECT Id, '+nameField+' FROM '+objectName+' WHERE Id = \'' + theRecordID+'\'';
      	   List<sObject> results = Database.query(myQuery);
           if (results.size()>0) {
                String oName = results[0].getSobjectType().getDescribe().getName();
                Result R = new Result(oName,(String)results[0].get(nameField), results[0].Id);
        		return R;
        	} 
        }
      return new Result(null,'Invalid record id', null);  
    }

    /**
     * Aura enabled method to search a specified SObject for a specific string
     */
    @AuraEnabled
    public static Result[] lookup(String searchString, String[] objectsToSearch)
    {
        // Sanitze the input
        String sanitizedSearchString = String.escapeSingleQuotes(searchString);
        String toReturn = '';
        for (String objectName: objectsToSearch) {
           toReturn+= objectName+'(id,name), ';
        }
        if (toReturn.endsWith(', ')) {toReturn= toReturn.removeEnd(', ')+' ';}

		List<Result> results = new List<Result>();

        // Build our SOSL query
        String searchQuery = 'FIND \'' + sanitizedSearchString + '*\' IN ALL FIELDS RETURNING ' + toReturn + ' Limit 50';

        // Execute the Query
        List<List<SObject>> searchList = search.query(searchQuery);

        // Create a list of matches to return
        for (List<Sobject> sl : searchList){
          		for (SObject so : sl)
                    {
                      //  results.add(new Result((String)so.get('ProductCode')+' - '+(String)so.get('Name'), so.Id));
                      String objectName = so.getSobjectType().getDescribe().getName();
                      results.add(new Result(objectName,(String)so.get('Name'), so.Id));
                    }
                    system.debug(results);  
         }
        
        return results;
    }

    /**
     * Inner class to wrap up an SObject Label and its Id
     */
	public class Result
    {
        @AuraEnabled public String recLabel {get; set;}
        @AuraEnabled public Id recId {get; set;}
        @AuraEnabled public String objectIcon {get; set;}
        @AuraEnabled public String objectName {get; set;}

        public Result(String objectName, String recLabel, Id recId)
        {
            this.objectName = objectName;
            if (objectName!=null)
   		         this.objectIcon = objectName.endsWith('__c') ? 'standard:custom_notification' : 'standard:'+objectName.toLowerCase();
            this.recLabel = recLabel;
            this.recId = recId;
        }
    }
}