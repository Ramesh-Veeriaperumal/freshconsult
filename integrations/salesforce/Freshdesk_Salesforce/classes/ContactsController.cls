global with sharing  class ContactsController {
	private final Contact contact;
    public static CustomFields[] customFields{get; set;}
    public string ticket_subject{get; set;}
    public boolean valid_fd{get; set;}
    public string url{get; set;}
    public string uname{get; set;}
    public string pwd{get; set;}
    public string contactName{get; set;}
    public string contactId{get; set;}
    public string contactEmail{get; set;}
    public static RemoteAuth__c site{get; set;} 
    public static boolean isApexTest = false;
    public boolean isPrevious = false;
	public boolean isNext = false; 
	public static integer page = 0; 
	public static boolean valid_agent{get; set;}
    public static string apikey{get; set;}
    public static string filter{get; set;}
    
    public ContactsController(ApexPages.StandardController stdController) {
        if(!isApexTest)
            this.contact = [select id, name, email from Contact where id=:ApexPages.currentPage().getParameters().get('id')];
        else
            this.contact = (Contact)stdController.getRecord();
        	contactName = contact.name;
        contactId = contact.Id;
        contactEmail = contact.email;
        
        System.debug('Contats Controller ' + contactId + ' --- contactEmail = ' + contactEmail);
        site = RemoteAuth__c.getOrgDefaults();
        url = site.fd_url__c;
        customFields = FDUtility.populateCustomFields();
    }
    
    @remoteAction
    global static remoteObject createTicket(string dataString, string updateFlag, string ticketId, string eMail)
    {
        remoteObject returnObj = FDUtility.createTicket(dataString, updateFlag, '', eMail);
        return returnObj;       
    }
    
}