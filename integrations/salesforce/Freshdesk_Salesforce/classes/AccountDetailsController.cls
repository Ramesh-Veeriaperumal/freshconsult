public with sharing class AccountDetailsController {
    private final Account account;
    public static string ticketId{get;set;}
    public static boolean valid_fd{get; set;}
    public string accName{get; set;}
    public string accId{get; set;}
    public string accEmail{get; set;}
    public static Ticket ticket{get; set;}
    public static FDContact fdContact{get; set;}
    
    public static TicketComment[] ticket_notes{get; set;}
    public static CustomFields[] customFields{get; set;}
    public string url{get; set;}
    public static RemoteAuth__c site{get; set;}
    public static boolean isApexTest = false;
    public static boolean valid_agent{get; set;}
    public static string apikey{get; set;}
    public static string errorMessage{get; set;}
    public static string ticketCsat{get;set;}
    
        
	public AccountDetailsController(ApexPages.StandardController stdController) {
		
        if(!isApexTest){
        	ticketId = ESAPI.encoder().SFDC_HTMLENCODE(ApexPages.currentPage().getParameters().get('ticket'));
        	this.account = [select id, name from Account where id=:ApexPages.currentPage().getParameters().get('id')];	
        }
        else{
        	ticketId = '1';
        	this.account = (Account)stdController.getRecord();
        }	
        accId = account.Id;
        site = RemoteAuth__c.getOrgDefaults();
        url = site.fd_url__c;
        fetchTickets();
    }
          
    public void fetchTickets(){
		valid_fd = (site.Id == null) ? false : true;
		if(valid_fd){
			ticket = FDUtility.fetchTickets(ticketId);
			if(ticket != null){
				ticketCsat = FDUtility.fetchCSATForTicket(ticketId);
        		ticket_notes = FDUtility.fetchTicketNotes(ticketId);
        		fdContact = FDUtility.getContactDetails(ticket.requester);
        	}
        	if(isApexTest){
    			fdContact = new FDContact();
    			fdContact.name = 'dsdas';
    			fdContact.email = 'dsad@gf.com';	
        	}
    		accName = fdContact.name;
    		accEmail = fdContact.email;	
        	customFields = FDUtility.populateCustomFields();
		}
		else{
			errorMessage = 'Unable to reach your Freshdesk domain(' + site.fd_url__c + '). Please verify your APIKey and domain URL.';
		}	
    }   
}