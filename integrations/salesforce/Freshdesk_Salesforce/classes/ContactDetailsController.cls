public with sharing class ContactDetailsController {
	private final Contact contact;
    public static string ticketId{get;set;}
    public static boolean valid_fd{get; set;}
    public string contactName{get; set;}
    public string contactId{get; set;}
    public string contactEmail{get; set;}
    public static Ticket ticket{get; set;}
    public static TicketComment[] ticket_notes{get; set;}
    public static CustomFields[] customFields{get; set;}
    public string url{get; set;}
    public static RemoteAuth__c site{get; set;}
    public static boolean isApexTest = false;
    public static boolean valid_agent{get; set;}
    public static string apikey{get; set;}
    public static string errorMessage{get; set;}
    public static string ticketCsat{get;set;}
    
        
	public ContactDetailsController(ApexPages.StandardController stdController) {
		
        if(!isApexTest){
        	ticketId = ESAPI.encoder().SFDC_HTMLENCODE(ApexPages.currentPage().getParameters().get('ticket'));
        	this.contact = [select id, name, email from Contact where id=:ApexPages.currentPage().getParameters().get('id')];	
        }
        else{
        	ticketId = '1';
        	this.contact = (Contact)stdController.getRecord();
        }	
        contactName = contact.name;
        contactId = contact.Id;
        contactEmail = contact.email;
        site = RemoteAuth__c.getOrgDefaults();
        url = site.fd_url__c;
        fetchTickets();
        
        
    }
          
        public static void fetchTickets(){
       	//System.debug('ContactDetails fetchTickets --------');
        valid_fd = (site.Id == null) ? false : true;
        
        //System.debug('valid_fd ' + valid_fd);
        if(valid_fd){
        	ticket = FDUtility.fetchTickets(ticketId);
        	//System.debug('contactdetails - ticket == ' + ticket);
        	
        	if(ticket != null){
        		ticketCsat = FDUtility.fetchCSATForTicket(ticketId);
        		//System.debug('csat ' + ticketCsat);
        		ticket_notes = FDUtility.fetchTicketNotes(ticketId);
        		customFields = FDUtility.populateCustomFields();	
        	}
        	else{
        		errorMessage = 'Unable to reach your Freshdesk domain(' + site.fd_url__c + '). Please verify your APIKey and domain URL.';
        	}
        }
      }
           
	
}