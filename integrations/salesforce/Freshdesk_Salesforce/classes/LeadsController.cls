global with sharing class LeadsController {
        
    private final Lead lead;
    public static List<CustomFields> customFields{get; set;}
    public string ticket_subject{get; set;}
    public boolean valid_fd{get; set;}
    public boolean valid_agent{get; set;}
    public string url{get; set;}
    public string uname{get; set;}
    public string apikey{get; set;}
    public string pwd{get; set;}
    public string leadName{get; set;}
    public string leadId{get; set;}
    public string leadEmail{get; set;}
    public string resBody{get;set;}
    public static RemoteAuth__c site{get; set;}
	public static boolean isApexTest = false;
	public static boolean isApexTest1 = false;
	public static boolean isApexTest2 = false;  
	public boolean isPrevious = true;
	public boolean isNext = false; 
	public static integer page = 0; 
	public static string filter{get; set;}
    
    public LeadsController(ApexPages.StandardController stdController) {
    	
        if(!isApexTest)
        	this.lead = [select id, name, email from Lead where id=:ApexPages.currentPage().getParameters().get('id')];
        else
        	this.lead = (Lead)stdController.getRecord();
        leadName = lead.name;
        leadId = lead.Id;
        leadEmail = lead.email;
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