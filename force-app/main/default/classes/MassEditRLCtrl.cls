public class MassEditRLCtrl {    
    /*
   	 THIS APEX CLASS IS USED BY MASS EDIT RELATED LIST LIGHTNING COMPONENT
	 Author : Pierre Delattre (pdelattre@salesforce.com) - May 2018
	
 	This project is an attempt to help Solutions Engineers save time while preparing demos ;-)
	*/
    
    @AuraEnabled
    public static OrgInfo fetchOrgInfo(){
        string url = URL.getSalesforceBaseUrl().toExternalForm();
        string namespace  = getNamespacePrefix(); //get namespace in which Mass Edit Related Lists is running.
        OrgInfo org = new OrgInfo(url,namespace);
        return org;
    }
    
    // getNamespacePrefix() retrieves the namespace in which the component is running
    // method will return different answers depending on wheter were are running as managed packaged or as an unmanaged package. 
    public static String getNamespacePrefix() {
        String namespacePrefix;
        String[] classNameParts = String.valueOf(MassEditRLCtrl.class).split('\\.', 2);
        if(classNameParts.size() > 1) {
            Type classType = Type.forName(classNameParts[0], classNameParts[1]);
            if(classType == MassEditRLCtrl.class) {
                namespacePrefix = classNameParts[0];
            } else {
                namespacePrefix = null;
            }
        } else {
            //If there is only one part, the class has no namespace
            namespacePrefix = null;
        }
        return namespacePrefix; 
	}
    
    @AuraEnabled
    public static MassEditLayout getLayout(string recordId, string sObjectName, string sessionID) {
        // Check if the object has record types enabled
        List<RecordType> rts = [select Id from RecordType where SObjectType = :sObjectName ];
        Id recordTypeId = null;
        if (rts.size() > 0) {
                //Get record type id from the record that started the lightning component. 
                string soql = 'select RecordtypeId from ' + sObjectName + ' where id = \'' + recordId + '\'';
                list<sobject> records = Database.query(soql);
                recordTypeId = (Id)records[0].get('RecordtypeId');
        }
        
        system.debug('recordTypeId: '+recordTypeId);
        //SELECT DEFAULT MASTER RECORD TYPE IF NO RECORDTYPE FOUND
        if (recordTypeId==null) recordTypeId='012000000000000AAA'; 
        
        // now, let's get the layout for this record type id by quering the metadata api
        
        
        String salesforceHost = System.Url.getSalesforceBaseURL().toExternalForm();
        
		String url =  salesforceHost + '/services/data/v41.0/sobjects/'+ sObjectName +'/describe/layouts/' + recordTypeId;

		//Following is an alternative with oAuth. Working well but needs a connected app, auth provider, and named cred
		// ---> DifficultToPackage
		//
        //String url =  'callout:massEdit/services/data/v41.0/sobjects/'+ sObjectName +'/describe/layouts/' + recordTypeId;     
        //THE OAUTH TUTORIAL I USED : https://www.gscloudsolutions.com/blogpost/Using-Named-Credentials-with-the-Apex-Wrapper-Salesforce-Metadata-API-apex-mdapi?blogpost=true&utm_source=twitter&utm_medium=social&utm_campaign=named_credentials
        
        
		HttpRequest req = new HttpRequest();
            
        req.setMethod('GET');
        req.setEndpoint(url);
        req.setHeader('Content-type', 'application/json');
           
        //req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId()); // Not working when apex called from a lightning component
        req.setHeader('Authorization', 'Bearer ' + sessionID); //sessionID is loaded in a VF and passed as a parameter to this aura method. 
        //previous line needs to be commented if using oAuth.
                    
        Http http = new Http();
        HTTPResponse res = new HTTPResponse();
        
        try {
        res = http.send(req);
   			 }
  		  catch (Exception e) {
        // "Convert" the exception into an AuraHandledException
        throw new AuraHandledException('Something went wrong: '
            + e.getMessage());    
   			 }
        
        system.debug(res);
        system.debug(res.getBody());
        String jsonString = res.getBody();// Now we have all the record metadata as a string. 
        // We need to convert it into APEX object. But before that we want to get rid of apex reserved words
        
        jsonString = jsonString.replace('"sobject":', '"objectname":');//required because sobject is reserved in apex
        jsonString = jsonString.replace('"sort":', '"sortBy":');//required because sort is reserved in apex
        
        
        MassEditLayout mel = new MassEditLayout(sObjectName);
        
        //The following JSON parser does the job of converting the metadata api result into one RList Object
        //for each related list. These RList Object are stored into MassEditLayout Object and returned to the lightning
        //component. 
        JSONParser parser = JSON.createParser(jsonString);
        Boolean isActivitiesAdded = false;
        while (parser.nextToken() != null) {
        
            if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && 
                (parser.getText() == 'relatedLists')) {
               		parser.nextToken();
                    system.debug('currToken:'+parser.getCurrentToken());   
                    
		        if (parser.getCurrentToken() == JSONToken.START_ARRAY) {
        		    while (parser.nextToken() != null) {
                 		if (parser.getCurrentToken() == JSONToken.START_OBJECT) {
       						RList rl = (RList)parser.readValueAs(RList.class);
     						if (rl.objectname=='CombinedAttachment' || rl.objectname=='AttachedContentDocument' 
                                || rl.objectname=='CollaborationGroupRecord' || rl.objectname=='ProcessInstanceHistory'
                               	|| rl.objectname=='EmailStatus' || rl.objectname==null || rl.objectname=='OpportunitySplit'
                                || (rl.objectname.contains('History') && rl.objectname!='ActivityHistory' && !rl.objectname.endsWith('__c'))
                                || rl.objectname=='AttachedContentNote'  
                               )
                                continue; //skip some not queryable standard objects   
							
                            //Remove all related list with no lookupid to the parent record. 
                            if (rl.field == null) {
                                if (rl.objectname=='Opportunity' && sObjectName=='Contact') {} 
                                else continue;
                            }
                            
                            //ActivityHistory and OpenActivities object are special objects that need to be handled differently
                            if (rl.objectname=='ActivityHistory' || rl.objectname=='OpenActivity' ) {
                                if (!isActivitiesAdded) addTaskAndEventRL(mel);
                                isActivitiesAdded=true;
                                continue;
                            }
                            mel.relatedLists.add(rl);
							String s = JSON.serialize(rl);
                            //If we find account or opp teams, we'll add a related list with an extraction of users
                            if (rl.objectname=='OpportunityTeamMember' || rl.objectname=='AccountTeamMember' )
                                mel.relatedLists.add(extractRelatedList(rl,'User',new sortProperties('FirstName',true)));
                            	//addExtractedUsers(mel);
                            //If we find campaign influence, we'll add a related list with an extraction of campaigns
                            if ((rl.objectname=='CampaignInfluence' && sObjectName=='Opportunity')
                                || (rl.objectname=='CampaignMember' && sObjectName=='Contact')) {
                                    RList RCampaign = extractRelatedList(rl,'Campaign',new sortProperties('Name',true));
                            		if (RCampaign!=null) mel.relatedLists.add(RCampaign);
							}
                            
                            system.debug('Serialized rl: ' + rl);
                            if (rl.objectname=='OpportunityContactRole')
                                mel.relatedLists.add(extractRelatedList(rl,'Contact',new sortProperties('FirstName',true)));
                            
                            if (rl.objectname=='OpportunityLineItem'){
                                Rlist RPBE = extractRelatedList(rl,'PriceBookEntry',new sortProperties('Product2.Name',true));
                                if (RPBE!=null) {
                                    mel.relatedLists.add(RPBE);
                                	Rlist RProducts = extractRelatedList(RPBE,'Product2',new sortProperties('Name',true));
                                    if (RProducts!=null) mel.relatedLists.add(RProducts);
                                	}
                            }   
                    }
                }
            }
        }
        
        }
      
      mel.layoutId=jsonString.substringAfter('"id":"').substringBefore('"');
      mel.objectId=getObjectIdFromToolingApi(sObjectName,sessionID);  
      system.debug('objectId='+mel.objectId+' layoutId='+mel.layoutId);    
      //addChatterPosts(mel);  
      // Standard objects sometimes have some strange behavours that we need to correct
      fixStandardObjects(mel); 
      fixLookupFields(mel);  
      for (RList rl : mel.relatedLists){
        rl.objectId=getObjectIdFromToolingApi(rl.objectname,sessionID);
        rl.parentRecordLayoutId=mel.layoutId;
        rl.parentObjectId=mel.objectId;
        rl.parentObjectName=mel.objectName;
      }    
      // We need also to figure wich fields are mandatory to create new records but are not included in the layout. 
      // These fields will be used to clone or to create blank records. 
      getExtraFields(mel);   
      // Finally, we also need some metadata for each field. Is the field editable ? What's its type ?
      getRLMetaData(mel);
      getFieldsMetaData(mel);
 
      system.debug(mel);
      return mel;
    }
    
    public static String getObjectIdFromToolingApi(string sObjectName, string sessionID){	
		String objectName = sObjectName;
        if (objectName.endsWith('__c')) {
            objectName= objectName.removeEnd('__c');
        } else {
            return objectName;
        }    

        String query = 'SELECT Id From CustomObject Where DeveloperName = \'' + objectName + '\'';
        String endpoint = Url.getSalesforceBaseUrl().toExternalForm();
        endpoint += '/services/data/v41.0/tooling/query/?q=';
        endpoint += EncodingUtil.urlEncode(query, 'UTF-8');
        
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer ' + sessionID);
        request.setEndpoint(endpoint);
        
        
		String customObjectId='';        
          try {
        	HttpResponse response = new Http().send(request);
            customObjectId = response.getBody().substringAfter('"Id":"').substringBefore('"');  
   			 }
  		  catch (Exception e) {
            system.debug(e.getMessage());    
   		  }    
        
        //eg '01Id0000001BSeoEAG'
        customObjectId=customObjectId.left(15);
        System.debug(customObjectId);
        
        return customObjectId;
    }
    
   // Following method is to extract a relatedlist from another related list
   // i.e. Users from AccountTeam, Campaign from CampaignMember, Pricebookentry from OpportunityLineItem, ... 
   // This will allow to edit fields that were not editable in the source related list.
   public static RList extractRelatedList(RList sourceRL, String objectToExtract, sortProperties sortBy) {
	   Schema.SObjectType oExtract = Schema.getGlobalDescribe().get(objectToExtract);  
       RList rl = new RList();
       rl.objectname=objectToExtract;
       rl.label=oExtract.getDescribe().getLabelPlural()+' (extracted from '+sourceRL.objectName+')';
       rl.field=null;
       rl.extractedFrom=sourceRL.objectName;
       rl.sortBy=new list<sortProperties>();
       rl.sortBy.add(sortBy);
       rl.columns = new list<Column>();
       //If the extracted object is user, let's override the related list columns
       if (rl.objectname=='User') {
         rl.columns.add(new Column('FirstName'));
		 rl.columns.add(new Column('LastName'));
         rl.columns.add(new Column('Title'));  
         return rl;  
       }
       //If we extract another object, let's extract the columns for the new object from the columns in the source object
       for (column col:sourceRL.columns){
         if (col.fieldApiName.startsWithIgnoreCase(objectToExtract+'.'))
	         rl.columns.add(new Column(col.fieldApiName.removeStartIgnoreCase(objectToExtract+'.')));  
       }
       if (rl.columns.size()>0) return rl;
       else return null;
   }      
  
    //Task and events are weird objets for which the metadata api provide weird information. 
    //Let's build them manually instead of extracting them from the metadata json    
    static void addTaskAndEventRL(massEditLayout mel) {
        RList rlTask = new RList();
        rlTask.objectname='Task';rlTask.label='Tasks';
        rlTask.field=(mel.objectName!='Lead') ? 'WhatId' : 'WhoId';
        rlTask.sortBy=new list<sortProperties>();
        rlTask.sortBy.add(new sortProperties('ActivityDate',false));
        rlTask.columns = new list<Column>();
        rlTask.columns.add(new Column('Subject'));
        rlTask.columns.add(new Column('ActivityDate'));
        rlTask.columns.add(new Column('Status'));
        Column cTaskSubtype = new Column('TaskSubtype');
        cTaskSubtype.UpdateableOnlyOnCreate=true;
        rlTask.columns.add(cTaskSubtype);
        if (mel.objectName!='Lead') rlTask.columns.add(new Column('WhoId'));
        rlTask.columns.add(new Column('OwnerId'));
        //rlTask.columns.add(new Column('Who.Name'));
		mel.relatedLists.add(rlTask);
        
        RList rlEvent = new RList();
        rlEvent.objectname='Event';rlEvent.label='Events';
        rlEvent.field=(mel.objectName!='Lead') ? 'WhatId' : 'WhoId';
        rlEvent.sortBy=new list<sortProperties>();
        rlEvent.sortBy.add(new sortProperties('ActivityDate',false));
        rlEvent.columns = new list<Column>();
        rlEvent.columns.add(new Column('Subject'));
        rlEvent.columns.add(new Column('StartDateTime'));
        rlEvent.columns.add(new Column('DurationInMinutes'));
        if (mel.objectName!='Lead') rlEvent.columns.add(new Column('WhoId'));
        rlEvent.columns.add(new Column('OwnerId'));
        //rlEvent.columns.add(new Column('Who.Name'));
       	mel.relatedLists.add(rlEvent); 
        
    }

    // When a lookup field is found in a related list, the metadata api replace it with a name field on the target object.   
    // Let's fix this :-) .   
	static void fixLookupFields(massEditLayout mel) { 
        for (RList rl : mel.relatedLists){
            list<Column> columnsClean = new list<Column>(); 
            for (Column col : rl.columns){
                if (col.fieldApiName.endsWith('__r.Name') && col.lookupId!=null)
               	 columnsClean.add(new Column(col.lookupId));    
                else if (col.fieldApiName=='User.Name' && (rl.objectname=='OpportunityTeamMember' || rl.objectname=='AccountTeamMember')){
                    Column colUserId = new Column('UserId');
				    colUserId.UpdateableOnlyOnCreate=true; 
                    columnsClean.add(colUserId);
                } 
                else if (col.fieldApiName=='Contact.Name')
                  columnsClean.add(new Column('ContactId'));
 				else if (col.fieldApiName=='Account.Name')
                columnsClean.add(new Column('AccountId'));
                else if (col.fieldApiName=='Campaign.Name')
                columnsClean.add(new Column('CampaignId'));                
                else columnsClean.add(col); 
            }    
            rl.columns=columnsClean; 
        }
    }
    
    static void fixStandardObjects(massEditLayout mel) { 
       
         for (RList rl : mel.relatedLists){
             rl.initialObjectName=rl.objectname;
             // Let's convert "account contact roles" into contacts. This will allow us to edit them. 
             if (rl.objectname=='AccountContactRelation' && mel.objectName=='Account') {
                 rl.objectname='Contact';
                 rl.extractedFrom='AccountContactRelation';rl.field='AccountId';
                 list<Column> columnsClean = new list<Column>(); 
                 for (Column col : rl.columns){
                    if (col.fieldApiName.contains('Contact.')) columnsClean.add(col); 
                 }    
                 rl.columns=columnsClean;     
                 String rlString = JSON.serialize(rl);
                 rlString = rlString.replaceAll('Contact[.]', '');
                 RList rlCleaned = (RList)JSON.deserialize(rlString, Rlist.class);
                 rl.columns = rlCleaned.columns;
                 rl.sortBy= rlCleaned.sortBy;
                 system.debug(rlString);
             	
             }
             if (rl.objectname=='Opportunity' && mel.objectName=='Contact') {
               rl.extractedFrom='OpportunityContactRole';rl.field=null;  
             }
             
             if (rl.objectname=='OpportunityLineItem' && mel.objectName=='Opportunity') {
               rl.label='Opportunity Line Items';  
             }  
             
             //"Name" field on contact object is non updateable, let's convert it into firstname and lastname
             if (rl.objectname=='Contact'){
                list<Column> columnsClean = new list<Column>(); 
                for (Column col : rl.columns){
                    if (col.fieldApiName!='Name') columnsClean.add(col); 
                    else {
                      	Column colFirstName = new Column();
            			colFirstName.fieldapiname='FirstName';
                        columnsClean.add(colFirstName);
                        Column colLastName = new Column();
                        colLastName.fieldapiname='LastName';
                        columnsClean.add(colLastName);
                    }
                }
                rl.columns=columnsClean;  
             }
           if (rl.objectname.contains('ContactRole')){
               List<String> allowedCols = new list<String> {'Contact.Name', 'Role', 'IsPrimary', 'Contact.Title'}; 
               list<Column> columnsClean = new list<Column>(); 
               for (Column col : rl.columns){
                    if (allowedCols.contains(col.fieldApiName)) columnsClean.add(col);
                }
               rl.columns=columnsClean;  
           }
          if (rl.objectname=='CampaignInfluence'){ 
               list<Column> columnsClean = new list<Column>();
               for (Column col : rl.columns){
                   if (!col.fieldApiName.contains('OpportunityContactRole')) {columnsClean.add(col);}
                }
               rl.columns=columnsClean;  
          }      
           
         }
    }
    
    
    //This method is called when a user click save on a related list. Goal is to send back to client side all save results
    //record per record. 
    @AuraEnabled    
    public static SaveTableResult saveRecords (string sObjectName, list<SObject> toInsert,list<SObject> toUpdate,list<SObject> toDelete){
    		
        SaveTableResult STR = new SaveTableResult();
        
        try {
                // UPDATE RECORDS    
                Database.SaveResult[] updateResult = Database.update(toUpdate,false);
                Integer i=0;    
                for (Database.SaveResult sr : updateResult) {
                  STR.updateResults.add(new DMLResult(toUpdate[i].Id,sr.isSuccess(),sr.getErrors()));
                  i++;  
                }
               
                // INSERT RECORDS    
                Database.SaveResult[] insertResult = Database.insert(toInsert,false);
                i=0;    
                for (Database.SaveResult sr : insertResult) {
                  STR.insertResults.add(new DMLResult(toInsert[i].Id,sr.isSuccess(),sr.getErrors()));
                  i++;  
                }
                    
                // DELETE RECORDS
                Database.DeleteResult[] deleteResult = Database.delete(toDelete,false);
                i=0;    
                for (Database.DeleteResult sr : deleteResult) {
                  STR.deleteResults.add(new DMLResult(toDelete[i].Id,sr.isSuccess(),sr.getErrors()));
                  i++;  
                }   
   			 }
  		  catch (Exception e) {
        // "Convert" the exception into an AuraHandledException
        throw new AuraHandledException('Something went wrong: '
            + e.getMessage());    
   		}
    	
    	
        return STR;
    }    
 
    
    public static list<String> getObjectMandatoryFields (String sObjectName) {
        
        	List<String> reqFields = new List<String>();
            Map <String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
            Schema.SObjectType targetObj = schemaMap.get(sObjectName);
            if (targetObj==null) return reqFields;
            Map <String, Schema.SObjectField> fieldMap = targetObj.getDescribe().fields.getMap();
            for(String fieldName : fieldMap.keySet())
            { 
                Schema.SObjectField field = fieldMap.get(fieldName);
                Schema.DescribeFieldResult F = field.getDescribe();
               //A nillable field can have a null value, hence it is not mandatory.
               //system.debug('F: '+fieldName+' isCreateable: '+F.isCreateable()+' isNillable: '+F.isNillable()+' isDefaultedCreate: '+F.isDefaultedOnCreate()); 
                if( F.isCreateable() && !F.isNillable() && !F.isDefaultedOnCreate() && F.isUpdateable())
                {
                    reqFields.add(F.getName()); //getName() recovers the APEX field name (=with correct letter uppercase)
                }
              
           }
        if (!reqFields.contains('Name') && fieldMap.get('name')!=null && !fieldMap.get('name').getDescribe().isAutoNumber() && fieldMap.get('name').getDescribe().isUpdateable())
            	reqFields.add('Name'); 
        //system.debug(reqFields);	
        return reqFields;
    } 
    
    @AuraEnabled    
    public static list<sobject> getRecords (string recordId, string sObjectName, string rl, String queryLimit){
        //LET'S BUILD A DYNAMIC QUERY
        system.debug('RL catched?');
        Rlist oRlist = (RList)JSON.deserialize(rl, Rlist.class);
        system.debug('field:' + oRlist.field+ ' objectname:' + oRlist.objectname);
        
        
        //FIELDS OF THE QUERY 
        string soqlFields='';
        for (String s : oRlist.allFields){
            soqlFields += s + ', ';
        }
        if (soqlFields.endsWith(', ')) {soqlFields= soqlFields.removeEnd(', ')+' ';}
        system.debug(soqlFields);
        
        //ORDER BY OF THE QUERY
        string orderBy='';
        if (oRlist.sortBy!=null && oRlist.sortBy.size()>0){
           if (oRlist.objectname =='Task' && oRlist.sortBy[0].column=='ActivityDate') oRlist.sortBy[0].ascending = false; // force tasks to be ordered descending as in lightning 
           orderBy=' ORDER BY '+oRlist.sortBy[0].column+' '+(oRlist.sortBy[0].ascending?'ASC':'DESC');
           if (oRlist.sortBy.size()==2) 
           orderBy+=', '+oRlist.sortBy[1].column+' '+(oRlist.sortBy[1].ascending?'ASC':'DESC');
        }
        
        //WHERE PART OF THE QUERY
        string wherePart='';
        wherePart=' where '+oRlist.field+' = \'' + recordId + '\' ';
        
        // craft the 'where' clause for task and events
        if (oRlist.objectname=='Event' || oRlist.objectname=='Task') {
            wherePart+=' OR AccountId = \'' + recordId + '\' ';
            if (oRlist.parentObjectName=='Account' || oRlist.parentObjectName=='Contact'){
               MAP<ID,Contact> MAPContact = new MAP<Id,Contact>([Select ID from Contact where AccountId = :recordId OR Id = :recordId]);
               SET<ID> SETContactIDs = MAPContact.keyset();
                if (oRlist.objectname=='Task') {
                    if (Schema.getGlobalDescribe().get('TaskRelation')!=null){
                        String MAPQuery='select id, TaskId from TaskRelation where RelationId in :SetContactIDs';
                        //we use a dynamic query when querying TaskRelation, otherwise, the package will require 'shared activities' as an org feature
                        MAP<ID,sObject> MAPTR = new MAP<Id,sObject> (database.query(MAPQuery));
                        SET<ID> SETTaskIDs = new Set<ID>();
                        for (ID TR_ID : MAPTR.keyset()) {
                          SETTaskIDs.add((ID)MAPTR.get(TR_ID).get('TaskId'));  
                        }
                        wherePart+=' OR Id in :SETTaskIDs '; 
                    } else 
                        wherePart+=' OR WhoId in :SetContactIDs ';     
                }
                if (oRlist.objectname=='Event') {
                    if (Schema.getGlobalDescribe().get('TaskRelation')!=null){
                        String MAPQuery='select id, EventId from EventRelation where RelationId in :SetContactIDs';
                        //we use a dynamic query when querying EventRelation, otherwise, the package will require 'shared activities' as an org feature
                        MAP<ID,sObject> MAPER = new MAP<Id,sObject> (database.query(MAPQuery));
                        SET<ID> SETEventIDs = new Set<ID>();
                        for (ID ER_ID : MAPER.keyset()) {
                          SETEventIDs.add((ID)MAPER.get(ER_ID).get('EventId'));  
                        }
                        wherePart+=' OR Id in :SETEventIDs ';
                    } else 
                        wherePart+=' OR WhoId in :SetContactIDs ';      
                }
            }
        }
        if (oRlist.objectname=='CampaignInfluence')
              wherePart+=' AND Model.IsDefaultModel = true ';

        // CRAFT THE WHERE CLAUSE FOR ALL THE RLEATED LISTS THAT WERE EXTRACTED FROM OTHER LISTS
        if (oRlist.objectname=='Product2' && oRlist.parentObjectName=='Opportunity') {
            String MAPQuery='select id, Product2Id from OpportunityLineItem where OpportunityId = \''+recordId+'\'';
            MAP<ID,sObject> MAPOLI = new MAP<ID,sObject> (database.query(MAPQuery));
            SET<ID> SETProductIDs = new Set<ID>();
            for (ID OLI_ID : MAPOLI.keyset()) {
               SETProductIDs.add((ID)MAPOLI.get(OLI_ID).get('Product2Id')); 
            }    
            wherePart=' where Id IN :SETProductIDs ';    
        } 
        else if ((oRlist.extractedFrom!=null && oRlist.field==null)
                || oRlist.extractedFrom=='AccountContactRelation' ) {
            String MAPQuery='SELECT ID, '+oRlist.objectname+'Id from '+oRlist.extractedFrom+' where '+oRlist.parentObjectName+'Id = \''+recordId+'\'';
            if (oRlist.extractedFrom=='CampaignInfluence') MAPQuery+=' and Model.IsDefaultModel = true';
            MAP<ID,sObject> MAPSourceObject = new MAP<ID,sObject> (database.query(MAPQuery));
		    SET<ID> SETTargetObject = new Set<ID>();
            for (ID SR_ID : MAPSourceObject.keyset()) {
                 SETTargetObject.add((ID)MAPSourceObject.get(SR_ID).get(oRlist.objectname+'Id'));
            }
            wherePart=' where Id IN :SETTargetObject ';
        }        
       
       //CONCATENATE THE QUERY 
       string soql = 'select '+soqlFields+' from ' + oRlist.objectname + wherePart +orderBy;
       soql += ' LIMIT '+queryLimit; 
       system.debug('query:');
       system.debug(soql);
       list<sobject> records = Database.query(soql);
        

       return records;
        
    }

	public static void getRLMetaData (MassEditLayout mel) {
      for (RList rl : mel.relatedLists){
      if (rl.objectname=='User'){
        rl.isRowCreateable = false;
        rl.isRowDeleteable = false;  
      } 
      else if (rl.objectname=='CampaignInfluence'){
        rl.isRowCreateable = false;
        rl.isRowDeleteable = true;     
      }    
      else {
        rl.isRowCreateable = true;
        rl.isRowDeleteable = true;    
      }      
      }    
    }    
    
    public static void getFieldsMetaData (MassEditLayout mel) {
        Map <String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        for (RList rl : mel.relatedLists){
            Schema.SObjectType targetObj = schemaMap.get(rl.objectname);
            if (targetObj==null) continue;
            Map <String, Schema.SObjectField> fieldMap = targetObj.getDescribe().fields.getMap();
            //let's get full metadata for layout fields. 
            for (Column col : rl.columns){
                col.isVisible=true; 
                Schema.SObjectField field = fieldMap.get(col.fieldApiName);
                if (field != null) {
                    col.fieldType = field.getDescribe().getType().name();
                    col.isCalculated = field.getDescribe().isCalculated();
                    col.isUpdateable = field.getDescribe().isUpdateable();
                    if (col.isCalculated){
                        col.fieldType = 'CALCULATED';
                    }
                    col.htmlInputType = new HtmlInputType(col.fieldType);
                    
                     if (col.fieldType=='PICKLIST') {
                       PicklistOption[] options = new list<PicklistOption>();  
                       Schema.PicklistEntry[] picklistValues = field.getDescribe().getPicklistValues();
                        for (Schema.PicklistEntry entry : picklistValues){
                            PicklistOption newOption = new PicklistOption(entry.getValue(),entry.getLabel());
                            options.add(newOption);
                        }
                      col.picklistOptions=options;  
                     }
                   if (col.fieldType=='REFERENCE') {
                      Relationship relationship = new Relationship(field.getDescribe().getRelationshipName()); 
                      for(Schema.SObjectType reference : field.getDescribe().getReferenceTo()) {
                      	relationship.objects.add(reference.getDescribe().getName());
                      }
                      col.relationship=relationship; 
                   } 
                   
                } else {
                    col.isUpdateable = false;
                }
            }
          
         //let's get basic metadata for all fields.
         Column[] allFieldsWithFieldType = new list<Column>();
         for (string s : rl.allFields){    
         	Column c = new Column();
            c.fieldApiName=s;
            Schema.SObjectField field = fieldMap.get(s);
            if (field != null) {
            	c.fieldType = field.getDescribe().getType().name();
                c.htmlInputType = new HtmlInputType(c.fieldType);
            }
           allFieldsWithFieldType.add(c);    
         }
        rl.allFieldsWithFieldType=allFieldsWithFieldType;    
        }
        

        return;
    }
 
public static void getExtraFields (MassEditLayout mel) {
	for (RList rl : mel.relatedLists){
        List<String> extraFields = new List<String>();
        List<String> allFields = new List<String>();
    	List<String> layoutFields = new List<String>();  
        for (Column col : rl.columns){
            layoutFields.add(col.fieldApiName);
            allFields.add(col.fieldApiName);
        }
        List<String> reqFields = getObjectMandatoryFields(rl.objectname);
        for (String s : reqFields){
            if (!layoutFields.contains(s)) {extraFields.add(s);allFields.add(s);}
        }
        if (!layoutFields.contains('Id') && !extraFields.contains('Id')) 
        	{extraFields.add('Id');allFields.add('Id');}
        if (!layoutFields.contains(rl.field) && !extraFields.contains(rl.field)) 
        	{extraFields.add(rl.field);allFields.add(rl.field);}
        rl.layoutFields=layoutFields;
        rl.extraFields=extraFields;
        rl.allFields=allFields;
        
        system.debug('extraFields for '+rl.objectname+' :');
        system.debug(rl.extraFields);
    }
    return;
}
    
@AuraEnabled    
public static void cleanChatterPosts () {
    Feeditem[] posts = [select id,type,body from FeedItem where type='CreateRecordEvent' or type='SocialPost'];
    delete posts;    
}   
    
@AuraEnabled
public static Rec getRecObjectAndName (string recordId) {
        if(recordId==null || (recordId.length() != 15 && recordId.length() != 18)) return new Rec(null,null);
        String objectName=((ID)recordId).getSObjectType().getDescribe().getName();
        String query = 'SELECT Name FROM '+objectName+' WHERE Id=\''+recordId+'\''; 
    	String recName=null;
       try {
           list<sobject> records = Database.query(query);
           recName = (String)records[0].get('Name');
   		}
  	   catch (Exception e) {
         recName=null;   
   	    } 
       
        return new Rec(objectName,recName);
}    
    
       
 public class RList {
	 @AuraEnabled 
     public String field;
     @AuraEnabled 
 	 public String name;
     @AuraEnabled 
     public String label;
     @AuraEnabled 
     public String objectname;
     @AuraEnabled 
     public String extractedFrom;
     @AuraEnabled
     public String initialObjectname;
     @AuraEnabled 
     public list<Column> columns;
     @AuraEnabled 
     public list<sortProperties> sortBy; 
     @AuraEnabled 
     public list<String> layoutFields;
     @AuraEnabled 
     public list<String> extraFields;
     @AuraEnabled 
     public list<String> allFields;
     @AuraEnabled 
     public list<Column> allFieldsWithFieldType;
     @AuraEnabled 
     public String objectId;
     @AuraEnabled 
     public String parentRecordLayoutId;
     @AuraEnabled 
     public String parentObjectId;
     @AuraEnabled 
     public String parentObjectName;
     @AuraEnabled 
     public Boolean isRowCreateable;
     @AuraEnabled 
     public Boolean isRowDeleteable;
} 

public class sortProperties {
  @AuraEnabled
  public Boolean ascending;
  @AuraEnabled  
  public String column;
  sortProperties(){}
  public sortProperties(string fieldName, Boolean isAscending){
    this.column=fieldName;
    this.ascending=isAscending;  
  } 
}    
    
public class Column {
    @AuraEnabled 
    public String field;
    @AuraEnabled 
    public String fieldApiName;
    @AuraEnabled 
    public String format;
    @AuraEnabled 
    public String label;
    @AuraEnabled 
    public String lookupId;
    @AuraEnabled 
    public String name;
    @AuraEnabled 
    public Boolean sortable;
    @AuraEnabled 
    public String fieldType;
    @AuraEnabled
    public Boolean isCalculated;
    @AuraEnabled
    public Boolean isUpdateable;
    @AuraEnabled
    public Boolean isVisible;
    @AuraEnabled
    public Boolean UpdateableOnlyOnCreate;
    @AuraEnabled 
    public HtmlInputType htmlInputType;
    @AuraEnabled 
    public list<PicklistOption> picklistOptions;
    @AuraEnabled 
    public Relationship relationship;
    public Column(){
        this.UpdateableOnlyOnCreate=false;
        this.isVisible=true;
    }
    public Column(String fieldApiName){
     this.fieldApiName=fieldApiName;
     this.UpdateableOnlyOnCreate=false;
     this.isVisible=true;
    }
}
    
public class Relationship{
   @AuraEnabled 
   public String relationshipName; 
   @AuraEnabled
   public list<String> objects;
   Relationship (String relationshipName){
    this.relationshipName=relationshipName;   
   	this.objects = new list<String>();     
   }
   
}    
    
public class PicklistOption{
       @AuraEnabled 
       public String value; 
       @AuraEnabled 
       public String label;
       public PicklistOption(String value, String label){
           this.value=value; this.label=label;
        }
 }
    
public class SaveTableResult{
@AuraEnabled     
public DMLResult[] insertResults;
@AuraEnabled 
public DMLResult[] updateResults;
@AuraEnabled 
public DMLResult[] deleteResults;
SaveTableResult(){
	this.insertResults = new list<DMLResult>();
	this.updateResults = new list<DMLResult>();
	this.deleteResults = new list<DMLResult>();    
 }    
}    
    

public class DMLResult {
    @AuraEnabled 
    public String id;
    @AuraEnabled     
    public Boolean isSuccess;
    @AuraEnabled     
    public String error;
    public DMLResult(String id, Boolean isSuccess,Database.Error[] Errors){
        this.id=id; this.isSuccess=isSuccess;
        this.error='';
        for(Database.Error err : Errors) {               
            this.error+=err.getStatusCode() + ': ' + err.getMessage()+'<br/>';
            this.error+='Fields that affected this error: ' + err.getFields()+'<br/>';
        }
    }
}    

public class MassEditLayout {
    @AuraEnabled 
    public String objectName;
    @AuraEnabled 
    public String objectId;
    @AuraEnabled 
    public String layoutId;
    @AuraEnabled 
    public list<RList> relatedLists; 
    MassEditLayout () {
        relatedLists = new list<RList>();
    }
    MassEditLayout (String objectName) {
        relatedLists = new list<RList>();
        this.objectName = objectName;
    }
}
    
public class Rec {
  @AuraEnabled
  public String sObjectName;
  @AuraEnabled
  public String recordName;
  public Rec(String sObjectName, String recordName){
   this.sObjectName=sObjectName;
   this.recordName=recordName;   
  }
} 
    
public class OrgInfo {
  @AuraEnabled
  public String baseURL;  
  @AuraEnabled
  public String namespace;
  public OrgInfo(string baseURL,string namespace){
  	this.baseURL=baseURL; this.namespace=namespace;      
  }  
        
}    

public class HtmlInputType {
       @AuraEnabled 
       public String mainType; 
       @AuraEnabled 
       public String subType;
       public HtmlInputType(String fieldType){
           this.mainType='invalid';
           this.subType='invalid';    
           if (fieldType=='TEXTAREA' || fieldType=='STRING' || fieldType=='ID' || fieldType=='COMBOBOX' ) {
           		this.mainType='standard';
                this.subType='text';    
           } 
           if (fieldType=='CURRENCY' || fieldType=='DOUBLE' || fieldType=='INTEGER' || fieldType=='PERCENT' ) {
           		this.mainType='standard';
                this.subType='number';    
           } 
           if (fieldType=='DATE' || fieldType=='DATETIME') {
           		this.mainType='standard';
                this.subType='date';    
           } 
		   if (fieldType=='DATETIME') {
           		this.mainType='standard';
                this.subType='datetime-local';    
           }            
           if (fieldType=='BOOLEAN') {
           		this.mainType='checkbox';
                this.subType='';    
           }
           if (fieldType=='CALCULATED') {
           		this.mainType='calculated';
                this.subType='';    
           } 
           if (fieldType=='PICKLIST' ||  fieldType=='MULTIPICKLIST') {
           		//this.mainType='standard'; //this is a hack until a v2 of the component with picklist management
               	this.mainType='picklist';
                this.subType='';    
           }
           if (fieldType=='EMAIL') {
           		this.mainType='standard';
                this.subType='email';    
           }
           if (fieldType=='PHONE') {
           		this.mainType='standard';
                this.subType='tel';    
           }
           if (fieldType=='URL') {
           		this.mainType='standard';
                this.subType='url';    
           }
           if (fieldType=='REFERENCE') {
           		this.mainType='lookup';
                this.subType='';    
           } 
        }
    }
    
        
}