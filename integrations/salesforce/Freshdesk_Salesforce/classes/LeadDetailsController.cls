global with sharing class LeadDetailsController {
    private final Lead lead;
    public static string ticketId{get;set;}
    public static boolean valid_fd{get; set;}
    public string leadName{get; set;}
    public string leadId{get; set;}
    public string leadEmail{get; set;}
    public static Ticket ticket{get; set;}
    public static TicketComment[] ticket_notes{get; set;}
    public static CustomFields[] customFields{get; set;}
    public static boolean isApexTest = false;
    public string url{get; set;}
    public static RemoteAuth__c site{get; set;}
    public static boolean valid_agent{get; set;}
    public static string apikey{get; set;}
    public static string errorMessage{get; set;}
    public static string ticketCsat{get;set;}
    
        
	public LeadDetailsController(ApexPages.StandardController stdController) {
        //this.lead = (Lead)stdController.getRecord();
        if(!isApexTest){
        	ticketId = ESAPI.encoder().SFDC_URLENCODE(ApexPages.currentPage().getParameters().get('ticket'));
        	this.lead = [select id, name, email from Lead where id=:ApexPages.currentPage().getParameters().get('id')];	
        }
        else{
        	ticketId = '1';
        	this.lead = (Lead)stdController.getRecord();
        }	
        leadName = lead.name;
        leadId = lead.Id;
        leadEmail = lead.email;
        site = RemoteAuth__c.getOrgDefaults();
        url = site.fd_url__c;
        fetchTickets();
        
        
        }
          
        public static void fetchTickets(){
	        valid_fd = (site.Id == null) ? false : true;
	        if(valid_fd){
	        	ticket = FDUtility.fetchTickets(ticketId);
	        	System.debug(LoggingLevel.ERROR, ticket);
	        	if(ticket != null){
	        		ticketCsat = FDUtility.fetchCSATForTicket(ticketId);
	        		ticket_notes = FDUtility.fetchTicketNotes(ticketId);
	        		customFields = FDUtility.populateCustomFields();	
	        	}
	        	else{
	        		errorMessage = 'Unable to reach your Freshdesk domain(' + site.fd_url__c + '). Please verify your APIKey and domain URL.';
	        	}
	        		
	        }
      }
     
    
}