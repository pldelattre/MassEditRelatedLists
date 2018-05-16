@isTest(seeAllData=true)
public class MassEditRLCtrlTest {

    // THIS IS AN UGLY CLASS TEST FOR PACKAGING PURPOSES
    
        static testMethod void myTestMethod() {
            MassEditRLCtrl.fetchOrgInfo();
            
            Account acc = new Account(Name='New Account');
            insert acc;
            MassEditRLCtrl.getRecObjectAndName(acc.id);
            Contact con = new Contact(LastName='test',AccountId=acc.id);
            insert con;
            Event ev = new Event(SUBJECT='test',ActivityDateTime=Date.today(),DurationInMinutes=10);
            insert ev;
            Task t = new Task(SUBJECT='test',STATUS='not started');
            String sessionID=UserInfo.getSessionId();
            
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
	        mock.setStaticResource('massEditAnythingJsonMock');
      	  	mock.setStatusCode(200);
        	mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            MassEditRLCtrl.MassEditLayout mel = MassEditRLCtrl.getLayout(acc.id,'Account',sessionID);
			Test.stopTest(); 
            MassEditRLCtrl.RList rl = new MassEditRLCtrl.RList();
            rl.columns = new list<MassEditRLCtrl.Column>();
            for (MassEditRLCtrl.RList aRL : mel.relatedLists){
                 String rlJSON = JSON.serialize(aRL);
                 MassEditRLCtrl.getRecords(acc.id,'Account',rlJSON,'30'); 
            }
            String rlJSON = JSON.serialize(mel.relatedLists[0]);
           // MassEditRLCtrl.getRecords(acc.id,'Account',rlJSON,'30'); 
            
            MassEditRLCtrl.HtmlInputType HIT = new MassEditRLCtrl.HtmlInputType('TEXTAREA');
            HIT = new MassEditRLCtrl.HtmlInputType('CURRENCY');
            HIT = new MassEditRLCtrl.HtmlInputType('DATE');
            HIT = new MassEditRLCtrl.HtmlInputType('BOOLEAN');
            HIT = new MassEditRLCtrl.HtmlInputType('CALCULATED');
            HIT = new MassEditRLCtrl.HtmlInputType('PICKLIST');
            HIT = new MassEditRLCtrl.HtmlInputType('EMAIL');
            HIT = new MassEditRLCtrl.HtmlInputType('PHONE');
            HIT = new MassEditRLCtrl.HtmlInputType('URL');
            
            Contact A = new Contact(LastName='Smith'); //TO INSERT
            Contact B = new Contact(LastName='Smith'); //TO UPDATE
            Contact C = new Contact(LastName='Smith'); //TO DELETE
            Contact[] LA = new list<Contact>(); LA.add(A);
            Contact[] LB = new list<Contact>(); LB.add(B);
            Contact[] LC = new list<Contact>(); LC.add(C);
            insert LB; insert LC;
            MassEditRLCtrl.saveRecords('Contact',LA,LB,LC);
            
            MassEditRLCtrl.RList rl2 = MassEditRLCtrl.extractRelatedList(rl,'Account',new MassEditRLCtrl.sortProperties('Name',true));
 
        }
    
}