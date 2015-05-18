/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest (seeAllData=true)
private class testIntegration {
	static ApexPages.StandardController controller;
   	
   	static testMethod void testLeadsController(){
   		LeadsController.isApexTest = true;
    	Lead[] l = [select id, name, email from Lead ];
    	if (l.size() > 0)
        	controller =new ApexPages.StandardController(l[0]);
        LeadsController leads = new LeadsController(controller);
    }
    
    static testMethod void testContactsController(){
   		ContactsController.isApexTest = true;
    	Contact[] c = [select id, name, email from Contact ];
    	if (c.size() > 0)
        	controller =new ApexPages.StandardController(c[0]);
        ContactsController leads = new ContactsController(controller);
    }
    
    static testMethod void testAccountsController(){
   		AccountsController.isApexTest = true;
    	Account[] a = [select id, name from Account ];
    	if (a.size() > 0)
        	controller =new ApexPages.StandardController(a[0]);
        AccountsController accounts = new AccountsController(controller);
    }
    
    static testMethod void testLeadDetailsController(){
   		LeadDetailsController.isApexTest = true;
    	Lead[] l = [select id, name, email from Lead ];
    	if (l.size() > 0)
        	controller =new ApexPages.StandardController(l[0]);
        LeadDetailsController leads = new LeadDetailsController(controller);
    }
    
    static testMethod void testContactDetailsController(){
   		ContactDetailsController.isApexTest = true;
    	Contact[] c = [select id, name, email from Contact];
    	if (c.size() > 0)
        controller =new ApexPages.StandardController(c[0]);
        ContactDetailsController contacts = new ContactDetailsController(controller);
    }
    
    static testMethod void testAccountDetailsController(){
   		AccountDetailsController.isApexTest = true;
    	Account[] a = [select id, name from Account ];
    	if (a.size() > 0)
        controller =new ApexPages.StandardController(a[0]);
        AccountDetailsController leads = new AccountDetailsController(controller);
    }
    
    
    
    static testMethod void testCreateTicketCall(){
    	LeadsController.createTicket('Test String', 'false', '', 'fd@try.com');
    }
    
    static testMethod void testCreateTicketContacts(){
    	ContactsController.createTicket('Test String', 'false', '', 'fd@try.com');
    }	
    
    static testMethod void testStaticParamsLead(){
    	LeadDetailsController.ticket = null;
    	LeadDetailsController.ticket_notes = null;
    	LeadDetailsController.customFields = null;
    }
    
    static testMethod void testStaticParamsAccount(){
    	AccountDetailsController.ticket = null;
    	AccountDetailsController.ticket_notes = null;
    	AccountDetailsController.customFields = null;
    }
    
    static testMethod void testStaticParamsContact(){
    	ContactDetailsController.ticket = null;
    	ContactDetailsController.ticket_notes = null;
    	ContactDetailsController.customFields = null;
    }
    
    static testMethod void testFetchContacts(){
    	FDUtility.testFetchContactsFD();
    }
          
    
    static testMethod void testDetailsAddComment() {
        TicketDetailsController.addComment('1', 'comment=Test&subject=&description=&status=2&priority=1', 'true', null);
    }
    
    static testMethod void testAssumeError(){
    	remoteObject returnObj = new remoteObject();
    	FDUtility.handleAssumeIdentityError(returnObj, 'text/xml', 401, '{"error_code":"unauthorized"}');
    }
    
    static testMethod void testAssumeError1(){
    	remoteObject returnObj = new remoteObject();
    	FDUtility.handleAssumeIdentityError(returnObj, 'text/xml', 401, '{"error_code":"assuming_identity_user_does_not_exist"}');
    }
    
    static testMethod void testAssumeError2(){
    	remoteObject returnObj = new remoteObject();
    	FDUtility.handleAssumeIdentityError(returnObj, 'text/xml', 401, '{"error_code":"assuming_identity_not_allowed"}');
    }
    
    static testMethod void testAllTickets(){
    	FDUtility.testGetAllTickets();
    }
    
    static testMethod void testFetchTicketDetails(){
    	FDUtility.testFetchTicketDetails();
    }
    static testMethod void testFetchTicketNotes(){
    	FDUtility.testFetchTicketNotes();
    }
    
    static testMethod void testPopulateFields(){
    	FDUtility.testPopulateCustomFields();
    }
    
    
    static testMethod void testFieldOptions(){
    	FieldOptions options = new FieldOptions();
    	options.id = 'ID';
    	options.value = 'Value';
    	
    }
    
    static testMethod void testUTCDateFormat(){
    	string formattedDate = FDUtility.formatUTCDate('2012-05-10T18:59:49+05:30');
        System.assertEquals('May 10, 2012 06:59 PM', formattedDate);
    	
    }
    
    static testMethod void testAddFDNote(){
    	FDUtility.testAddComment();
    }
    
    static testMethod void testCreate(){
    	FDUtility.testCreateTicket();
    }
    
    static testMethod void testUpdate(){
    	FDUtility.testUpdateTicket();
    }
    
    
    static testMethod void testTicket(){
    	Ticket ticket = new Ticket();
    	ticket.ticketId = 'Test Ticket';
    }
    
    static testMethod void testTicketComment(){
    	TicketComment ticket = new TicketComment();
    	ticket.comment = 'Test Comment';
    }
    
    static testMethod void testAccountSettings(){
    	//AccountSettings.saveRemoteSettings('https://testertest.freshdesk.com', 'sathappan@freshdesk.com', 'legolas');
    	AccountSettings.testAcc();
    }
    
    static testMethod void testUnauthorizedAccount(){
    	//AccountSettings.saveRemoteSettings('https://testertest.freshdesk.com', 'sathappan@freshdesk.com', 'legolas');
    	AccountSettings.testUnauthorizedAcc();
    }
    
    static testMethod void testAccountException(){
    	//AccountSettings.saveRemoteSettings('https://testertest.freshdesk.com', 'sathappan@freshdesk.com', 'legolas');
    	AccountSettings.testAccException();
    }
    
    static testMethod void testAttachmentsClass(){
    	Attachments  att = new Attachments();
    	att.attachment_url='http://cdn.ghj.com';
    	att.content_file_name='cdn';
    	att.content_file_type='image'; 	
    }
    
    static testMethod void testFDContact(){
    	FDContact fdContact = new FDContact();
    	fdContact.id='asdf';
    	fdContact.name='Contact';
    	fdContact.email='da@re.com';
    }
    
    static testMethod void testCreateTicketTC(){
    	TicketDetailsController.createTicket('Test String', 'false', '', 'fd@try.com');
    }
    
    static testMethod void testUpdateAgentTC(){
    	TicketDetailsController.updateAgent('TestString', 'false');
    }
    
    static testMethod void testAgentException(){
    	TicketDetailsController.testUpdateAgentException();
    }
    
    
    static testMethod void testInvalidRemote(){
    	TicketDetailsController.testInvalidRemoteObj();
    }
    
    static testMethod void testJSENCODE(){
    	ESAPI.encoder().SFDC_JSENCODE('<html>');
    }
    
    static testMethod void testSINHTMLENCODE(){
    	ESAPI.encoder().SFDC_JSINHTMLENCODE('<html>');
    }
    
    static testMethod void testURLENCODE(){
    	ESAPI.encoder().SFDC_URLENCODE('<html>');
    }
    
    static testMethod void testURLENCODEENC(){
    	ESAPI.encoder().SFDC_URLENCODE('<html>', 'UTF-8');
    }
    
    
    
    
}