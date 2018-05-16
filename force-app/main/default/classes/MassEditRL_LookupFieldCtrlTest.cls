@isTest(seeAllData=true)

public class MassEditRL_LookupFieldCtrlTest {
    
    static testMethod void myTestMethod() {
        Contact c = new contact(Lastname='john');
        insert c;
        String[] objects = new list<String>{'Contact','Lead'};
        MassEditRL_LookupFieldCtrl.lookup('john',objects);
        MassEditRL_LookupFieldCtrl.getRecordName(c.id,objects);
        
    }

}